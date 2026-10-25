// Step 27: power is reachable in the browser -- the demo island (Settings)
// has sun, wind, a boiler and a water wheel; the power pill under the day
// card opens the panel with supply, draw and each generator.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('power on the demo island', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  let pw = await game.query('power');
  expect(pw.pill).toBe(false);
  const hud = await game.query('hud');
  const gear = await centre(game, hud.buttons.settings, hud.window);
  await game.tap(gear.x, gear.y);
  await game.page.waitForTimeout(300);
  const st = await game.query('settings_ui');
  const demo = await centre(game, st.demo, st.window);
  await game.tap(demo.x, demo.y);
  await game.page.waitForFunction(() => window.momonium && window.momonium.call && window.momonium.call('settings_ui').in_demo === true, null, { timeout: 30_000 });
  await game.setTimeScale(0);
  await game.page.waitForTimeout(400);
  pw = await game.query('power');
  expect(pw.pill).toBe(true);
  expect(pw.capacity).toBe(15);
  const pill = await centre(game, pw.pill_rect, pw.window);
  await game.tap(pill.x, pill.y);
  await game.page.waitForTimeout(300);
  pw = await game.query('power');
  expect(pw.open).toBe(true);
  expect(pw.head).toMatch(/^Supply [\d.]+ kW · Draw [\d.]+ kW · Share \d+%$/);
  const s = await game.state();
  const types = s.buildings.buildings.map((b) => b.type);
  for (const t of ['solar_panel', 'wind_turbine', 'steam_engine', 'water_wheel']) expect(types).toContain(t);
});
