// Step 25 acceptance: a first-time player on a fresh island, with no docs,
// is led by the tutorial to the catalog, the farm and its price, a tile, the
// build, the first sowing and watering, and to where the mine and lumberyard
// wait with their unlock levels -- all by real taps on what it rings. With
// MOMONIUM_EVIDENCE set, each step's screen is saved there.
import { test, expect } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const EVIDENCE = process.env.MOMONIUM_EVIDENCE || '';

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
  expect(t.step).toBe('open_build');
  await shot('1-open-build');
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('pick_farm');
  const ui = await g.query('build_ui');
  expect(Object.keys(ui.cards)).toEqual(expect.arrayContaining(['farm', 'lumberyard', 'mine']));
  await shot('2-catalog-farm-price');
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('pick_tile');
  await shot('3-tile-and-cost');
  await tapRect(t.target2, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('wait_build');
  await shot('4-building');
  await g.query('dev_advance_ms', 6000);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('sow');
  await shot('5-sow');
  await tapRect(t.target2, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('working');
  await g.query('dev_advance_ms', 5000);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('water');
  await shot('6-water');
  await tapRect(t.target2, t.window);
  await g.query('dev_advance_ms', 5000);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('more');
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  await shot('7-mine-lumberyard-levels');
  const s = await g.state();
  const farm = s.buildings.buildings.find((b) => b.type === 'farm');
  expect(farm.completed).toBe(2);
  await tapRect(t.ok, t.window);
  t = await g.query('tutorial');
  expect(t.running).toBe(false);
  expect(t.done).toBe(true);
  expect(errors).toEqual([]);
});
