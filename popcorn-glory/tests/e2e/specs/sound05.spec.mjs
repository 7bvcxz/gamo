// Step 05: the sounds reach the speakers -- measured as signal on the audio
// thread (lib/audio_tap.mjs), not as 'play() was called' (AGENTS.md
// 2026-10-27: a game passed such checks for 26 versions while silent).
// Each experiment's main action makes sound; the mute button and ?sound=off
// silence it.
import { test as base, expect } from '../lib/pop.mjs';
import { AUDIO_TAP, listen } from '../lib/audio_tap.mjs';

const test = base.extend({
  pop: async ({ pop }, use) => {
    await pop.page.addInitScript(AUDIO_TAP);
    await use(pop);
  },
});

// Every project: a phone's first touch must unlock audio as a desktop click
// does (Step 05 addendum: 'Web audio actually plays after a user gesture
// across desktop and mobile').

const LOUD = 0.01;    // RMS over 23 ms; the synthesised pops peak at 0.8

test('A: a press is heard', async ({ pop }) => {
  await pop.open('./#click');
  await pop.tap('play');                       // the first tap also unlocks audio
  await pop.page.waitForTimeout(300);
  const heard = await listen(pop.page);
  await pop.tap('play');
  const m = await heard(500);
  expect(m.rms, `rms ${m.rms.toFixed(4)} peak ${m.peak.toFixed(3)}`).toBeGreaterThan(LOUD);
});

test('B: the sizzle while held, and a perfect pop', async ({ pop }) => {
  await pop.open('./#perfect');
  await pop.tap('play');
  await pop.page.waitForTimeout(700);
  const heard = await listen(pop.page);
  await pop.hold('play', 1625);
  const m = await heard(400);
  expect(m.rms, `rms ${m.rms.toFixed(4)}`).toBeGreaterThan(LOUD);
  const s = await pop.state();
  expect(s.sound.played.sizzle ?? 0).toBeGreaterThan(0);
  expect(s.sound.played.ding ?? 0, 'the perfect chime').toBeGreaterThan(0);
});

test('C: kernels clink and the eruption booms', async ({ pop }) => {
  await pop.open('./#explosion');
  await pop.tap('play');
  await pop.page.waitForTimeout(300);
  for (let i = 0; i < 6; i++) await pop.tap('play');
  const heard = await listen(pop.page);
  await pop.tap('play');
  const m = await heard(700);
  expect(m.rms, `rms ${m.rms.toFixed(4)}`).toBeGreaterThan(LOUD);
  expect((await pop.state()).sound.played.boom ?? 0).toBeGreaterThan(0);
});

test('the mute button silences the game, and turns it back on', async ({ pop }) => {
  await pop.open('./#click');
  await pop.tap('play');
  await pop.page.waitForTimeout(300);
  await pop.tap('sound');
  await expect.poll(async () => (await pop.state()).sound.muted).toBe(true);
  await pop.page.waitForTimeout(600);
  let heard = await listen(pop.page);
  for (let i = 0; i < 4; i++) await pop.tap('play');
  let m = await heard(500);
  expect(m.rms, `muted rms ${m.rms.toFixed(5)}`).toBeLessThan(0.001);
  await pop.tap('sound');
  await expect.poll(async () => (await pop.state()).sound.muted).toBe(false);
  heard = await listen(pop.page);
  await pop.tap('play');
  m = await heard(500);
  expect(m.rms, 'heard again').toBeGreaterThan(LOUD);
});

test('?sound=off starts muted', async ({ pop }) => {
  await pop.open('./?sound=off#click');
  expect((await pop.state()).sound.muted).toBe(true);
  await pop.tap('play');
  await pop.page.waitForTimeout(400);
  const heard = await listen(pop.page);
  for (let i = 0; i < 4; i++) await pop.tap('play');
  const m = await heard(500);
  expect(m.rms).toBeLessThan(0.001);
});
