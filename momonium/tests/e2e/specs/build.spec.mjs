// Step 30 (redesigned): tap an empty tile of the island and four choices --
// farm, mine, lumberyard, lab -- open beside it with their prices or levels;
// one tap builds. Tap a building: a trash can bottom right; tap it and a check
// appears above; only the check pulls the building down, with half of what it
// cost back.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('tap an empty tile, then the farm: built in one tap', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const hud = await game.query('hud');
  expect(hud.buttons.build).toBeUndefined();
  const cell = await cellToCanvas(game, [1, 1]);
  await game.tap(cell.x, cell.y);
  await game.page.waitForTimeout(250);
  const strip = await game.query('strip');
  expect(strip.open).toBe(true);
  expect(strip.cell).toEqual([1, 1]);
  expect(Object.keys(strip.buttons).sort()).toEqual(['farm', 'lumberyard', 'mine', 'research']);
  expect(strip.buttons.farm.disabled).toBe(false);
  expect(strip.buttons.farm.price).toBe('$10');
  expect(strip.buttons.mine.disabled).toBe(true);
  expect(strip.buttons.mine.price).toBe('Opens at Lv 3');
  for (const b of Object.values(strip.buttons)) {
    expect(b.rect[0]).toBeGreaterThanOrEqual(0);
    expect(b.rect[0] + b.rect[2]).toBeLessThanOrEqual(strip.window[0] + 1);
  }
  const farm = await centre(game, strip.buttons.farm.rect, strip.window);
  await game.tap(farm.x, farm.y);
  await game.page.waitForTimeout(200);
  const s = await game.state();
  expect(s.economy.money).toBe(0);
  const b = s.buildings.buildings[0];
  expect(b.type).toBe('farm');
  expect(b.anchor).toEqual([1, 1]);
  expect(b.state).toBe('constructing');
  expect((await game.query('strip')).open).toBe(false);
  await game.setTimeScale(10);
  await expect.poll(async () => (await game.state()).buildings.buildings[0].state, { timeout: 10_000 }).toBe('idle');
});

test('an occupied tile is refused', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_place_building', ['farm', 0, 0]);
  const r = await game.command({ type: 'building.place', building: 'farm', anchor: [0, 0] });
  expect(r.ok).toBe(false);
  expect(r.reason).toBe('err.occupied');
  expect((await game.state()).economy.money).toBe(10);
});

test('trash, then the check: pulled down for half of its cost', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_add_money', 70);
  const r = await game.command({ type: 'building.place', building: 'farm', anchor: [1, 0] });
  expect(r.ok).toBe(true);
  // Built (Step 69: the farm's 3 s x2.5).
  await game.query('dev_advance_ms', (await game.query('rules')).build_ms.farm + 100);
  await game.query('dev_select_cell', [1, 0]);
  await game.page.waitForTimeout(250);
  let ui = await game.query('strip');
  expect(ui.trash.length).toBe(4);
  expect(ui.confirm).toEqual([]);
  expect(ui.trash[0]).toBeGreaterThan(ui.window[0] * 0.7);
  const before = (await game.state()).economy.money;
  const trash = await centre(game, ui.trash, ui.window);
  await game.tap(trash.x, trash.y);
  await game.page.waitForTimeout(200);
  ui = await game.query('strip');
  expect(ui.confirm.length).toBe(4);
  expect(ui.confirm[1] + ui.confirm[3]).toBeLessThanOrEqual(ui.trash[1] + 1);
  expect((await game.state()).buildings.buildings.length).toBe(1);
  const check = await centre(game, ui.confirm, ui.window);
  await game.tap(check.x, check.y);
  await game.page.waitForTimeout(200);
  const s = await game.state();
  expect(s.buildings.buildings.length).toBe(0);
  expect(s.economy.money - before).toBe(5);
  ui = await game.query('strip');
  expect(ui.trash).toEqual([]);
  const cell = await cellToCanvas(game, [1, 0]);
  await game.tap(cell.x, cell.y);
  await game.page.waitForTimeout(200);
  expect((await game.query('strip')).open).toBe(true);
});
