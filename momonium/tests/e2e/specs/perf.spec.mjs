// Step 41: the large island demo (Settings) -- a big, busy island of the four
// kinds the player places and many Momo, never saved -- with the performance
// readout from Settings: what is out of sight stops animating (zoomed in with
// the view buttons, far fewer buildings and Momo are awake), and the way back
// leads to the player's own island untouched.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('large island demo with the performance readout', async ({ game }) => {
  await game.query('set_language', 'en');
  const own = await game.state();
  const hud = await game.query('hud');
  const openSettings = async () => {
    const gear = await centre(game, hud.buttons.settings, hud.window);
    await game.tap(gear.x, gear.y);
    await game.page.waitForTimeout(300);
    return game.query('settings_ui');
  };
  let st = await openSettings();
  expect(st.large_demo.length).toBe(4);
  const large = await centre(game, st.large_demo, st.window);
  await game.tap(large.x, large.y);
  await game.page.waitForFunction(() => window.momonium && window.momonium.call && window.momonium.call('settings_ui').demo_kind === 'large', null, { timeout: 60_000 });
  await game.page.waitForTimeout(800);
  const s = await game.state();
  const kinds = [...new Set(s.buildings.buildings.map((b) => b.type))].sort();
  expect(kinds).toEqual(['farm', 'lumberyard', 'mine', 'research']);
  expect(s.buildings.buildings.length).toBeGreaterThan(150);
  st = await game.query('settings_ui');
  expect(st.badge_text).toBe('LARGE DEMO');
  // Settings: show performance, and the view buttons to zoom with taps.
  st = await openSettings();
  await game.query('dev_settings_reveal', 'Performance');
  await game.page.waitForTimeout(150);
  st = await game.query('settings_ui');
  expect(st.perf.length).toBe(4);
  const perfToggle = await centre(game, st.perf, st.window);
  await game.tap(perfToggle.x, perfToggle.y);
  await game.page.waitForTimeout(200);
  await game.query('dev_settings_reveal', 'CameraButtons');
  await game.page.waitForTimeout(150);
  let o = await game.query('options');
  expect(o.toggles.camera_buttons.length).toBe(4);
  const cam = await centre(game, o.toggles.camera_buttons, o.window);
  await game.tap(cam.x, cam.y);
  await game.page.waitForTimeout(200);
  await openSettings(); // closes it
  await game.page.waitForTimeout(1200);
  let p = await game.query('perf');
  expect(p.visible).toBe(true);
  expect(p.text).toContain('fps');
  expect(p.shown.buildings).toBe(s.buildings.buildings.length);
  const all = p.now.buildings_awake;
  expect(all).toBe(p.now.buildings);
  // Zoom in with the + button: most of the island is out of sight now.
  // (Step 56: the island is framed nearer the middle of the screen, so the
  // zoom centres on its busy middle -- eight taps left most of it in view.)
  o = await game.query('options');
  for (let i = 0; i < 14; i++) {
    const plus = await centre(game, o.pad.in, o.window);
    await game.tap(plus.x, plus.y);
    await game.page.waitForTimeout(120);
  }
  await game.page.waitForTimeout(400);
  p = await game.query('perf');
  expect(p.now.buildings_awake).toBeLessThan(all / 2);
  expect(p.now.momos_awake).toBeLessThan(p.now.momos);
  console.log(`large demo: ${p.now.buildings} buildings, ${p.now.momos} Momo; zoomed in ${p.now.buildings_awake} / ${p.now.momos_awake} awake; ${p.now.fps} fps`);
  // Back to the player's own island, as it was.
  st = await openSettings();
  expect(st.demo_text).toBe('Back to my island');
  // The panel keeps where it was scrolled (down at the view buttons); on a
  // desktop's larger UI (Step 54) the button is above that, out of sight.
  await game.query('dev_settings_reveal', 'Demo');
  await game.page.waitForTimeout(150);
  st = await game.query('settings_ui');
  const back = await centre(game, st.demo, st.window);
  await game.tap(back.x, back.y);
  await game.page.waitForFunction(() => window.momonium && window.momonium.call && window.momonium.call('settings_ui').in_demo === false, null, { timeout: 60_000 });
  const mine = await game.state();
  expect(mine.buildings.buildings.length).toBe(own.buildings.buildings.length);
  expect(mine.economy.money).toBe(own.economy.money);
  // Turn the options back off for the next test in this browser profile.
  await game.query('dev_max_fps', 0);
});
