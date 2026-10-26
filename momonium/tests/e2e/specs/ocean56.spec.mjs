// Step 56: no sky. In the real web build the sea fills the whole screen at
// every time of day -- no sun or moon disc, no cloud band, no star field, no
// horizon line where the sky used to end -- pauses and fast-forwards with the
// game clock, and costs no more frame time than the sky and sea did.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

const luma = ([r, g, b]) => r * 0.3 + g * 0.59 + b * 0.11;

function mean(png, x0, y0, x1, y1, step = 2) {
  const sum = [0, 0, 0];
  let n = 0;
  for (let y = y0; y < y1; y += step) {
    for (let x = x0; x < x1; x += step) {
      const p = pixel(png, x, y);
      for (let i = 0; i < 3; i++) sum[i] += p[i];
      n += 1;
    }
  }
  return sum.map((v) => v / Math.max(n, 1));
}

// The upper water, where the sky was, between the HUD's corners: how much of
// it is near-white (a cloud band, a disc), and its brightest patch against
// its typical one (a sun or moon, however soft, would stand out). With the
// sky (0.55.0): up to 22% white, the brightest patch 36 to 60 over.
function upper(png) {
  const x0 = png.width * 0.28;
  const x1 = png.width * 0.62;
  const y0 = png.height * 0.02;
  const y1 = png.height * 0.3;
  let white = 0;
  let n = 0;
  for (let y = y0; y < y1; y += 2) {
    for (let x = x0; x < x1; x += 2) {
      const [r, g, b] = pixel(png, x, y);
      if (r > 230 && g > 230 && b > 230) white += 1;
      n += 1;
    }
  }
  const s = Math.round(png.width * 0.05);
  const patches = [];
  for (let y = y0; y + s < y1; y += s) {
    for (let x = x0; x + s < x1; x += s) patches.push(luma(mean(png, x, y, x + s, y + s, 3)));
  }
  patches.sort((a, b) => a - b);
  return { white: white / n, brightest: patches[patches.length - 1], typical: patches[Math.floor(patches.length / 2)] };
}

// Down the left edge of the screen, clear of the HUD (the day card and its
// pills above, the buttons below) and the island: the largest colour step
// between neighbouring bands. A horizon is a step: 55 to 155 with the sky
// (0.55.0), under 30 on open water.
function largestStep(png) {
  const x0 = png.width * 0.005;
  const x1 = png.width * 0.06;
  const band = Math.round(png.height * 0.02);
  let prev = null;
  let worst = 0;
  for (let y = png.height * 0.18; y + band < png.height * 0.86; y += band) {
    const m = mean(png, x0, y, x1, y + band);
    if (prev) worst = Math.max(worst, Math.abs(m[0] - prev[0]) + Math.abs(m[1] - prev[1]) + Math.abs(m[2] - prev[2]));
    prev = m;
  }
  return worst;
}

test('the sea, edge to edge, at day, sunset and night', async ({ game }) => {
  await game.setTimeScale(0);
  expect((await game.query('art_info')).backdrop, 'the backdrop is the sea alone').toEqual(['Ocean']);
  for (const [phase, t] of [['day', 0.3], ['sunset', 0.62], ['night', 0.86]]) {
    await game.query('dev_advance_to', [1, t]);
    await game.page.waitForTimeout(300);
    expect((await game.query('day_look')).phase).toBe(phase);
    const png = decodePng(await game.canvas.screenshot());
    const u = upper(png);
    const step = largestStep(png);
    console.log(`ocean56 ${phase}: white ${(u.white * 100).toFixed(2)}%  brightest ${u.brightest.toFixed(0)} vs typical ${u.typical.toFixed(0)}  largest step ${step.toFixed(1)}`);
    expect(u.white, `${phase}: no cloud band, no disc, no field of stars`).toBeLessThan(0.01);
    expect(u.brightest - u.typical, `${phase}: the sun or moon only a faint glow`).toBeLessThan(28);
    expect(step, `${phase}: no horizon line down the screen`).toBeLessThan(40);
  }
});

test('the look stops with the clock and runs with it', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_advance_to', [1, 0.5]);
  await game.page.waitForTimeout(200);
  const a = await game.query('day_look');
  await game.page.waitForTimeout(1200);
  const b = await game.query('day_look');
  expect(b.sea_far, 'paused: the light holds').toBe(a.sea_far);
  expect(b.progress).toBe(a.progress);
  await game.setTimeScale(10);
  await game.page.waitForTimeout(1000);
  await game.setTimeScale(0);
  const c = await game.query('day_look');
  expect(c.progress, 'fast: the day runs on').toBeGreaterThan(a.progress + 0.1);
  expect(c.sea_far, 'and the water changes with it').not.toBe(a.sea_far);
});

test('a frame of sea stays within the frame budget', async ({ game }) => {
  await game.page.waitForTimeout(500);
  // Headless Chromium draws WebGL in software (SwiftShader) on a shared
  // machine: one reading is noise. Three, and the middle one.
  const runs = [];
  for (let i = 0; i < 3; i++) {
    runs.push(await game.page.evaluate(() => new Promise((done) => {
      let frames = 0;
      const start = performance.now();
      const tick = () => {
        frames += 1;
        if (performance.now() - start < 2000) requestAnimationFrame(tick);
        else done(frames / ((performance.now() - start) / 1000));
      };
      requestAnimationFrame(tick);
    })));
  }
  runs.sort((a, b) => a - b);
  console.log(`ocean56 fps: ${runs.map((f) => f.toFixed(1)).join(' / ')} (median ${runs[1].toFixed(1)})`);
  // The same floor as the night demo (vfx.spec). A/B against the sky build:
  // design/ART_SPEC.md 8 and the Step 56 report.
  expect(runs[1], 'a usable frame rate').toBeGreaterThan(8);
  expect((await game.query('art_info')).backdrop, 'one full-screen pass behind the island').toEqual(['Ocean']);
});
