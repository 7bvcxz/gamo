// Step 47: the kettle says when it cannot take a press, in a still (the blind players' view).
// Two fresh AI players lost presses to a full glass without seeing why ("my holds were silently
// swallowed", "nothing on screen to say the kettle wasn't ready"): the ring looked ready, and the
// refused press's cue lasted 1.6 s from the press -- after a 1.8 s hold it was gone.
//  1. while a lot waits in the glass the ring is dimmed: its pixels around the circle are less
//     saturated than when the kettle is ready (measured on the canvas, not read from a flag)
//  2. a 1.8 s hold on the waiting kettle is refused, and 0.4 s after the finger lifts the cue is
//     still up (a still taken then shows why)
// Stills go to $POPCORN_SHOTS47 (evidence/step47/ready/).
import fs from 'node:fs';
import path from 'node:path';
import { test, expect } from '../lib/pop.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

const OUT = process.env.POPCORN_SHOTS47 || '';

async function still(pop, testInfo, name) {
  const buf = await pop.page.screenshot();
  if (OUT) { fs.mkdirSync(OUT, { recursive: true }); fs.writeFileSync(path.join(OUT, `${name}_${testInfo.project.name}.png`), buf); }
  return decodePng(buf);
}

// Mean saturation of the pixels on the ring's circle (window px -> page px).
async function ringSat(pop, png) {
  const s = await pop.state();
  const [cx, cy, r] = s.view.ring_geom;
  const box = await pop.canvas.boundingBox();
  const k = (box.width / s.window[0]) * (png.width / (await pop.page.viewportSize()).width);
  let sum = 0;
  let n = 0;
  for (let i = 0; i < 180; i++) {
    const a = (i / 180) * Math.PI * 2;
    const x = Math.round((box.x * png.width) / (await pop.page.viewportSize()).width + (cx + Math.cos(a) * r) * k);
    const y = Math.round((box.y * png.width) / (await pop.page.viewportSize()).width + (cy + Math.sin(a) * r) * k);
    if (x < 0 || y < 0 || x >= png.width || y >= png.height) continue;
    const [R, G, B] = pixel(png, x, y);
    const mx = Math.max(R, G, B); const mn = Math.min(R, G, B);
    sum += mx === 0 ? 0 : (mx - mn) / mx;
    n++;
  }
  return n ? sum / n : 0;
}

test('a waiting kettle dims its ring, and a refused hold shows why after the finger lifts', async ({ pop }, testInfo) => {
  test.skip(!['p720', 'phone', 'desktop'].includes(testInfo.project.name), 'the everyday three');
  test.setTimeout(240_000);
  await pop.open('./#factory');
  await pop.page.waitForTimeout(1500);
  let s = await pop.state();
  for (let i = 0; i < 40 && s.view.ring_waiting; i++) { await pop.page.waitForTimeout(250); s = await pop.state(); }
  expect(s.view.ring_waiting, 'a fresh kettle is ready').toBe(false);
  await pop.page.waitForTimeout(700);   // past any ready flash
  const ready = await ringSat(pop, await still(pop, testInfo, 'ready'));
  // The bin made full, then a pop: its lot waits in the glass.
  await pop.call('dev_fill_bin', {});
  s = await pop.state();
  for (let i = 0; i < 20 && Object.keys(s.run.glass).length === 0; i++) {
    if (!s.run.heating && s.run.cooldown_left <= 0) await pop.holdGold();
    await pop.page.waitForTimeout(400);
    s = await pop.state();
  }
  expect(Object.keys(s.run.glass).length, 'a lot waits in the glass').toBeGreaterThan(0);
  expect(s.view.ring_waiting, 'the kettle says it cannot take a press').toBe(true);
  const waiting = await ringSat(pop, await still(pop, testInfo, 'waiting'));
  // A blind player's hold on it: 1.8 s, a look 0.4 s after the lift.
  const cues0 = s.view.full_cues;
  await pop.hold('play', 1800);
  await pop.page.waitForTimeout(400);
  s = await pop.state();
  await still(pop, testInfo, 'refused_after_lift');
  testInfo.annotations.push({ type: 'ready47', description: JSON.stringify({ ring_sat: { ready: Math.round(ready * 1000) / 1000, waiting: Math.round(waiting * 1000) / 1000 }, cue_after_lift: s.view.full_cue, refused: s.view.full_cues - cues0 }) });
  expect(s.view.full_cues, 'the hold was refused and shown').toBeGreaterThan(cues0);
  expect(s.view.full_cue, 'the cue is still up 0.4 s after the finger lifts').toBe(true);
  expect(s.run.heating, 'no heat').toBe(false);
  expect(waiting, `the dimmed ring is less saturated (ready ${ready.toFixed(3)}, waiting ${waiting.toFixed(3)})`).toBeLessThan(ready * 0.8);
});
