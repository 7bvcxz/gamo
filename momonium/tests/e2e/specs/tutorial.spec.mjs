// Step 25 acceptance, Step 30 flow: a first-time player on a fresh island,
// with no docs, is led by the tutorial to an empty tile, the farm among the
// four choices beside it (price shown), the build, the first sowing and
// watering, and at the end to the trash can and its check -- all by real taps
// on what it rings. With MOMONIUM_EVIDENCE set, each step's screen is saved.
import { test, expect } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const EVIDENCE = process.env.MOMONIUM_EVIDENCE || '';
const near = (a, b) => a.length === 4 && b.length === 4 && a.every((v, i) => Math.abs(v - b[i]) < 2);

async function open(page) {
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; window.MOMONIUM_E2E_TUTORIAL = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(800);
  return {
    query: (name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]),
    state: () => page.evaluate(() => window.momonium.state()),
  };
}

test('first run: the tutorial leads from nothing to a watered farm', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  const g = await open(page);
  await page.evaluate(() => window.momonium.setTimeScale(0));
  await g.query('set_language', info.project.use.hasTouch ? 'ko' : 'en');
  const canvas = page.locator('canvas');
  const tapRect = async (r, win) => {
    const box = await canvas.boundingBox();
    const x = box.x + (r[0] + r[2] / 2) * (box.width / win[0]);
    const y = box.y + (r[1] + r[3] / 2) * (box.height / win[1]);
    if (info.project.use.hasTouch) await page.touchscreen.tap(x, y);
    else await page.mouse.click(x, y);
    await page.waitForTimeout(300);
  };
  const shot = async (name) => {
    if (!EVIDENCE) return;
    mkdirSync(EVIDENCE, { recursive: true });
    await canvas.screenshot({ path: `${EVIDENCE}/${info.project.name}-${name}.png` });
  };
  let t = await g.query('tutorial');
  expect(t.running).toBe(true);
  expect(t.step).toBe('pick_tile');
  await shot('1-empty-tile');
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('pick_farm');
  const strip = await g.query('strip');
  expect(strip.open).toBe(true);
  expect(Object.keys(strip.buttons).sort()).toEqual(['farm', 'lumberyard', 'mine', 'research']);
  await shot('2-four-choices-farm-price');
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('wait_build');
  await shot('3-building');
  await g.query('dev_advance_ms', 6000);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('sow');
  await shot('4-sow');
  await tapRect(t.target2, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('working');
  await g.query('dev_advance_ms', 5000);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('water');
  await shot('5-water');
  await tapRect(t.target2, t.window);
  await g.query('dev_advance_ms', 5000);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('more');
  const ring = await g.query('strip');
  expect(near(t.target, ring.trash)).toBe(true);
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  expect(near(t.target2, (await g.query('strip')).confirm)).toBe(true);
  await shot('6-trash-and-check');
  const s = await g.state();
  const farm = s.buildings.buildings.find((b) => b.type === 'farm');
  expect(farm.completed).toBe(2);
  await tapRect(t.ok, t.window);
  t = await g.query('tutorial');
  expect(t.running).toBe(false);
  expect(t.done).toBe(true);
  expect(errors).toEqual([]);
});
