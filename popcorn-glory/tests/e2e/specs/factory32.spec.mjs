// Step 32: the support machines and the upkeep overview in a real browser. The kitchen's picker
// offers the robot, the lubricator and the energy saver (any floor) but not the lift or the inspector
// (packing floor), and never the sanitation bot, scheduler or balancer (their systems do not exist).
// A small factory runs; the overview (the coin-and-clock button) shows the burn, the take and the
// net; its button pauses every machine (no upkeep while paused) and resumes them; the per-machine
// ledger adds up to the upkeep paid.
import { test, expect } from '../lib/pop.mjs';

async function opened(pop) {
  await pop.open('./#factory');
  const s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 90000);
  await pop.tap('floor_top');
  for (let i = 0; i < 6; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(6);
  await pop.tap('floor_mid');
  for (let i = 0; i < 3; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(3);
}

async function build(pop, floor, list) {
  for (const [slot, type] of list) {
    const n = (await pop.state()).run.machines.length;
    await pop.tap(`slot_${floor}_${slot}`);
    await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the ${floor} picker` }).toBe(true);
    await pop.tap(`pick_${type}`);
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built` }).toBe(n + 1);
  }
}

test('support machines on their floors, the upkeep overview, pause and resume everything', async ({ pop }) => {
  test.setTimeout(240_000);
  await opened(pop);
  await build(pop, 'kitchen', [[0, 'cooker']]);
  await pop.tap('slot_kitchen_1');
  let rects = (await pop.state()).rects;
  for (const id of ['U01', 'U02', 'U03']) expect(rects[`pick_${id}`], `${id} offered in the kitchen`).toBeTruthy();
  for (const id of ['U04', 'U05', 'U06', 'U07', 'U08']) expect(rects[`pick_${id}`], `${id} not offered in the kitchen`).toBeUndefined();
  await build(pop, 'kitchen', [[1, 'U02'], [2, 'cooker'], [3, 'M01'], [4, 'U03'], [5, 'U01']]);
  await pop.tap('slot_packing_1');
  rects = (await pop.state()).rects;
  for (const id of ['U04', 'U05']) expect(rects[`pick_${id}`], `${id} offered on the packing floor`).toBeTruthy();
  await build(pop, 'packing', [[0, 'bagger'], [1, 'U04'], [2, 'U05']]);
  let s = await pop.state();
  const u02 = s.run.machines.find((m) => m.type === 'U02');
  expect(u02.floor, 'the lubricator stands where it was put').toBe('kitchen');
  expect(s.run.bin_cap, 'the buffer lift adds bin room').toBeGreaterThan(24);
  for (let i = 0; i < 18; i++) {
    const x = (await pop.state()).run;
    if (!x.heating && Object.keys(x.glass).length === 0) await pop.hold('ring', Math.round(x.window[0] + (x.window[1] - x.window[0]) * 0.25));
    await pop.call('dev_advance', 5000);
  }
  await pop.tap('overview');
  await expect.poll(async () => !!(await pop.state()).rects.pause_all, { message: 'the overview opened' }).toBe(true);
  s = await pop.state();
  const o = s.run.overview;
  expect(o.burn_per_min, 'running machines burn coins').toBeGreaterThan(0);
  expect(o.machines.length).toBe(s.run.machines.length);
  expect(o.machines.reduce((n, m) => n + m.paid, 0), 'the per-machine ledger adds up').toBe(s.run.stats.upkeep_paid);
  await pop.shot('factory32_overview');
  await pop.tap('pause_all');
  await expect.poll(async () => (await pop.state()).run.machines.every((m) => m.state === 'paused'), { message: 'every machine paused' }).toBe(true);
  const paid = (await pop.state()).run.stats.upkeep_paid;
  for (let i = 0; i < 6; i++) await pop.call('dev_advance', 5000);
  s = await pop.state();
  expect(s.run.stats.upkeep_paid, 'a paused factory pays nothing').toBe(paid);
  expect(s.run.overview.burn_per_min).toBe(0);
  await pop.shot('factory32_paused');
  await pop.tap('pause_all');
  await expect.poll(async () => (await pop.state()).run.machines.every((m) => m.state !== 'paused'), { message: 'every machine resumed' }).toBe(true);
  s = await pop.state();
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
  expect(s.run.stats.wrong_sku || 0).toBe(0);
  expect(pop.errors).toEqual([]);
});
