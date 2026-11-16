// Step 22 evidence (run on demand, not in the regular suite): real-time 3-minute factory sessions
// from different seeds (?seed=N), played by a simple hand -- a gold-middle hold whenever the
// kettle is free -- recording when each customer came in (the model's flow ms), the line length,
// the first sale. Nothing is fast-forwarded. Results: $OUT/sessions22.json.
import { test, expect } from '../lib/pop.mjs';
import fs from 'node:fs';

const SEEDS = (process.env.SEEDS || '11,22,33').split(',').map(Number);
for (const seed of SEEDS) {
  test(`a real 3-minute session, seed ${seed}`, async ({ pop }, testInfo) => {
    test.skip(testInfo.project.name !== 'p720');
    test.setTimeout(260_000);
    await pop.open(`./?seed=${seed}#factory`);
    const t0 = Date.now();
    let maxLine = 0; const lines = []; let pops = 0;
    while (Date.now() - t0 < 180_000) {
      const s = await pop.state();
      maxLine = Math.max(maxLine, s.run.queue);
      lines.push([s.run.flow_ms || 0, s.run.queue]);
      if (!s.run.heating && Object.keys(s.run.glass).length === 0 && (s.run.cooldown_left || 0) <= 0) {
        await pop.hold('ring', Math.round((s.run.window[0] + s.run.window[1]) / 2));
        pops++;
      } else {
        await pop.page.waitForTimeout(300);
      }
    }
    const s = await pop.state();
    const arr = s.run.arrivals;
    const gaps = arr.slice(2).map((t, i) => t - arr[i + 1]);
    const out = {
      seed, real_ms: Date.now() - t0, flow_ms: s.run.flow_ms, pops, arrivals: arr,
      gaps_from_third: gaps, mean_gap_ms: gaps.length ? Math.round(gaps.reduce((a, b) => a + b, 0) / gaps.length) : null,
      min_gap_ms: gaps.length ? Math.min(...gaps) : null, max_gap_ms: gaps.length ? Math.max(...gaps) : null,
      max_line: maxLine, first_sale_ms: s.run.first_sale_ms, sold: s.run.stats.sold, abandoned: s.run.stats.abandoned,
      visitors: s.run.stats.visitors, money: s.run.money, line_samples: lines.length,
    };
    const file = `${process.env.OUT}/sessions22.json`;
    const all = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
    all[seed] = out;
    fs.writeFileSync(file, JSON.stringify(all, null, 1));
    expect(arr[0], 'one customer waiting at the start').toBe(0);
    expect(pop.errors).toEqual([]);
  });
}
