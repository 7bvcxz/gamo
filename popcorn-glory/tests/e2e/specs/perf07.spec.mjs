// Step 07: performance smoke on the real build, thresholds measured on this
// machine (recorded beside the load average): load to the first drawn frame,
// JS heap growth over a minute of real play, the worst burst (C at its top
// level), and a background tab that sleeps and wakes. Desktop only.
import { test, expect } from '../lib/pop.mjs';
import os from 'node:os';

test.skip(({ hasTouch }) => hasTouch, 'one project measures (desktop)');

test('load, heap over a minute, worst burst, sleep and wake', async ({ pop }) => {
  test.setTimeout(240_000);
  await pop.open('./#click');
  const load = pop.loadMs;
  const heap0 = await pop.page.evaluate(() => performance.memory?.usedJSHeapSize ?? 0);
  const t0 = Date.now();
  while (Date.now() - t0 < 60_000) {
    const s = await pop.state();
    if (s.run.cost >= 0 && s.run.money >= s.run.cost) await pop.tap('upgrade');
    else await pop.tap('play');
    await pop.page.waitForTimeout(200);
  }
  const heap1 = await pop.page.evaluate(() => performance.memory?.usedJSHeapSize ?? 0);
  // The worst burst: C at its top level.
  await pop.page.evaluate(() => { location.hash = '#explosion'; });
  await expect.poll(async () => (await pop.state()).exp).toBe('explosion');
  await pop.call('dev_level', 14);
  for (let i = 0; i < 8; i++) await pop.tap('play');
  await pop.page.waitForTimeout(600);
  const burstFps = await pop.fps(1000);
  const info = await pop.call('dev_render_info');
  const sb = await pop.state();
  // Sleep and wake.
  const c0 = (await pop.state()).clock_ms;
  await pop.tab(true);
  await pop.page.waitForTimeout(5000);
  const c1 = (await pop.state()).clock_ms;
  await pop.tab(false);
  await pop.page.waitForTimeout(800);
  const c2 = (await pop.state()).clock_ms;
  const rec = { load_ms: load, heap_start: heap0, heap_after_60s: heap1, burst: { fps: burstFps, draw_calls: info.draw_calls, primitives: info.primitives, fx_peak: sb.fx.peak, fx_cap: sb.fx.cap },
    sleep: { before: c0, hidden_5s: c1, after_wake: c2 }, load_avg: os.loadavg()[0] };
  test.info().annotations.push({ type: 'perf', description: JSON.stringify(rec) });
  expect(load, 'first drawn frame within 20 s even on a loaded machine').toBeLessThan(20000);
  expect(heap1 - heap0, 'JS heap grows less than 30 MB over a minute of play').toBeLessThan(30e6);
  expect(sb.fx.peak, 'pieces under the cap').toBeLessThanOrEqual(sb.fx.cap);
  expect(info.draw_calls, 'draw calls within the budget at the worst burst').toBeLessThanOrEqual(200);
  expect(burstFps, 'no collapse at the worst burst').toBeGreaterThanOrEqual(10);
  expect(c1 - c0, 'no play time while hidden').toBeLessThanOrEqual(300);
  expect(c2 - c1, 'time runs again after waking').toBeGreaterThan(0);
});

// Step 11: the stand at its peak -- the top machine, every rung of the ladder (the helper
// popping every 1.5 s), caramel, golden batches popping and bags flying -- for a minute of
// real holds: draw calls, pieces, heap, sound voices, and the frame rate (with the load
// average beside it); then a hidden tab must not earn (no helper batches while hidden) and
// the restart button must give a fresh stand.
test('stand: peak load for a minute, hidden tab, restart', async ({ pop }) => {
  test.setTimeout(240_000);
  await pop.open('./#stand');
  await pop.call('dev_level', 14);
  await pop.call('dev_money', 50000000);
  for (let i = 0; i < 7; i++) { await pop.tap('auto'); await pop.page.waitForTimeout(150); }
  await expect.poll(async () => (await pop.state()).run.auto_level).toBe(7);
  await pop.tap('recipe_caramel');
  const heap0 = await pop.page.evaluate(() => performance.memory?.usedJSHeapSize ?? 0);
  let worst = { draw_calls: 0, primitives: 0, fx: 0 };
  const fps = [];
  const t0 = Date.now();
  while (Date.now() - t0 < 60_000) {
    await pop.holdGold();
    await pop.page.waitForTimeout(450);
    const info = await pop.call('dev_render_info');
    const s = await pop.state();
    worst = { draw_calls: Math.max(worst.draw_calls, info.draw_calls), primitives: Math.max(worst.primitives, info.primitives), fx: Math.max(worst.fx, s.fx.alive) };
    if (fps.length < 6 && (Date.now() - t0) > fps.length * 10_000) fps.push(await pop.fps(1000));
  }
  const heap1 = await pop.page.evaluate(() => performance.memory?.usedJSHeapSize ?? 0);
  const s1 = await pop.state();
  // Hidden: no time, no helper batches.
  const h0 = s1.run.helper_batches;
  await pop.tab(true);
  await pop.page.waitForTimeout(5000);
  const h1 = (await pop.state()).run.helper_batches;
  await pop.tab(false);
  await expect.poll(async () => (await pop.state()).run.helper_batches, { message: 'the helper works again after waking', timeout: 10_000 }).toBeGreaterThan(h1);
  // Restart: a fresh stand.
  await pop.tap('restart');
  await expect.poll(async () => (await pop.state()).run.level).toBe(0);
  const s2 = await pop.state();
  const median = [...fps].sort((a, b) => a - b)[Math.floor(fps.length / 2)];
  const rec = { worst, fps, median_fps: median, heap_start: heap0, heap_after_60s: heap1, batches: s1.run.outcomes, helper_batches: s1.run.helper_batches,
    sound_played: s1.sound.played, load_avg: os.loadavg()[0], hidden: { helper_before: h0, helper_after_5s_hidden: h1 },
    after_restart: { money: s2.run.money, auto: s2.run.auto_level, recipe: s2.run.recipe, helper: s2.run.helper_level } };
  test.info().annotations.push({ type: 'perf', description: JSON.stringify(rec) });
  expect(worst.draw_calls, 'draw calls within the budget at the stand peak').toBeLessThanOrEqual(200);
  expect(worst.fx, 'pieces under the cap').toBeLessThanOrEqual(s1.fx.cap);
  expect(median, 'no collapse at the stand peak').toBeGreaterThanOrEqual(10);
  expect(heap1 - heap0, 'JS heap grows less than 30 MB over a minute at the peak').toBeLessThan(30e6);
  expect(h1 - h0, 'no helper batch while the tab is hidden').toBeLessThanOrEqual(1);
  expect(s2.run.money, 'restart: no money').toBe(0);
  expect(s2.run.auto_level, 'restart: no machines').toBe(0);
  expect(s2.run.recipe, 'restart: butter').toBe('butter');
  expect(pop.errors).toEqual([]);
});
