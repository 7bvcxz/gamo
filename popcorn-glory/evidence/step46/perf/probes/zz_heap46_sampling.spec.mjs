// Step 46 probe (temporary; kept in evidence/step46/perf/): which code allocates the heap that
// survives GC at 44 machines? V8's sampling heap profiler, live objects only, by call stack.
import fs from 'node:fs';
import { test, expect } from '../lib/pop.mjs';
const PLAN = JSON.parse(fs.readFileSync(new URL('./perf46.spec.mjs', import.meta.url), 'utf8').match(/const PLAN = (\[[\s\S]*?\]\]);/)[1].replace(/'/g, '"'));
const MIN = Number(process.env.HEAP_MIN || 4);
test('heap sampling', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop only');
  test.setTimeout(1_800_000);
  await pop.open(`./${process.env.HEAP_QUERY || '?sound=off'}#factory`);
  await pop.call('dev_restart');
  await pop.call('dev_money', 1e9);
  expect((await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 })).ok).toBe(true);
  const cdp = await pop.cdp();
  const heap = async () => { await cdp.send('HeapProfiler.collectGarbage'); return Math.round((await cdp.send('Runtime.getHeapUsage')).usedSize / 1e5) / 10; };
  await pop.page.waitForTimeout(20_000);
  const h0 = await heap();
  await cdp.send('HeapProfiler.enable');
  await cdp.send('HeapProfiler.startSampling', { samplingInterval: 16384 });
  await pop.page.waitForTimeout(MIN * 60_000);   // no state polling: the game alone
  const h1 = await heap();
  const { profile } = await cdp.send('HeapProfiler.getSamplingProfile');
  await cdp.send('HeapProfiler.stopSampling');
  // Sum live bytes by the allocating frame and by the 4-frame stack.
  const byFrame = new Map(); const byStack = new Map();
  const walk = (n, stack) => {
    const f = n.callFrame; const name = `${f.functionName || '(anon)'} ${(f.url || '').split('/').pop()}:${f.lineNumber}`;
    const st = [...stack, name];
    if (n.selfSize) {
      byFrame.set(name, (byFrame.get(name) || 0) + n.selfSize);
      const k = st.slice(-5).join(' < ');
      byStack.set(k, (byStack.get(k) || 0) + n.selfSize);
    }
    for (const c of n.children) walk(c, st);
  };
  walk(profile.head, []);
  const top = (m) => [...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, 25).map(([k, v]) => [Math.round(v / 1e4) / 100, k]);
  const s = await pop.state();
  const out = { when: new Date().toISOString(), version: s.version ?? null, query: process.env.HEAP_QUERY || '?sound=off', minutes: MIN, heap_mb: [h0, h1], sold: s.run.stats.sold, top_frames_mb: top(byFrame), top_stacks_mb: top(byStack) };
  fs.writeFileSync(process.env.OUT + '/heap46_sampling.json', JSON.stringify(out, null, 2));
  console.log(JSON.stringify({ heap: out.heap_mb, frames: out.top_frames_mb.slice(0, 12) }));
});
