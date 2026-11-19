// Step 43: the factory's sound, measured as the signal the page sends to the speakers
// (lib/audio_tap.mjs: an AudioWorklet meter, a stereo meter, buffer counts, a recorder) -- never
// as 'play() was called' (AGENTS.md 2026-10-27). design/SOUND.md is the score.
//  1. The first touch wakes the sound (the context is held suspended until then, as a phone
//     does); one machine is a quiet floor, forty-four are a lively one; the hand's pops over the
//     crowd never clip; the voices stay inside their pool. Recorded on the desktop.
//  2. A sound on the left of the screen is louder in the left channel, and on the right, right.
//  3. A hidden tab is silent; the factory is heard again when it comes back.
//  4. Calm (the reduced-audio option): no beds, the hand still heard; the choice survives a reload.
//  5. One sale, one cash sound.
import fs from 'node:fs';
import path from 'node:path';
import { test as base, expect } from '../lib/pop.mjs';
import { AUDIO_TAP, listen, listenStereo, counts, states, startRecord, stopRecord } from '../lib/audio_tap.mjs';

const test = base.extend({
  pop: async ({ pop }, use) => {
    await pop.page.addInitScript(AUDIO_TAP);
    await use(pop);
  },
});

const PLAN = [['M07', 'kitchen'], ['bagger', 'packing'], ['S03', 'shop'], ['M01', 'kitchen'], ['M07', 'kitchen'],
  ['S05', 'shop'], ['M07', 'kitchen'], ['P07', 'packing'], ['M13', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'],
  ['S08', 'shop'], ['M08', 'kitchen'], ['U04', 'packing'], ['S01', 'shop'], ['M06', 'kitchen'], ['M07', 'kitchen'],
  ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['kiosk', 'shop'], ['M14', 'kitchen'], ['U08', 'packing'],
  ['S04', 'shop'], ['M07', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'], ['S06', 'shop'], ['M02', 'kitchen'],
  ['P01', 'packing'], ['kiosk', 'shop'], ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['M03', 'kitchen'],
  ['U05', 'packing'], ['M07', 'kitchen'], ['U03', 'kitchen'], ['bagger', 'packing'], ['M07', 'kitchen'], ['M05', 'kitchen'],
  ['U02', 'kitchen'], ['M07', 'kitchen'], ['P04', 'packing']].map(([t, f]) => [t === 'M07' ? 'cooker' : t, f]);

const LOUD = 0.01;
const OUT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../../evidence/step43/audio');

async function holdKettle(pop) {
  const s = await pop.state();
  if (s.run.heating || Object.keys(s.run.glass).length > 0 || s.run.cooldown_left > 0) return false;
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  return true;
}

// The game's time runs on: machines work, customers come (the clock is real; dev_advance hurries it).
async function hurry(pop, n, ms = 400) {
  for (let i = 0; i < n; i++) {
    await pop.call('dev_advance', ms);
    await pop.page.waitForTimeout(200);
  }
}

test('the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips', async ({ pop }, testInfo) => {
  test.setTimeout(300_000);
  await pop.open('./#factory');
  // As a phone does before any gesture: the context waits.
  await pop.page.evaluate(() => Promise.all(window.__audio.contexts.map((c) => c.suspend())));
  expect(await states(pop.page), 'held until a gesture').not.toContain('running');
  await holdKettle(pop);   // the first touch: a real press on the kettle
  await expect.poll(() => states(pop.page), { message: 'the press wakes the sound' }).toContain('running');
  await hurry(pop, 6);
  // The floor's own sound, no input: its mean loudness (the energy over the window), and its
  // loudest 23 ms (a sale's coin is a moment, the beds are the floor).
  const floor = async () => {
    const st = await listenStereo(pop.page);
    const h = await listen(pop.page);
    const m = await h(4000);
    const e = await st(0);
    return { rms: m.rms, peak: m.peak, mean_rms: e.mean_rms };
  };
  const one = await floor();
  const sOne = (await pop.state()).sound;
  const b = await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
  expect(b.machines).toBe(44);
  await hurry(pop, 10);
  const forty = await floor();
  const sForty = (await pop.state()).sound;
  // The hand over the crowd: pops, the peak measured on the audio thread.
  const rec = testInfo.project.name === 'desktop' ? await startRecord(pop.page) : false;
  let worst = { rms: 0, peak: 0 };
  let pops = 0;
  for (let i = 0; i < 6; i++) {
    const h = await listen(pop.page);
    if (await holdKettle(pop)) pops += 1;
    await pop.call('dev_advance', 400);
    const m = await h(1500);
    worst = { rms: Math.max(worst.rms, m.rms), peak: Math.max(worst.peak, m.peak) };
  }
  if (rec) {
    fs.mkdirSync(OUT, { recursive: true });
    fs.writeFileSync(path.join(OUT, 'factory44_hand_desktop.webm'), await stopRecord(pop.page));
  }
  const s = (await pop.state()).sound;
  testInfo.annotations.push({ type: 'mix', description: JSON.stringify({ one, forty, hand: worst, pops,
    beds_one: sOne.beds, beds_forty: sForty.beds, voices_peak: s.voices_peak, played: s.played, refused: s.refused }) });
  expect(one.peak, `one machine: peak ${one.peak.toFixed(3)}`).toBeLessThan(1.0);
  expect(forty.mean_rms, `forty-four are livelier: mean rms ${one.mean_rms.toFixed(4)} -> ${forty.mean_rms.toFixed(4)}`).toBeGreaterThan(one.mean_rms * 1.5);
  expect(forty.mean_rms, 'and heard').toBeGreaterThan(0.004);
  expect(forty.mean_rms, 'and not a wall of sound').toBeLessThan(0.08);
  expect(forty.peak, `forty-four, no input: peak ${forty.peak.toFixed(3)}`).toBeLessThan(1.0);
  expect(pops, 'the hand popped').toBeGreaterThan(1);
  expect(worst.rms, 'the hand is heard').toBeGreaterThan(LOUD);
  expect(worst.peak, `the hand over forty-four machines: peak ${worst.peak.toFixed(3)} (1.0 = full scale)`).toBeLessThan(1.0);
  expect(s.voices_peak, 'the voices stay in their pool').toBeLessThanOrEqual(16);
  expect((s.played.perfect ?? 0) + (s.played.thud ?? 0) + (s.played.pop_1 ?? 0) + (s.played.hiss ?? 0), 'the outcomes sounded').toBeGreaterThan(0);
  expect(s.played.ding ?? 0, "the factory's kettle: its own grammar").toBe(0);
  expect(pop.errors).toEqual([]);
});

test('a sound on the left is louder on the left, on the right louder on the right', async ({ pop }, testInfo) => {
  await pop.open('./#factory');
  await holdKettle(pop);   // wake the sound
  await pop.page.waitForTimeout(1500);
  const side = async (x) => {
    const h = await listenStereo(pop.page);
    await pop.call('dev_sound', { name: 'serve', x });
    return h(900);
  };
  const left = await side(0.0);
  await pop.page.waitForTimeout(600);
  const right = await side(1.0);
  testInfo.annotations.push({ type: 'pan', description: JSON.stringify({ left, right }) });
  expect(left.energy_left, `left: L ${left.energy_left.toFixed(2)} R ${left.energy_right.toFixed(2)}`).toBeGreaterThan(left.energy_right * 1.5);
  expect(right.energy_right, `right: L ${right.energy_left.toFixed(2)} R ${right.energy_right.toFixed(2)}`).toBeGreaterThan(right.energy_left * 1.5);
  expect(pop.errors).toEqual([]);
});

test('a hidden tab is silent, and the factory is heard again after', async ({ pop }, testInfo) => {
  test.setTimeout(240_000);
  await pop.open('./#factory');
  await holdKettle(pop);
  const b = await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
  expect(b.machines).toBe(44);
  await hurry(pop, 8);
  let h = await listen(pop.page);
  const before = await h(2000);
  await pop.tab(true);
  await pop.page.waitForTimeout(800);
  h = await listen(pop.page);
  const hidden = await h(2500);
  const sh = (await pop.state()).sound;
  await pop.tab(false);
  await pop.page.waitForTimeout(2500);
  h = await listen(pop.page);
  const after = await h(2500);
  testInfo.annotations.push({ type: 'hidden', description: JSON.stringify({ before, hidden, after, paused: sh.paused, beds: sh.beds_playing }) });
  expect(before.rms, 'heard before').toBeGreaterThan(LOUD * 0.5);
  expect(hidden.rms, `hidden: rms ${hidden.rms.toFixed(5)}`).toBeLessThan(0.002);
  expect(after.rms, 'heard again').toBeGreaterThan(LOUD * 0.5);
  expect(pop.errors).toEqual([]);
});

test('calm: no beds, the hand still heard, and the choice survives a reload', async ({ pop }, testInfo) => {
  test.setTimeout(240_000);
  await pop.open('./#factory');
  await holdKettle(pop);
  const b = await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
  expect(b.machines).toBe(44);
  await hurry(pop, 8);
  let h = await listen(pop.page);
  const loud = await h(2500);
  // The speaker button: loud -> soft -> calm.
  await pop.tap('sound');
  await pop.tap('sound');
  await expect.poll(async () => (await pop.state()).sound.level).toBe('calm');
  await pop.page.waitForTimeout(1500);
  h = await listen(pop.page);
  const calmFloor = await h(2500);
  h = await listen(pop.page);
  const popped = await holdKettle(pop);
  const calmHand = await h(1200);
  const s = (await pop.state()).sound;
  testInfo.annotations.push({ type: 'calm', description: JSON.stringify({ loud, calmFloor, calmHand, popped, beds: s.beds_playing, played: s.played }) });
  expect(s.beds_playing, 'calm: no bed plays').toBe(0);
  expect(calmFloor.rms, `the floor is quieter: ${loud.rms.toFixed(4)} -> ${calmFloor.rms.toFixed(4)}`).toBeLessThan(loud.rms);
  expect(calmHand.rms, 'the hand is still heard').toBeGreaterThan(0.002);
  await pop.page.reload();
  await pop.ready();
  expect((await pop.state()).sound.level, 'kept after a reload').toBe('calm');
  expect(pop.errors).toEqual([]);
});

test('one sale, one cash sound', async ({ pop }, testInfo) => {
  test.setTimeout(240_000);
  await pop.open('./#factory');
  await holdKettle(pop);
  await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
  await hurry(pop, 4);
  const s0 = await pop.state();
  await hurry(pop, 40);
  const s1 = await pop.state();
  const sold = s1.run.stats.sold - s0.run.stats.sold;
  const asked = (s1.sound.asked.cash ?? 0) - (s0.sound.asked.cash ?? 0);
  const played = (s1.sound.played.cash ?? 0) - (s0.sound.played.cash ?? 0);
  testInfo.annotations.push({ type: 'cash', description: JSON.stringify({ sold, asked, played }) });
  expect(sold, 'sales').toBeGreaterThan(5);
  expect(asked, 'asked once per sale').toBe(sold);
  expect(played, 'never more than the sales').toBeLessThanOrEqual(sold);
  expect(pop.errors).toEqual([]);
});
