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
  // The times as played (Step 69: a farm builds in 7.5 s, a stage is 6.25 s).
  const rules = await g.query('rules');
  await g.query('dev_advance_ms', rules.build_ms.farm + 100);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('sow');
  await shot('4-sow');
  await tapRect(t.target2, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('working');
  await g.query('dev_advance_ms', rules.farm_stages[0][1] + 100);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('water');
  await shot('5-water');
  await tapRect(t.target2, t.window);
  await g.query('dev_advance_ms', rules.farm_stages[1][1] + rules.farm_stages[1][2] + 100);
  await page.waitForTimeout(300);
  // Step 53: no Momo yet -- farm by hand for the first, then the Hire
  // button and its card (real taps); the hire is selected: Schedule under it.
  t = await g.query('tutorial');
  expect(t.step).toBe('save_hire');
  expect((await g.state()).momo.momos.length).toBe(0);
  await shot('6-save-for-a-momo');
  await g.query('dev_add_money', 15);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('hire');
  await shot('7-hire');
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  expect(t.step, 'the menu is open: its Momo card is ringed').toBe('hire');
  await tapRect(t.target, t.window);
  expect((await g.state()).momo.momos.length, 'the first Momo, hired by the player').toBe(1);
  t = await g.query('tutorial');
  expect(t.step).toBe('momo_schedule');
  await shot('8-momo-schedule');
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('momo_edit');
  const tile = await page.evaluate(() => window.momonium.call('cell_screen', [0, 1]));
  await tapRect([tile.x - 2, tile.y - 2, 4, 4], tile.window);
  const w = await g.query('watch');
  if (w.editing) await tapRect(w.schedule, w.window);
  // Quiet while the island has room (Step 50), then the sea once it is
  // nearly full: its price, and when affordable, two taps on the glow.
  t = await g.query('tutorial');
  expect(t.step).toBe('later');
  expect(t.shown).toBe(false);
  while (t.free.length > 1) {
    await g.query('dev_place_building', ['research', t.free[0][0], t.free[0][1]]);
    t = await g.query('tutorial');
  }
  await g.query('dev_add_money', (await g.query('rules')).land_price);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  expect(t.step).toBe('land');
  expect(t.shown).toBe(true);
  expect(t.target.length).toBe(4);
  await shot('9-land');
  const sea = t.target;
  await tapRect(sea, t.window);
  await tapRect(sea, t.window);
  t = await g.query('tutorial');
  expect(t.step).toBe('more');
  // The farm selected again: the last step rings its trash.
  const built = (await g.state()).buildings.buildings.find((b) => b.type === 'farm');
  await g.query('dev_select_cell', built.anchor);
  await page.waitForTimeout(300);
  t = await g.query('tutorial');
  const ring = await g.query('strip');
  expect(near(t.target, ring.trash)).toBe(true);
  await tapRect(t.target, t.window);
  t = await g.query('tutorial');
  expect(near(t.target2, (await g.query('strip')).confirm)).toBe(true);
  await shot('10-trash-and-check');
  const s = await g.state();
  const farm = s.buildings.buildings.find((b) => b.type === 'farm');
  expect(farm.completed).toBe(2);
  await tapRect(t.ok, t.window);
  t = await g.query('tutorial');
  expect(t.running).toBe(false);
  expect(t.done).toBe(true);
  expect(errors).toEqual([]);
});
