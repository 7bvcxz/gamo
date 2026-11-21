// Step 46 probe (temporary; kept in evidence/step46/perf/): the same factory scene, to compare by
// eye the goods drawn as vectors (0.46.0) and as baked pictures (0.46.1).
import fs from 'node:fs';
import { test, expect } from '../lib/pop.mjs';
const PLAN = JSON.parse(fs.readFileSync(new URL('./perf46.spec.mjs', import.meta.url), 'utf8').match(/const PLAN = (\[[\s\S]*?\]\]);/)[1].replace(/'/g, '"'));
test('the factory scene for the eye', async ({ pop }, testInfo) => {
  test.setTimeout(300_000);
  await pop.open('./?sound=off&motion=reduce#factory');
  await pop.call('dev_restart');
  await pop.call('dev_money', 1e9);
  expect((await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 })).ok).toBe(true);
  for (let i = 0; i < 12; i++) await pop.call('dev_advance', 5000);
  await pop.call('dev_fill_bin');
  await pop.page.waitForTimeout(2500);
  const s = await pop.state();
  const tag = process.env.LOOK_TAG || 'x';
  await pop.page.screenshot({ path: `${process.env.OUT}/look46_${tag}_${testInfo.project.name}.png` });
  console.log(JSON.stringify({ tag, project: testInfo.project.name, version: s.version, bin: s.run.bin_portions, shelf: s.run.shelf, queue: s.run.queue }));
});
