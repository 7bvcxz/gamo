// Step 46 probe (temporary; kept in evidence/step46/perf/): which canvas items redraw each frame at 44 machines.
import fs from 'node:fs';
import { test, expect } from '../lib/pop.mjs';
const PLAN = JSON.parse(fs.readFileSync(new URL('./perf46.spec.mjs', import.meta.url), 'utf8').match(/const PLAN = (\[[\s\S]*?\]\]);/)[1].replace(/'/g, '"'));
test('redraws per frame', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop only');
  test.setTimeout(600_000);
  await pop.open('./?sound=off#factory');
  await pop.call('dev_restart');
  if (process.env.DRAWS_MACHINES !== '0') {
    await pop.call('dev_money', 1e9);
    expect((await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 })).ok).toBe(true);
  }
  await pop.page.waitForTimeout(12_000);
  const st = await pop.call('dev_draws', { start: true });
  await pop.page.waitForTimeout(6000);
  const r = await pop.call('dev_draws', {});
  const rows = Object.entries(r.counts).map(([k, v]) => [k, Math.round(v / r.frames * 100) / 100]).sort((a, b) => b[1] - a[1]);
  const out = { label: process.env.DRAWS_LABEL || '', hooked: st.hooked, frames: r.frames, redraws_per_frame: rows };
  fs.writeFileSync(`${process.env.OUT}/draws46${process.env.DRAWS_LABEL ? '_' + process.env.DRAWS_LABEL : ''}.json`, JSON.stringify(out, null, 2));
  console.log(JSON.stringify({ hooked: st.hooked, frames: r.frames, top: rows.slice(0, 40) }));
});
