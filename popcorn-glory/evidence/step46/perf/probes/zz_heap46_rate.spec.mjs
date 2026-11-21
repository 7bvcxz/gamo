// Step 46 probe (temporary; kept in evidence/step46/perf/): what sets the heap's growth rate?
import fs from 'node:fs';
import { test, expect } from '../lib/pop.mjs';
const PLAN = JSON.parse(fs.readFileSync(new URL('./perf46.spec.mjs', import.meta.url), 'utf8').match(/const PLAN = (\[[\s\S]*?\]\]);/)[1].replace(/'/g, '"'));
const SEC = Number(process.env.HEAP_SEC || 150);
const VARIANTS = [
  { name: '0 machines', n: 0 },
  { name: '44 machines', n: 44 },
  { name: '44, bakes off and freed', n: 44, bake: { actors: false, free: true } },
  { name: '44, goods layer hidden', n: 44, hide: 'goods_layer' },
  { name: '44, in the background tab (no frames)', n: 44, hidden: true },
];
test('heap rate', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop only');
  test.setTimeout(3_000_000);
  const rows = [];
  for (const v of VARIANTS) {
    await pop.open('./?sound=off#factory');
    await pop.call('dev_restart');
    if (v.n) { await pop.call('dev_money', 1e9); expect((await pop.call('dev_build', { plan: PLAN.slice(0, v.n), sign: 8, packer: 3 })).ok).toBe(true); }
    if (v.bake) await pop.call('dev_bake', v.bake);
    if (v.hide) await pop.call('dev_hide', { name: v.hide, hidden: true });
    const cdp = await pop.cdp();
    const heap = async () => { await cdp.send('HeapProfiler.collectGarbage'); return (await cdp.send('Runtime.getHeapUsage')).usedSize / 1e6; };
    await pop.page.waitForTimeout(15_000);
    const info0 = await pop.call('dev_render_info');
    const fps = await pop.fps(2000);
    const h0 = await heap(); const t0 = Date.now();
    if (v.hidden) await pop.tab(true);
    await pop.page.waitForTimeout(SEC * 1000);
    if (v.hidden) await pop.tab(false);
    const h1 = await heap(); const min = (Date.now() - t0) / 60000;
    rows.push({ variant: v.name, fps: Math.round(fps * 10) / 10, draw_calls: info0.draw_calls, viewports: info0.viewports ?? null, heap_mb: [Math.round(h0 * 10) / 10, Math.round(h1 * 10) / 10], mb_per_min: Math.round((h1 - h0) / min * 10) / 10, mb_per_1k_frames: Math.round((h1 - h0) / (fps * min * 60 / 1000) * 10) / 10 });
    console.log(JSON.stringify(rows.at(-1)));
  }
  fs.writeFileSync(process.env.OUT + '/heap46_rate.json', JSON.stringify({ when: new Date().toISOString(), seconds: SEC, rows }, null, 2));
});
