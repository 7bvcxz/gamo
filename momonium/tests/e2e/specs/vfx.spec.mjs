// Step 38: the demo island at night -- warm windows, pennants on the four
// families, the sea's occasional splash -- keeps drawing under a 30 and a 60
// fps cap, and the 30 cap is respected (software GL in headless Chromium, so
// the 60 cap is a ceiling, not a promise).
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

async function measure(game, ms) {
  const a = await game.query('frames');
  await game.page.waitForTimeout(ms);
  const b = await game.query('frames');
  return ((b.drawn - a.drawn) * 1000) / (b.ticks - a.ticks);
}

test('night life at 30 and 60 fps', async ({ game }) => {
  await game.query('set_language', 'en');
  const hud = await game.query('hud');
  const gear = await centre(game, hud.buttons.settings, hud.window);
  await game.tap(gear.x, gear.y);
  await game.page.waitForTimeout(300);
  const st = await game.query('settings_ui');
  const demo = await centre(game, st.demo, st.window);
  await game.tap(demo.x, demo.y);
  await game.page.waitForFunction(() => window.momonium && window.momonium.call && window.momonium.call('settings_ui').in_demo === true, null, { timeout: 30_000 });
  const day = (await game.state()).day ?? 1;
  await game.query('dev_advance_to', [day, 0.82]);
  await game.page.waitForTimeout(500);
  const v = await game.query('vfx');
  expect(v.phase).toBe('night');
  expect(v.night).toBeGreaterThan(0.3);
  expect(Object.values(v.pennants).some((t) => t >= 0)).toBe(true);
  await game.query('dev_max_fps', 30);
  await game.page.waitForTimeout(500);
  const at30 = await measure(game, 2500);
  await game.query('dev_max_fps', 60);
  await game.page.waitForTimeout(500);
  const at60 = await measure(game, 2500);
  console.log(`demo island at night: ${at30.toFixed(1)} fps (cap 30), ${at60.toFixed(1)} fps (cap 60)`);
  // The cap holds, and frames keep coming under both (the effects run on game
  // time, so they look the same at any frame rate). Software GL here reaches
  // ~15 fps on this busy island, old build and new alike (A/B in the report).
  expect(at30).toBeLessThanOrEqual(32);
  expect(at30).toBeGreaterThan(8);
  expect(at60).toBeGreaterThan(8);
  await game.query('dev_max_fps', 0);
});
