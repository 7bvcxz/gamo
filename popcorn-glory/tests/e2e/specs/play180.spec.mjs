// Step 04: each experiment played for three real minutes with real input on a
// 720x1280 touch screen (the slow test; one project by default:
//   popcorn-glory/tools/e2e.sh specs/play180.spec.mjs --project p720
// ). A scripted player -- the same habits as tools/selftest.gd's steady
// players -- taps A and C at about 2.5 a second, and holds B into the gold.
// It proves a full three minutes is playable without a soft-lock, records
// what was reached, the frame rate at 5 s, 1:00 and 3:00, and screenshots.
// These are objective measurements, not anyone's fun.
//
// The performance gate is the render budget (draw calls, drawn pieces), not
// the frame rate. Step 04 first compared fps at 3:00 with fps at 5 s and it
// measured the machine, not the game: with another session's browser tests
// at ~640% CPU (load average 20 on 16 cores), the same idle level-0 screen
// read 60 fps and 39 fps half an hour apart, and one run rose from 21 to
// 52 fps over the three minutes. The fps is kept in the record with the load
// average beside it, and only a collapse (median under 10) fails.
import { test, expect } from '../lib/pop.mjs';
import fs from 'node:fs';
import os from 'node:os';

const DRAW_CALL_BUDGET = 200;   // the top level with fx measured 139 (render_probe, play180)

const OUT = process.env.POPCORN_PLAY_OUT;

for (const id of ['click', 'perfect', 'explosion']) {
  test(`${id}: three real minutes`, async ({ pop }) => {
    test.setTimeout(420_000);
    await pop.open(`./#${id}`);
    const marks = {};
    const t0 = Date.now();
    let buys = 0;
    const at = async (label) => {
      // The picture first: measuring the frame rate takes three idle seconds,
      // and a shot taken after them showed a machine with nothing flying.
      await pop.shot(`${id}_${label}`);
      const s = await pop.state();
      // The median of three one-second samples: a single sample in a software-
      // rendered browser swings too much to compare (AGENTS.md 2026-07-31).
      const samples = [await pop.fps(1000), await pop.fps(1000), await pop.fps(1000)].sort((a, b) => a - b);
      const info = await pop.call('dev_render_info');
      marks[label] = { clock_ms: s.clock_ms, level: s.run.level, money: s.run.money, earned: s.run.earned, fps: samples[1], fps_samples: samples, fx_peak: s.fx.peak, draw_calls: info.draw_calls, primitives: info.primitives, load_avg: os.loadavg()[0] };
    };
    const done = new Set();
    while (true) {
      const s = await pop.state();
      // The Step 04 addendum's checkpoints: first action, first upgrade, ~60 s, ~180 s.
      if (s.run.presses >= 1 && !done.has('first_action')) { done.add('first_action'); await pop.page.waitForTimeout(150); await at('first_action'); }
      if (s.run.level >= 1 && !done.has('first_upgrade')) { done.add('first_upgrade'); await pop.page.waitForTimeout(400); await at('first_upgrade'); }
      if (s.clock_ms >= 5000 && !done.has('5s')) { done.add('5s'); await at('5s'); }
      if (s.clock_ms >= 60000 && !done.has('60s')) { done.add('60s'); await at('60s'); }
      if (s.clock_ms >= 181000) { await at('180s'); break; }
      if (Date.now() - t0 > 330_000) throw new Error(`play clock only at ${s.clock_ms} ms after 330 s`);
      if (s.run.cost >= 0 && s.run.money >= s.run.cost) { await pop.tap('upgrade'); buys++; continue; }
      if (id === 'perfect') {
        const w = s.run.window;
        if (s.run.cooldown_left > 0 || s.run.heating) { await pop.page.waitForTimeout(100); continue; }
        await pop.hold('play', Math.round((w[0] + w[1]) / 2));
        await pop.page.waitForTimeout(250);
      } else {
        await pop.tap('play');
        await pop.page.waitForTimeout(250);
      }
    }
    const sum = await pop.call('summary');
    const doc = await pop.call('log_document');
    // A reproducible reset: Restart after the three minutes starts from nothing.
    await pop.tap('restart');
    await expect.poll(async () => (await pop.state()).run.money).toBe(0);
    const fresh = await pop.state();
    expect(fresh.run.level, 'restart: level 0').toBe(0);
    expect(fresh.clock_ms, 'restart: the clock from zero').toBeLessThan(3000);
    const result = { id, project: test.info().project.name, marks, buys, summary: sum, log: doc };
    test.info().annotations.push({ type: 'result', description: JSON.stringify({ marks, level: sum.level, inputs: sum.inputs }) });
    if (OUT) fs.writeFileSync(`${OUT}/play180_${id}_${test.info().project.name}.json`, JSON.stringify(result, null, 2));
    expect(sum.milestones.three_minutes, 'reached three minutes of play').toBeGreaterThanOrEqual(180000);
    expect(sum.level, 'at least three upgrades').toBeGreaterThanOrEqual(3);
    expect(marks['180s'].earned, 'still earning at the end (no soft-lock)').toBeGreaterThan(marks['60s'].earned);
    for (const k of ['5s', '60s', '180s']) {
      expect(marks[k].draw_calls, `draw calls at ${k} within the budget`).toBeLessThanOrEqual(DRAW_CALL_BUDGET);
      expect(marks[k].fx_peak, `drawn pieces at ${k} under the cap`).toBeLessThanOrEqual(400);
      expect(marks[k].fps, `no frame-rate collapse at ${k} (median of three; load ${marks[k].load_avg.toFixed(1)})`).toBeGreaterThanOrEqual(10);
    }
  });
}
