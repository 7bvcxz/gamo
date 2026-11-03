// Step 04: the real game, played with the real mouse for more than three
// minutes from a fresh start, with a timestamped trace -- and the restart,
// the save and the pause policy on the real paths.
//
// The player is a script (a fixed human-like pattern of holds, clicks and
// rests on the key), not a person and not an AI: it shows the build runs and
// what a steady player reaches. Evidence: windup/evidence/step04/.
import { test, expect } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import { openGame, state, call, events, keyPoint, withinBudget, RENDER_BUDGET } from '../lib/game.mjs';
import { AUDIO_TAP, listen } from '../lib/audio_tap.mjs';

// Pictures and numbers go to windup/evidence/ only when asked (WINDUP_EVIDENCE=1), so
// a routine run cannot overwrite an earlier step's published-build evidence.
const evidence = process.env.WINDUP_EVIDENCE
  ? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../evidence/' + (process.env.WINDUP_EVIDENCE_STEP || 'step04'))
  : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../test-results/evidence/step04');

const median = (v) => { if (!v.length) return 0; const a = [...v].sort((x, y) => x - y); return a[Math.floor(a.length / 2)]; };

test('three minutes of real play from a fresh start', async ({ page }, info) => {
  test.skip(info.project.name !== 'desktop', 'one long play, on the PC layout');
  test.setTimeout(330_000);
  await page.addInitScript(AUDIO_TAP);
  const { errors } = await openGame(page, '?fresh=1');
  fs.mkdirSync(evidence, { recursive: true });
  const k = await keyPoint(page);
  const t0 = Date.now();
  const log = [];
  const now = () => (Date.now() - t0) / 1000;
  const shots = { 5: false, 30: false, 60: false, 120: false, 180: false };
  const fpsSamples = [];   // [game t, fps] about once a second
  let audio = null;
  const act = async (what, fn) => { log.push({ wall: now(), game: (await state(page)).t, input: what }); await fn(); };
  const shoot = async () => {
    const s = await state(page);
    if (!fpsSamples.length || s.t - fpsSamples[fpsSamples.length - 1][0] >= 0.9) fpsSamples.push([s.t, s.fps]);
    for (const mark of Object.keys(shots)) {
      if (!shots[mark] && s.t >= Number(mark)) {
        shots[mark] = true;
        await page.screenshot({ path: path.join(evidence, `play_${String(mark).padStart(3, '0')}s.png`) });
        log.push({ wall: now(), game: s.t, shot: Number(mark), awake: s.awake, energy: s.energy, stage: s.stage, fps: s.fps });
      }
    }
    return s;
  };
  await page.waitForTimeout(2500);                     // a first look before touching anything
  const budgetStart = await withinBudget(page);
  const loadStart = os.loadavg()[0];
  await page.mouse.move(k.x, k.y);
  // The cycle: three clicks, a long hold, a rest, a burst of clicks, a rest.
  while ((await shoot()).t < 186) {
    for (let i = 0; i < 3; i++) { await act('click', () => page.mouse.click(k.x, k.y)); await page.waitForTimeout(380); }
    if (!audio) audio = await listen(page);
    await act('down', () => page.mouse.down());
    for (let i = 0; i < 12; i++) { await page.waitForTimeout(1000); await shoot(); }
    await act('up', () => page.mouse.up());
    if (audio && typeof audio === 'function') audio = await audio(10);
    await page.waitForTimeout(2500); await shoot();
    for (let i = 0; i < 8; i++) { await act('click', () => page.mouse.click(k.x, k.y)); await page.waitForTimeout(300); }
    await page.waitForTimeout(2000); await shoot();
  }
  const budgetEnd = await withinBudget(page);
  const end = await call(page, 'end');
  const ev = await events(page);
  const s = await state(page);
  fs.writeFileSync(path.join(evidence, 'play_trace_events.jsonl'), ev.map((e) => JSON.stringify(e)).join('\n') + '\n');
  fs.writeFileSync(path.join(evidence, 'play_trace_inputs.json'), JSON.stringify(log, null, 1) + '\n');
  const awake = ev.filter((e) => e.ev === 'doll_awake').map((e) => e.t);
  const idle = ev.filter((e) => e.ev === 'idle').map((e) => e.seconds);
  const summary = {
    build: s.version, wall_seconds: now(), game_seconds: s.t,
    first_wind: ev.find((e) => e.ev === 'wind')?.t, awakenings: awake,
    dolls_at: Object.fromEntries([30, 60, 120, 180].map((m) => [m, awake.filter((t) => t <= m).length])),
    stages: ev.filter((e) => e.ev === 'stage').map((e) => [e.t, e.name]),
    winds: ev.filter((e) => e.ev === 'wind').length, presses: log.filter((l) => l.input).length,
    idle_over_5s: idle, hints: ev.filter((e) => e.ev === 'hint').length,
    end, audio_while_winding: audio, sounds_started: s.sounds, fps_end: s.fps,
    fps_at: Object.fromEntries(log.filter((l) => l.shot).map((l) => [l.shot, l.fps])),
    fps_median_first20: median(fpsSamples.filter(([t]) => t >= 3 && t <= 23).map(([, f]) => f)),
    fps_median_last20: median(fpsSamples.filter(([t]) => t >= 160 && t <= 180).map(([, f]) => f)),
    fps_samples: fpsSamples, render_start: budgetStart, render_end: budgetEnd, render_budget: RENDER_BUDGET,
    machine_load_1min: [loadStart, os.loadavg()[0]], cpus: os.cpus().length, errors,
  };
  fs.writeFileSync(path.join(evidence, 'play_summary.json'), JSON.stringify(summary, null, 2) + '\n');
  expect(s.t).toBeGreaterThan(180);
  expect(awake.length).toBeGreaterThanOrEqual(4);       // successive awakenings
  expect(awake[0]).toBeGreaterThan(10);
  expect(awake[0]).toBeLessThan(45);
  expect(summary.dolls_at[60]).toBeGreaterThanOrEqual(2);
  for (let i = 1; i < awake.length; i++) expect(awake[i] - awake[i - 1]).toBeLessThan(60);   // no wall in 3 min
  expect(audio.rms).toBeGreaterThan(0.005);             // the clicks reach the speakers
  // The frame rate holds as the atelier fills (software-rendered headless
  // Chromium: compare the run with itself, the Momonium Fun Lab's rule).
  // The render budget holds as the atelier fills. Frames a second are kept as
  // evidence (with the machine's load) but only a floor is asserted: on this
  // shared machine (load 20+ from other sessions' emulators and builds) the
  // same build measured 33 -> 47 and 38 -> 27 an hour apart (Step 05).
  expect(budgetStart.ok, JSON.stringify(budgetStart)).toBe(true);
  expect(budgetEnd.ok, JSON.stringify(budgetEnd)).toBe(true);
  expect(summary.fps_median_last20).toBeGreaterThanOrEqual(10);
  expect(errors).toEqual([]);
});

