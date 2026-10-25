// Step 25 / 30: mine and lumberyard are among the four choices of an empty
// tile, with their unlock levels, from the start; the demo island (Settings)
// lets their later features be tried in the browser -- clearly labelled --
// including refitting a lab into one of its facilities, and leads back to
// the player's own island untouched.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('catalog, demo island and back', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_add_money', 7);
  const own = await game.state();
  const hud = await game.query('hud');
  const tile = await cellToCanvas(game, [1, 1]);
  await game.tap(tile.x, tile.y);
  await game.page.waitForTimeout(250);
  const strip = await game.query('strip');
  expect(strip.buttons.mine.price).toBe('Opens at Lv 3');
  expect(strip.buttons.lumberyard.price).toBe('Opens at Lv 2');
  expect(strip.buttons.research.price).toBe('Opens at Lv 2');
  // Settings -> demo island.
  const gear = await centre(game, hud.buttons.settings, hud.window);
  await game.tap(gear.x, gear.y);
  await game.page.waitForTimeout(300);
  let st = await game.query('settings_ui');
  expect(st.open).toBe(true);
  const demo = await centre(game, st.demo, st.window);
  await game.tap(demo.x, demo.y);
  await game.page.waitForFunction(() => window.momonium && window.momonium.call && window.momonium.call('settings_ui').in_demo === true, null, { timeout: 30_000 });
  st = await game.query('settings_ui');
  expect(st.badge).toBe(true);
  const s = await game.state();
  expect(s.buildings.buildings.map((b) => b.type)).toEqual(expect.arrayContaining(['mine', 'lumberyard', 'research', 'farm', 'smelter']));
  expect(s.inventory.items.copper_ingot ?? 0).toBeGreaterThan(0);
  expect(s.inventory.items.stone).toBeGreaterThan(0);
  // A lab of the demo island: its details list what it can be refitted into.
  await game.setTimeScale(0);
  const lab = s.buildings.buildings.find((b) => b.type === 'research');
  await game.query('dev_select_cell', lab.anchor);
  await game.page.waitForTimeout(250);
  const p = await game.query('panels');
  const title = await centre(game, p.context_title, p.window);
  await game.tap(title.x, title.y);
  await game.page.waitForTimeout(400);
  let d = await game.query('details');
  expect(d.open).toBe(true);
  expect(Object.keys(d.refits)).toEqual(expect.arrayContaining(['solar_panel', 'office', 'apartment', 'community_center', 'game_studio']));
  expect(Object.keys(d.refits)).not.toContain('smelter');
  const open = Object.entries(d.refits).find(([, v]) => !v.disabled);
  expect(open).toBeTruthy();
  const refit = await centre(game, open[1].rect, d.window);
  await game.tap(refit.x, refit.y);
  await game.page.waitForTimeout(300);
  d = await game.query('details');
  expect([open[0], d.result.ok, d.result.reason]).toEqual([open[0], true, '']);
  const after = (await game.state()).buildings.buildings.find((b) => b.id === lab.id);
  expect(after.type).toBe(open[0]);
  expect(after.anchor).toEqual(lab.anchor);
  expect(after.state).toBe('constructing');
  await game.query('dev_advance_ms', 60000);
  // Back to the player's own island.
  await game.setTimeScale(0);
  const hud2 = await game.query('hud');
  const gear2 = await centre(game, hud2.buttons.settings, hud2.window);
  await game.tap(gear2.x, gear2.y);
  await game.page.waitForTimeout(300);
  st = await game.query('settings_ui');
  expect(st.demo_text).toBe('Back to my island');
  const back = await centre(game, st.demo, st.window);
  await game.tap(back.x, back.y);
  await game.page.waitForFunction(() => window.momonium && window.momonium.call && window.momonium.call('settings_ui').in_demo === false, null, { timeout: 30_000 });
  const mine = await game.state();
  expect(mine.economy.money).toBe(own.economy.money);
  expect(mine.buildings.buildings.length).toBe(own.buildings.buildings.length);
});
