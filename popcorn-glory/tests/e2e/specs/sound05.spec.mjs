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
  // Whatever the release was judged (a real-time hold on a loaded machine can
  // miss the gold by a few frames), its outcome sound played: the chime for a
  // perfect or near miss, the thud for early, a pop for late, the hiss for burnt.
  const p = s.sound.played;
  const outcome = (p.ding ?? 0) + (p.thud ?? 0) + (p.pop_1 ?? 0) + (p.hiss ?? 0);
  expect(outcome, `an outcome sound (${JSON.stringify(s.run.outcomes)})`).toBeGreaterThan(0);
});

// Step 10: the stand -- shaking clinks, and the helper is heard popping by itself while the
// hands are off the screen.
test('stand: the shake clinks and the helper pops on its own', async ({ pop }, testInfo) => {
  await pop.open('./#stand');
  await pop.tap('play');                      // unlock audio
  await pop.page.waitForTimeout(700);
  await pop.call('dev_level', 4);
  await pop.call('dev_money', 100000);
  // Shake by dragging while held.
  const s0 = await pop.state();
  const r = s0.rects.play;
  const box = await pop.canvas.boundingBox();
  const k = box.width / s0.window[0];
  const x = box.x + (r[0] + r[2] / 2) * k; const y = box.y + (r[1] + r[3] * 0.6) * k;
  const touch = testInfo.project.use.hasTouch;
  const cdp = touch ? await pop.cdp() : null;
  if (touch) await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
  else { await pop.page.mouse.move(x, y); await pop.page.mouse.down(); }
  for (const dx of [70, -70, 70]) {
    if (touch) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x + dx * k, y }] });
    else await pop.page.mouse.move(x + dx * k, y, { steps: 3 });
    await pop.page.waitForTimeout(120);
  }
  await pop.page.waitForTimeout(800);
  if (touch) await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  else await pop.page.mouse.up();
  await expect.poll(async () => (await pop.state()).sound.played.clink ?? 0, { message: 'the shake clinks' }).toBeGreaterThanOrEqual(3);
  // The motor, then the helper; then listen with no input at all.
  await pop.tap('auto');
  await pop.page.waitForTimeout(300);
  await pop.tap('auto');
  await expect.poll(async () => (await pop.state()).run.helper_level).toBe(1);
  await pop.page.waitForTimeout(500);
  const heard = await listen(pop.page);
  const m = await heard(3600);                // one helper cycle (3.0 s) and a little
  const s = await pop.state();
  expect(s.run.helper_batches, 'the helper popped while listening').toBeGreaterThanOrEqual(1);
  expect(m.rms, `rms ${m.rms.toFixed(4)} peak ${m.peak.toFixed(3)} with no input`).toBeGreaterThan(LOUD);
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

test('the speaker button steps loud -> soft -> off, and back on', async ({ pop }) => {
  await pop.open('./#click');
  await pop.tap('play');
  await pop.page.waitForTimeout(300);
  await pop.tap('sound');
  await expect.poll(async () => (await pop.state()).sound.level).toBe('soft');
  let soft = await listen(pop.page);
  await pop.tap('play');
  const s = await soft(500);
  expect(s.rms, `soft rms ${s.rms.toFixed(4)}`).toBeGreaterThan(0.002);
  await pop.tap('sound');
  await expect.poll(async () => (await pop.state()).sound.muted).toBe(true);
  await pop.page.waitForTimeout(600);
  let heard = await listen(pop.page);
  for (let i = 0; i < 4; i++) await pop.tap('play');
  let m = await heard(500);
  expect(m.rms, `muted rms ${m.rms.toFixed(5)}`).toBeLessThan(0.001);
  await pop.tap('sound');
  await expect.poll(async () => (await pop.state()).sound.level).toBe('loud');
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
