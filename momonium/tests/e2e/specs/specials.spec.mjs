// Step 35: an empty tile -> five choices -> Special -> back arrow first, then
// the landmarks with prices -> build a School with a tap; it is no longer
// offered and the slot is full; trash -> check pulls it down for half; it is
// offered again but waits before it can rise.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};
const tapRect = async (game, rect, win) => {
  const p = await centre(game, rect, win);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(250);
};

test('build a landmark from the Special choices', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_grow_island', 3);
  await game.query('dev_level', 6);
  await game.query('dev_add_money', 3000);
  await game.query('dev_add_items', { stone: 50, wood: 50, copper_ingot: 10 });
  const cell = await cellToCanvas(game, [1, 1]);
  await game.tap(cell.x, cell.y);
  await game.page.waitForTimeout(250);
  let s = await game.query('strip');
  expect(s.special.length).toBe(4);
  await tapRect(game, s.special, s.window);
  s = await game.query('strip');
  expect(s.mode).toBe('special');
  expect(s.back.length).toBe(4);
  expect(s.back[0]).toBeLessThan(s.specials.clock_tower.rect[0]);
  expect(Object.keys(s.specials).sort()).toEqual(['clock_tower', 'momo_monument', 'school']);
  expect(s.specials.school.price).toContain('$400');
  await tapRect(game, s.specials.school.rect, s.window);
  let st = await game.state();
  const school = st.buildings.buildings.find((b) => b.type === 'school');
  expect(school.anchor).toEqual([1, 1]);
  await game.query('dev_advance_ms', (await game.query('rules')).build_ms.school + 1000);
  // Another tile: the school is not offered, the slot is full.
  const other = await cellToCanvas(game, [0, 1]);
  await game.tap(other.x, other.y);
  await game.page.waitForTimeout(250);
  s = await game.query('strip');
  await tapRect(game, s.special, s.window);
  s = await game.query('strip');
  expect(s.specials.school).toBeUndefined();
  expect(s.specials.clock_tower.price).toBe('No slot (1/1)');
  // Pull it down: half back, offered again, but it waits.
  await tapRect(game, s.back, s.window);
  await game.query('dev_select_cell', [1, 1]);
  await game.page.waitForTimeout(250);
  let ui = await game.query('strip');
  const before = (await game.state()).economy.money;
  await tapRect(game, ui.trash, ui.window);
  ui = await game.query('strip');
  await tapRect(game, ui.confirm, ui.window);
  st = await game.state();
  expect(st.buildings.buildings.find((b) => b.type === 'school')).toBeUndefined();
  expect(st.economy.money - before).toBe(200);
  await game.tap(cell.x, cell.y);
  await game.page.waitForTimeout(250);
  s = await game.query('strip');
  await tapRect(game, s.special, s.window);
  s = await game.query('strip');
  expect(s.specials.school.price).toMatch(/^Again in/);
  expect(s.specials.school.disabled).toBe(true);
});
