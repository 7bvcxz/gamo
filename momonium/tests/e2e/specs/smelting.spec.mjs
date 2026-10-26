// Step 26: a smelter short of ore says so (marker, details: takes 1/2, short);
// with ore and fuel in the store a tap charges it -- inputs leave the store at
// once -- and an ingot comes out after the smelt. The demo island has a
// staffed smelter to try the chain in the browser.
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('smelt copper', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_place_building', ['smelter', 1, 0]);
  await game.query('dev_add_items', { copper_ore: 1, wood: 2 });
  // A real tap on the smelter: selected, and it says it cannot be charged.
  await game.page.waitForTimeout(200);
  const at = await clearPointOnCell(game, [1, 0]);
  await game.tap(at.x, at.y);
  await game.page.waitForTimeout(200);
  const r = (await game.query('selection')).result;
  expect(r.reason).toBe('err.missing_inputs');
  expect(r.missing).toEqual({ copper_ore: 1 });
  // Details from the building's name: what it takes and what it lacks.
  let p = await game.query('panels');
  expect(p.context_title.length).toBe(4);
  const t = await centre(game, p.context_title, p.window);
  await game.tap(t.x, t.y);
  await game.page.waitForTimeout(250);
  const d = await game.query('details');
  expect(Object.keys(d.varieties)).toEqual([]);
  p = await game.query('panels');
  expect(p.detail_open).toBe(true);
  await game.query('dev_add_items', { copper_ore: 1 });
  const close = await centre(game, p.close, p.window);
  await game.tap(close.x, close.y);
  await game.page.waitForTimeout(150);
  // The lit Smelt card charges it.
  const sel = await game.query('selection');
  const card = await centre(game, sel.cards[0], sel.window);
  await game.tap(card.x, card.y);
  await game.page.waitForTimeout(150);
  let s = await game.state();
  expect(s.inventory.items.copper_ore ?? 0).toBe(0);
  expect(s.inventory.items.wood).toBe(1);
  // The recipe's seconds times the work scale (Step 58: 10 s -> 25 s).
  const scale = (await game.query('rules')).work_scale;
  await game.query('dev_advance_ms', Math.ceil(10000 * scale));
  s = await game.state();
  expect(s.inventory.items.copper_ingot).toBe(1);
});
