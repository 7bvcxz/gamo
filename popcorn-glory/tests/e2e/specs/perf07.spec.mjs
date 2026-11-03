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
