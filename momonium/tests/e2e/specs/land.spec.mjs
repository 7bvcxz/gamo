// Step 12: Land opens the buy mode; a real tap chooses a cell next to the
// island, Buy takes the money and the island grows; unaffordable is refused.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('buy a cell next to the island', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_add_money', 90);
  const hud = await game.query('hud');
  const land = await centre(game, hud.buttons.land, hud.window);
  await game.tap(land.x, land.y);
  await game.page.waitForTimeout(150);
  expect((await game.query('land_mode')).active).toBe(true);
  const cell = await cellToCanvas(game, [2, 0]);
  await game.tap(cell.x, cell.y);
  await game.page.waitForTimeout(150);
  let m = await game.query('land_mode');
  expect(m.chosen).toEqual([2, 0]);
  expect(m.buy_disabled).toBe(false);
  const buy = await centre(game, m.buy, m.window);
  await game.tap(buy.x, buy.y);
  await game.page.waitForTimeout(200);
  const s = await game.state();
  expect(s.world.land.some(([x, y]) => x === 2 && y === 0)).toBe(true);
  expect(s.economy.money).toBe(50);
  m = await game.query('land_mode');
  expect(m.cost).toBe(65);
});

test('cannot buy without the money', async ({ game }) => {
  await game.setTimeScale(0);
  const hud = await game.query('hud');
  const land = await centre(game, hud.buttons.land, hud.window);
  await game.tap(land.x, land.y);
  const cell = await cellToCanvas(game, [0, 2]);
  await game.tap(cell.x, cell.y);
  await game.page.waitForTimeout(150);
  const m = await game.query('land_mode');
  expect(m.chosen).toEqual([0, 2]);
  expect(m.buy_disabled).toBe(true);
  const r = await game.command({ type: 'land.buy', cell: [0, 2] });
  expect(r.ok).toBe(false);
  expect(r.reason).toBe('err.not_enough_money');
  expect((await game.state()).world.land.length).toBe(4);
});
