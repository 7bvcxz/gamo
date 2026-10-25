// Step 29: Momo life is reachable in the browser -- the demo island has homes,
// a park, a pub and a hall; Status > Life explains the happiness and its
// effect on work.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('life on the demo island', async ({ game }) => {
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
  const hud2 = await game.query('hud');
  const status = await centre(game, hud2.buttons.status, hud2.window);
  await game.tap(status.x, status.y);
  await game.page.waitForTimeout(300);
  let p = await game.query('panels');
  expect(p.tabs.life).toBeTruthy();
  const life = await centre(game, p.tabs.life, p.window);
  await game.tap(life.x, life.y);
  await game.page.waitForTimeout(300);
  p = await game.query('panels');
  expect(p.tab).toBe('life');
  const l = await game.query('life');
  expect(l.happiness).toBeGreaterThan(0);
  expect(l.homes).toBe('8 / 8');
  expect(l.work).toMatch(/^×0\.\d+$/);
});
