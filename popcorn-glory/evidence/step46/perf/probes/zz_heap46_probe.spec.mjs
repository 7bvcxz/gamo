// Step 46 probe (temporary; kept in evidence/step46/perf/): where does the JS heap grow at 44 machines?
import fs from 'node:fs';
import { test, expect } from '../lib/pop.mjs';
const PLAN = JSON.parse(fs.readFileSync(new URL('./perf46.spec.mjs', import.meta.url), 'utf8').match(/const PLAN = (\[[\s\S]*?\]\]);/)[1].replace(/'/g, '"'));
const VARIANTS = (process.env.HEAP_VARIANTS || 'normal,sound_off,no_hand,fx_low').split(',');
const MIN = Number(process.env.HEAP_MIN || 4);
test('heap probe', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop only');
  test.setTimeout(3_600_000);
  const out = [];
  for (const v of VARIANTS) {
    const q = v === 'sound_off' ? '?sound=off' : v === 'fx_low' ? '?fx=low' : '';
    await pop.open(`./${q}#factory`);
    await pop.call('dev_restart');
    await pop.call('dev_money', 1e9);
    expect((await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 })).ok).toBe(true);
    const cdp = await pop.cdp();
    const heap = async () => { await cdp.send('HeapProfiler.collectGarbage'); const u = await cdp.send('Runtime.getHeapUsage'); return Math.round(u.usedSize / 1e5) / 10; };
    const rows = [];
    const t0 = Date.now();
    let pops = 0;
    while (Date.now() - t0 < MIN * 60_000) {
      if (v !== 'no_hand') {
        const s = await pop.state();
        if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0) { await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25)); pops++; }
      }
      if (rows.length === 0 || Date.now() - t0 >= rows.length * 30_000) {
        const s = await pop.state();
        const ext = await pop.page.evaluate(() => ({ dom: document.getElementsByTagName('*').length, audio: (window.__popAudioCount || null) }));
        rows.push({ t: Math.round((Date.now() - t0) / 1000), heap: await heap(), sold: s.run.stats.sold, played: Object.values(s.sound?.played || {}).reduce((a, b) => a + b, 0), loop_copies: s.sound?.loop_copies, dom: ext.dom });
      }
      await pop.page.waitForTimeout(3000);
    }
    out.push({ variant: v, pops, rows, growth: Math.round((rows.at(-1).heap - rows[0].heap) * 10) / 10 });
    console.log(JSON.stringify(out.at(-1)));
  }
  fs.writeFileSync(process.env.OUT + '/heap46_probe.json', JSON.stringify({ when: new Date().toISOString(), minutes: MIN, out }, null, 2));
});
