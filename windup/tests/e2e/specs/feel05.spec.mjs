// Step 05: the feel layer in the real web build -- the wordless volume and
// motion icons (and that they persist), the music box (silent while the
// atelier sleeps, audible once a doll is up: measured as signal), the gear
// train. Evidence with WINDUP_EVIDENCE=1 goes to windup/evidence/step05/.
import { test, expect } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import { openGame, state, call } from '../lib/game.mjs';
import { AUDIO_TAP, loudness } from '../lib/audio_tap.mjs';

const evidence = process.env.WINDUP_EVIDENCE
  ? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../evidence/step05')
  : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../test-results/evidence/step05');

async function pointOf(page, name, arg) {
  const r = await call(page, name, arg);
  const box = await page.locator('canvas').boundingBox();
  return { x: box.x + r.x * box.width, y: box.y + r.y * box.height };
}

test('icons, music box and gears', async ({ page: first }, info) => {
  let page = first;
  await page.addInitScript(AUDIO_TAP);
  const { errors } = await openGame(page, '?fresh=1');
  const tap = (p) => info.project.use.hasTouch ? page.touchscreen.tap(p.x, p.y) : page.mouse.click(p.x, p.y);
  fs.mkdirSync(evidence, { recursive: true });

  // A first press anywhere wakes the browser's audio; then the asleep atelier is silent.
  await page.mouse.click(5, 5);
  await page.waitForTimeout(300);
  const silent = await loudness(page, 2500);
  expect((await state(page)).music_notes).toBe(0);

  // One doll up: the music box starts, heard with nobody winding.
  await call(page, 'dev_wind', 80);
  await call(page, 'dev_advance', 2.0);
  expect((await state(page)).awake).toBe(1);
  expect((await state(page)).gears).toBe(1);
  await page.waitForTimeout(800);
  const music = await loudness(page, 4000);
  expect((await state(page)).music_notes).toBeGreaterThan(0);
  expect(music.rms).toBeGreaterThan(0.003);
  expect(music.rms).toBeGreaterThan(silent.rms * 5 + 0.001);

  // The speaker: full -> half -> off; the star: reduce motion. Kept for the next visit.
  const vol = await pointOf(page, 'icon_point', 'volume');
  await tap(vol);
  await expect.poll(async () => (await state(page)).settings.volume).toBe(0.5);
  await tap(vol);
  await expect.poll(async () => (await state(page)).settings.volume).toBe(0);
  const muted = await loudness(page, 2000);
  const mot = await pointOf(page, 'icon_point', 'motion');
  await tap(mot);
  await expect.poll(async () => (await state(page)).settings.reduced_motion).toBe(true);
  await page.screenshot({ path: path.join(evidence, `icons_${info.project.name}.png`) });
  expect((await state(page)).awake).toBe(1);       // the icons did not wind or restart
  // user:// reaches IndexedDB asynchronously (slower on a loaded machine): look
  // from new pages until the last change has arrived, up to ~20 s.
  let s = null;
  for (let attempt = 0; attempt < 5; attempt++) {
    await page.waitForTimeout(2000 + attempt * 2000);
    const again = await page.context().newPage();
    await again.goto('index.html');
    await again.waitForFunction(() => window.windup && window.windup.ready === true, null, { timeout: 120_000 });
    s = await state(again);
    if (attempt < 4 && !(s.settings.reduced_motion && s.settings.volume === 0)) { await again.close(); continue; }
    await page.close();
    page = again;
    break;
  }
  expect(s.settings.volume).toBe(0);
  expect(s.settings.reduced_motion).toBe(true);
  fs.writeFileSync(path.join(evidence, `feel_${info.project.name}.json`), JSON.stringify({
    silent_asleep: silent, music_one_doll: music, muted, settings_after_reload: s.settings }, null, 2) + '\n');
  expect(muted.rms).toBeLessThan(0.001);
  expect(errors).toEqual([]);
});