test('restart, save and the pause policy', async ({ page: first }, info) => {
  let page = first;
  const { errors } = await openGame(page, '?fresh=1');
  await call(page, 'dev_wind', 80);                      // enough for the first doll
  await call(page, 'dev_advance', 2.0);
  let s = await state(page);
  expect(s.awake).toBe(1);
  // Leaving the window pauses the game and saves; coming back resumes.
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await expect.poll(async () => (await state(page)).paused).toBe(true);
  const t = (await state(page)).t;
  await page.waitForTimeout(800);
  expect((await state(page)).t).toBe(t);
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect.poll(async () => (await state(page)).paused).toBe(false);
  // Another visit without ?fresh continues the saved atelier. The browser
  // persists user:// to IndexedDB asynchronously, so give it a moment, and
  // look from a new page in the same context (AGENTS.md, 2026-07-22).
  await page.waitForTimeout(2000);
  const again = await page.context().newPage();
  await again.goto('index.html');
  await again.waitForFunction(() => window.windup && window.windup.ready === true, null, { timeout: 120_000 });
  await page.close();
  page = again;
  s = await state(page);
  expect(s.awake).toBe(1);
  expect((await events(page))[0].resumed).toBe(true);
  // The restart arrow: one press arms it, a second starts over.
  const r = await call(page, 'restart_point');
  const box = await page.locator('canvas').boundingBox();
  const at = { x: box.x + r.x * box.width, y: box.y + r.y * box.height };
  const tap = (p) => info.project.use.hasTouch ? page.touchscreen.tap(p.x, p.y) : page.mouse.click(p.x, p.y);
  await tap(at);
  await page.waitForTimeout(300);
  expect((await state(page)).awake).toBe(1);              // armed, not yet
  await page.screenshot({ path: path.join(evidence, `restart_armed_${info.project.name}.png`) });
  await tap(at);
  await expect.poll(async () => (await state(page)).awake).toBe(0);
  expect((await state(page)).energy).toBe(0);
  expect(errors).toEqual([]);
});
