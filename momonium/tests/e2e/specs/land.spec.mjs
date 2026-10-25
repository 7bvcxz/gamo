// Step 12 / 31: the sea beside the island is bought where it is. A mouse
// hovering a sea tile that touches the island sees the block and its price
// and a click buys it at once; a finger's first tap previews ("tap again"),
// the second buys. Not enough money is shown and refused; a tile touching
// only by a corner, or open sea, is never offered.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

async function hoverOrTap(game, cell, touch) {
  const p = await cellToCanvas(game, cell);
  if (touch) return game.tap(p.x, p.y);
  const box = await game.canvas.boundingBox();
  await game.page.mouse.move(box.x + p.x, box.y + p.y, { steps: 4 });
}

async function clickOrTap(game, cell, touch) {
  const p = await cellToCanvas(game, cell);
  if (touch) return game.tap(p.x, p.y);
  const box = await game.canvas.boundingBox();
  await game.page.mouse.click(box.x + p.x, box.y + p.y);
}

test('buy the sea beside the island where it is', async ({ game }, info) => {
  const touch = info.project.use.hasTouch;
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_add_money', 90);
  const hud = await game.query('hud');
  expect(hud.buttons.land).toBeUndefined();
  // Hover (mouse) or first tap (finger): a preview with the price, nothing bought.
  await hoverOrTap(game, [2, 0], touch);
  await game.page.waitForTimeout(200);
  let b = await game.query('land_buy');
  expect(b.focus).toEqual([2, 0]);
  expect(b.price).toBe('$50');
  expect(b.affordable).toBe(true);
  if (touch) expect(b.hint).toBe('Tap again to buy');
  expect((await game.state()).world.land.length).toBe(4);
  // Click (mouse) or second tap (finger): bought.
  await clickOrTap(game, [2, 0], touch);
  await game.page.waitForTimeout(250);
  const s = await game.state();
  expect(s.world.land.some(([x, y]) => x === 2 && y === 0)).toBe(true);
  expect(s.economy.money).toBe(50);
  b = await game.query('land_buy');
  expect(b.cost).toBe(65);
  expect(b.focus).toEqual([]);
});

test('not enough money, and never a tile apart', async ({ game }, info) => {
  const touch = info.project.use.hasTouch;
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await hoverOrTap(game, [0, 2], touch);
  await game.page.waitForTimeout(200);
  let b = await game.query('land_buy');
  expect(b.focus).toEqual([0, 2]);
  expect(b.affordable).toBe(false);
  expect(b.hint).toBe('Not enough money');
  await clickOrTap(game, [0, 2], touch);
  await game.page.waitForTimeout(200);
  b = await game.query('land_buy');
  expect(b.result.reason).toBe('err.not_enough_money');
  expect((await game.state()).world.land.length).toBe(4);
  await game.query('dev_add_money', 500);
  await hoverOrTap(game, [2, 2], touch);
  await game.page.waitForTimeout(150);
  expect((await game.query('land_buy')).focus).toEqual([]);
  await clickOrTap(game, [2, 2], touch);
  await clickOrTap(game, [2, 2], touch);
  await game.page.waitForTimeout(200);
  expect((await game.state()).world.land.length).toBe(4);
});
