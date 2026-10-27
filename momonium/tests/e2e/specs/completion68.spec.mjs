// Step 68: tap, tap, THUNK -- measured at the speakers (lib/audio_tap.mjs) in
// the real web build. While a Momo digs, its pickaxe's strikes are quiet taps;
// when the simulation finishes the dig, the THUNK is heard in that moment,
// louder than the taps, with one ring at the mine and the money once; a job
// cut short (the mine pulled down mid-dig) gives none of it.
import { test, expect } from '@playwright/test';
import { AUDIO_TAP, loudness } from '../lib/audio_tap.mjs';

async function open(page) {
  await page.addInitScript(AUDIO_TAP);
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.call === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(600);
  const call = (n, a) => page.evaluate(([x, y]) => window.momonium.call(x, y), [n, a]);
  // A first touch for the browser; the music and the sea out of the way.
  const box = await page.locator('canvas').boundingBox();
  await page.mouse.click(box.x + box.width / 2, box.y + box.height * 0.2);
  await page.evaluate(() => window.momonium.setTimeScale(0));
  await call('dev_audio_setting', ['music_volume', 0.0]);
  await call('dev_audio_setting', ['ambience_volume', 0.0]);
  return call;
}

async function mineAtWork(page, call) {
  const command = (c) => page.evaluate((cmd) => window.momonium.command(cmd), c);
  await call('dev_grow_island', 3);
  await call('dev_add_momo', [1.5, 1.5]);
  const { id } = await call('dev_place_building', ['mine', 2, 1]);
  const momo = Number(Object.keys((await call('momos')).momos)[0]);
  expect((await command({ type: 'momo.assign', momo, building: id })).ok).toBe(true);
  for (let i = 0; i < 200; i++) {
    await call('dev_advance_ms', 250);
    if ((await call('momos')).momos[String(momo)].state === 'work') break;
  }
  expect((await call('momos')).momos[String(momo)].state).toBe('work');
  return { id, momo };
}

const thunks = async (call) => (await call('audio')).played.thunk ?? 0;

test('tap, tap, THUNK', async ({ page }) => {
  const call = await open(page);
  const { id } = await mineAtWork(page, call);
  await page.waitForTimeout(500);
  // The work: a few seconds of strikes, the simulation standing still.
  const taps0 = (await call('audio')).played.tap_pick ?? 0;
  const work = await loudness(page, 3000);
  const taps = ((await call('audio')).played.tap_pick ?? 0) - taps0;
  expect(taps, 'the pickaxe tapped as it struck').toBeGreaterThanOrEqual(2);
  expect(work.rms, `taps heard, quietly (rms ${work.rms.toFixed(4)})`).toBeGreaterThan(0.004);
  // The end of the dig: the THUNK in the moment it happens.
  const fx0 = await call('fx');
  const pops0 = fx0.world.filter((p) => p.kind === 'money').length;
  const imp0 = fx0.impacts[String(id)] ?? 0;
  const t0 = await thunks(call);
  let heard = null;
  for (let i = 0; i < 400 && heard === null; i++) {
    const listening = loudness(page, 450);
    await call('dev_advance_ms', 250);
    const l = await listening;
    if ((await thunks(call)) > t0) heard = l;
  }
  expect(heard, 'the dig finished').not.toBeNull();
  expect(await thunks(call), 'one THUNK').toBe(t0 + 1);
  expect(heard.rms, `THUNK (rms ${heard.rms.toFixed(4)}) over the taps (${work.rms.toFixed(4)})`).toBeGreaterThan(work.rms * 1.3);
  const fx1 = await call('fx');
  expect((fx1.impacts[String(id)] ?? 0) - imp0, 'one ring at the mine').toBe(1);
  expect(fx1.world.filter((p) => p.kind === 'money').length - pops0, 'the money it earned, once').toBe(1);
});

test('a job cut short finishes nothing', async ({ page }) => {
  const call = await open(page);
  // Taking the Momo off is not cutting the job short: the dig it started
  // still finishes and pays (a real THUNK). Pulling the mine down is.
  const { id } = await mineAtWork(page, call);
  const t0 = await thunks(call);
  expect((await page.evaluate((cmd) => window.momonium.command(cmd), { type: 'building.demolish', id })).ok).toBe(true);
  await call('dev_advance_ms', 60000);
  expect(await thunks(call), 'no THUNK').toBe(t0);
  expect((await call('fx')).impacts[String(id)], 'no ring (and no mine)').toBeUndefined();
});
