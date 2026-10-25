// Step 30: advanced industry is reachable in the browser -- the demo island's
// game studio (crew, power, notes -> releases that pay more with experience)
// and car factory (ingots -> cars sold daily); the studio's details show its
// crew and the next release's revenue.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('studio and car factory on the demo island', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
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
  const s = await game.state();
  const studio = s.buildings.buildings.find((b) => b.type === 'game_studio');
  const plant = s.buildings.buildings.find((b) => b.type === 'car_factory');
  expect(studio.releases).toBeGreaterThan(0);
  expect(plant.completed).toBeGreaterThan(0);
  await game.query('dev_select_cell', studio.anchor);
  await game.page.waitForTimeout(250);
  const p = await game.query('panels');
  const title = await centre(game, p.context_title, p.window);
  await game.tap(title.x, title.y);
  await game.page.waitForTimeout(300);
  const d = await game.query('details');
  expect(d.open).toBe(true);
  expect(d.takes).toMatch(/Crew \d\/2/);
  expect(d.takes).toMatch(/Next release \$\d+ · \d+ released/);
});
