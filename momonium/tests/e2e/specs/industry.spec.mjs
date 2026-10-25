// Step 25: mine and lumberyard are in the catalog with their unlock levels
// from the start; the demo island (Settings) lets their later features be
// tried in the browser -- clearly labelled -- and leads back to the player's
// own island untouched.
import { test, expect } from '../lib/fixtures.mjs';

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
  const build = await centre(game, hud.buttons.build, hud.window);
  await game.tap(build.x, build.y);
  await game.page.waitForTimeout(250);
  const ui = await game.query('build_ui');
  expect(ui.cards.mine).toBeTruthy();
  expect(ui.cards.lumberyard).toBeTruthy();
  await game.tap(build.x, build.y);
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
  const r = await game.query('research');
  void r;
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
