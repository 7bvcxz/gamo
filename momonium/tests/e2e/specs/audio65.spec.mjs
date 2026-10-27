// Step 65: the published game was silent -- music, ambience and effects all
// "played" into buses the web build never had. Measured at the speakers
// (lib/audio_tap.mjs): the first real tap is heard; an effect is heard over
// silence; mute silences and unmute brings it back; a saved mute survives a
// reload and lifts again; the background falls silent; a burst never clips.
import { test, expect } from '@playwright/test';
import { AUDIO_TAP, loudness, states } from '../lib/audio_tap.mjs';

async function open(page, context) {
  await page.addInitScript(AUDIO_TAP);
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.call === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(800);
  return (name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]);
}

async function tapAt(page, info, r, win) {
  const box = await page.locator('canvas').boundingBox();
  const x = box.x + (r[0] + r[2] / 2) * (box.width / win[0]);
  const y = box.y + (r[1] + r[3] / 2) * (box.height / win[1]);
  if (info.project.use.hasTouch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
}

// Sea, away from every button.
async function tapSea(page, info) {
  const box = await page.locator('canvas').boundingBox();
  const x = box.x + box.width * 0.5;
  const y = box.y + box.height * 0.22;
  if (info.project.use.hasTouch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
}

test('the first real tap is heard, even when the browser held sound back', async ({ page }, info) => {
  await open(page);
  // As a browser does before any touch: the audio held.
  await page.evaluate(() => Promise.all(window.__audio.contexts.map((c) => c.suspend())));
  expect(await states(page)).toEqual(['suspended']);
  await tapSea(page, info);
  await expect.poll(() => states(page), { timeout: 3_000 }).toEqual(['running']);
  const heard = await loudness(page, 1500);
  expect(heard.rms, `music and the sea after the first tap (rms ${heard.rms.toFixed(4)})`).toBeGreaterThan(0.02);
});

test('an effect is heard over silence', async ({ page }, info) => {
  const call = await open(page);
  await tapSea(page, info);
  await call('dev_audio_setting', ['music_volume', 0.0]);
  await call('dev_audio_setting', ['ambience_volume', 0.0]);
  await page.waitForTimeout(600);
  const quiet = await loudness(page, 600);
  expect(quiet.rms, `music and ambience at 0 (rms ${quiet.rms.toFixed(4)})`).toBeLessThan(0.003);
  // A real tap on a HUD button: its click.
  const h = await call('hud');
  const clicks = (await call('audio')).played.click ?? 0;
  const during = loudness(page, 900);
  await tapAt(page, info, h.buttons.status, h.window);
  const click = await during;
  const played = (await call('audio')).played.click ?? 0;
  expect(click.rms, `a button's click (rms ${click.rms.toFixed(4)}, clicks ${clicks} -> ${played})`).toBeGreaterThan(0.01);
  // The island's own sounds: a harvest, research, land, a Momo.
  for (const effect of ['harvest', 'research', 'land', 'momo', 'build']) {
    await page.waitForTimeout(700);
    const during = loudness(page, 700);
    await call('dev_play', [effect]);
    const e = await during;
    expect(e.rms, `${effect} heard (rms ${e.rms.toFixed(4)})`).toBeGreaterThan(0.01);
  }
});

test('mute silences, unmute brings it back, a saved mute survives a reload', async ({ page, context }, info) => {
  const call = await open(page);
  await tapSea(page, info);
  expect((await loudness(page, 800)).rms).toBeGreaterThan(0.02);
  // Settings -> the Mute toggle, with real taps.
  let h = await call('hud');
  await tapAt(page, info, h.buttons.settings, h.window);
  await page.waitForTimeout(500);
  await call('dev_settings_reveal', 'Mute');
  await page.waitForTimeout(200);
  let a = await call('audio');
  await tapAt(page, info, a.mute, a.window);
  await page.waitForTimeout(500);
  expect((await call('audio')).settings.muted).toBe(true);
  const muted = await loudness(page, 800);
  expect(muted.rms, `muted (rms ${muted.rms.toFixed(5)})`).toBeLessThan(0.002);
  a = await call('audio');
  await tapAt(page, info, a.mute, a.window);
  await page.waitForTimeout(500);
  const back = await loudness(page, 800);
  expect(back.rms, `unmuted (rms ${back.rms.toFixed(4)})`).toBeGreaterThan(0.02);
  expect((await call('audio')).music, 'the same music, not a second copy').toBe(true);
  // Mute, reload: still silent after the first tap; unmute: heard.
  await call('dev_audio_setting', ['muted', true]);
  await page.waitForTimeout(300);
  const again = await context.newPage();
  const call2 = await open(again);
  await tapSea(again, info);
  await again.waitForTimeout(500);
  expect((await call2('audio')).settings.muted, 'the saved mute').toBe(true);
  expect((await loudness(again, 800)).rms, 'silent after a reload').toBeLessThan(0.002);
  await call2('dev_audio_setting', ['muted', false]);
  await again.waitForTimeout(400);
  expect((await loudness(again, 800)).rms, 'heard once unmuted').toBeGreaterThan(0.02);
  await call2('dev_audio_setting', ['muted', false]);
});

test('quiet in the background, back in front; a burst never clips', async ({ page }, info) => {
  const call = await open(page);
  await tapSea(page, info);
  expect((await loudness(page, 600)).rms).toBeGreaterThan(0.02);
  // A tab switch or another app in front: the game's canvas loses focus.
  await page.evaluate(() => document.querySelector('canvas').dispatchEvent(new FocusEvent('blur')));
  await page.waitForTimeout(500);
  expect((await call('audio')).master_mute, 'the background rule').toBe(true);
  expect((await loudness(page, 600)).rms, 'silent in the background').toBeLessThan(0.002);
  await page.evaluate(() => document.querySelector('canvas').dispatchEvent(new FocusEvent('focus')));
  await page.waitForTimeout(500);
  expect((await loudness(page, 600)).rms, 'heard again in front').toBeGreaterThan(0.02);
  // Many things at once: loud, never clipping.
  const during = loudness(page, 1200);
  await call('dev_play', ['harvest', 'coin', 'build', 'built', 'research', 'land', 'momo', 'promote']);
  const burst = await during;
  expect(burst.peak, `the burst's peak ${burst.peak.toFixed(3)}`).toBeLessThan(0.99);
});
