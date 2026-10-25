// Step 13: Shop -> Farm -> tap a tile -> Build: $10 is spent, the farm is
// under construction for 5 seconds and then ready; an occupied tile is refused.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('build the first farm from the shop', async ({ game }) => {
  await game.setTimeScale(0);
  const hud = await game.query('hud');
  const shop = await centre(game, hud.buttons.shop, hud.window);
  await game.tap(shop.x, shop.y);
  await game.page.waitForTimeout(200);
  let ui = await game.query('build_ui');
  expect(ui.menu_open).toBe(true);
  const card = await centre(game, ui.cards.farm, ui.window);
  await game.tap(card.x, card.y);
  await game.page.waitForTimeout(150);
  const cell = await cellToCanvas(game, [1, 1]);
  await game.tap(cell.x, cell.y);
  await game.page.waitForTimeout(150);
  ui = await game.query('build_ui');
  expect(ui.placing).toBe(true);
  expect(ui.anchor).toEqual([1, 1]);
  expect(ui.valid).toBe(true);
  const build = await centre(game, ui.build, ui.window);
  await game.tap(build.x, build.y);
  await game.page.waitForTimeout(150);
  let s = await game.state();
  expect(s.economy.money).toBe(0);
  const farm = s.buildings.buildings[0];
  expect(farm.state).toBe('constructing');
  expect(farm.build_end - farm.build_start).toBe(5000);
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
