// Step 39: Settings has Sound -- a tap on the Ambience slider sets its volume
// (the bus follows), the mute toggle silences everything; building a farm
// from the strip is heard (the effect plays); the music runs.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

const toCss = async (game, x, y, win) => {
  const box = await game.canvas.boundingBox();
  return { x: x * (box.width / win[0]), y: y * (box.height / win[1]) };
};

test('sound settings and sounds', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const cell = await cellToCanvas(game, [1, 1]);
  await game.tap(cell.x, cell.y);
  await game.page.waitForTimeout(250);
  const strip = await game.query('strip');
  const farm = await toCss(game, strip.buttons.farm.rect[0] + strip.buttons.farm.rect[2] / 2, strip.buttons.farm.rect[1] + strip.buttons.farm.rect[3] / 2, strip.window);
  await game.tap(farm.x, farm.y);
  await game.page.waitForTimeout(250);
  let a = await game.query('audio');
  expect(a.played.build).toBeGreaterThanOrEqual(1);
  expect(a.played.click ?? 0).toBeGreaterThanOrEqual(1);
  expect(a.music).toBe(true);
  // Settings -> Sound.
  const hud = await game.query('hud');
  const gear = await toCss(game, hud.buttons.settings[0] + hud.buttons.settings[2] / 2, hud.buttons.settings[1] + hud.buttons.settings[3] / 2, hud.window);
  await game.tap(gear.x, gear.y);
  await game.page.waitForTimeout(400);
  a = await game.query('audio');
  const r = a.sliders.ambience_volume.rect;
  expect(r.length).toBe(4);
  const p = await toCss(game, r[0] + r[2] * 0.25, r[1] + r[3] / 2, a.window);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(250);
  a = await game.query('audio');
  expect(a.settings.ambience_volume).toBeGreaterThan(0.1);
  expect(a.settings.ambience_volume).toBeLessThan(0.45);
  expect(a.buses.Ambience.db).toBeLessThan(-6);
  const m = await toCss(game, a.mute[0] + a.mute[2] / 2, a.mute[1] + a.mute[3] / 2, a.window);
  await game.tap(m.x, m.y);
  await game.page.waitForTimeout(250);
  a = await game.query('audio');
  expect(a.settings.muted).toBe(true);
  expect(a.master_mute).toBe(true);
});
