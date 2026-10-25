// Step 42: the same game on many screens -- a small and a tall phone, a
// tablet both ways, a laptop and a wide desktop. At each size the HUD sits
// inside the window with nothing overlapping, the island is in view, and a
// tap on Settings opens it and a second closes it.
import { test, expect } from '../lib/fixtures.mjs';

const SIZES = [[360, 640], [412, 915], [768, 1024], [1024, 768], [1366, 768], [1920, 1080]];

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};
const inside = (r, w) => r[0] >= -1 && r[1] >= -1 && r[0] + r[2] <= w[0] + 1 && r[1] + r[3] <= w[1] + 1;
const overlap = (a, b) => a[0] < b[0] + b[2] - 1 && b[0] < a[0] + a[2] - 1 && a[1] < b[1] + b[3] - 1 && b[1] < a[1] + a[3] - 1;

test('every screen size', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  for (const [w, h] of SIZES) {
    await game.page.setViewportSize({ width: w, height: h });
    await game.page.waitForTimeout(700);
    const hud = await game.query('hud');
    const rects = { ...hud.buttons, ...Object.fromEntries(Object.entries(hud.pills).map(([k, v]) => ['pill_' + k, v])) };
    for (const [k, r] of Object.entries(rects)) {
      expect(inside(r, hud.window), `${w}x${h}: ${k} ${r} inside ${hud.window}`).toBe(true);
    }
    const names = Object.keys(rects);
    for (let i = 0; i < names.length; i++) {
      for (let j = i + 1; j < names.length; j++) {
        expect(overlap(rects[names[i]], rects[names[j]]), `${w}x${h}: ${names[i]} and ${names[j]} overlap`).toBe(false);
      }
    }
    const cam = await game.query('camera');
    expect(cam.zoom, `${w}x${h}: the island is framed`).toBeGreaterThan(0);
    const island = await game.query('cell_screen', [0, 0]);
    expect(inside([island.x, island.y, 1, 1], island.window), `${w}x${h}: the island is in view`).toBe(true);
    const gear = await centre(game, hud.buttons.settings, hud.window);
    await game.tap(gear.x, gear.y);
    await game.page.waitForTimeout(250);
    expect((await game.query('settings_ui')).open, `${w}x${h}: Settings opens`).toBe(true);
    await game.tap(gear.x, gear.y);
    await game.page.waitForTimeout(250);
    expect((await game.query('settings_ui')).open, `${w}x${h}: and closes`).toBe(false);
  }
});
