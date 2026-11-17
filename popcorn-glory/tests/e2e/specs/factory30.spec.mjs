// Step 30: the packing floor in a real browser. A kitchen (two kettles and a hopper) feeds it; the
// packing floor's four places take a bagger, the cup feeder, the weigher and the sealer from its
// picker (the flavor sprayer and coater are not sold). Over two and a half minutes (fast-forward):
// cups are a product of their own (customers who order a cup get a cup), the weigher keeps every
// overfilled portion, the sealer's shorter cycle shows in the station, nobody gets a SKU they did not
// order, every portion is accounted for. Then (desktop) the dispenser sells large bags at tier 1, and
// the floor with no popcorn stops and pays nothing.
import { test, expect } from '../lib/pop.mjs';

async function opened(pop, packer) {
  await pop.open('./#factory');
  const s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 90000);
  await pop.tap('floor_top');
  for (let i = 0; i < 4; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(4);
  await pop.tap('floor_mid');
  for (let i = 0; i < packer; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(packer);
}

async function build(pop, floor, list) {
  for (const [slot, type] of list) {
    const n = (await pop.state()).run.machines.length;
    await pop.tap(`slot_${floor}_${slot}`);
    await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the picker` }).toBe(true);
    await pop.tap(`pick_${type}`);
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built` }).toBe(n + 1);
  }
}

test('the packing floor: cups, the weigher, the sealer, honest SKUs', async ({ pop }) => {
  test.setTimeout(240_000);
  await opened(pop, 3);
  await build(pop, 'kitchen', [[0, 'cooker'], [1, 'cooker'], [2, 'M01']]);
  await pop.tap('slot_packing_0');
  const rects = (await pop.state()).rects;
  for (const id of ['bagger', 'P01', 'P02', 'P04', 'P07', 'P08']) expect(rects[`pick_${id}`], `${id} in the packing picker`).toBeTruthy();
  for (const id of ['P05', 'P06']) expect(rects[`pick_${id}`], `${id} is not sold before flavors`).toBeUndefined();
  await pop.shot('factory30_picker');
  await build(pop, 'packing', [[0, 'bagger'], [1, 'P01'], [2, 'P04'], [3, 'P07']]);
  let s = await pop.state();
  expect(s.run.machines.filter((m) => m.floor === 'packing').map((m) => m.type)).toEqual(['bagger', 'P01', 'P04', 'P07']);
  await pop.shot('factory30_floor');
  for (let i = 0; i < 30; i++) {
    const x = (await pop.state()).run;
    if (!x.heating && Object.keys(x.glass).length === 0) await pop.hold('ring', Math.round(x.window[0] + (x.window[1] - x.window[0]) * 0.25));
    await pop.call('dev_advance', 5000);
  }
  s = await pop.state();
  const st = s.run.stats;
  expect(st.sold_size_1 || 0, 'cups were sold').toBeGreaterThan(0);
  expect(st.overfill_portions || 0, 'the weigher gave nothing away').toBe(0);
  expect(st.wrong_sku || 0, 'no customer got a SKU they did not order').toBe(0);
  for (const e of s.run.ledger) {
    expect(e.recipe).toBe(e.ordered_recipe);
    expect(e.size, 'each sale the size that was ordered').toBe(e.ordered);
  }
  const bagger = s.run.machines.find((m) => m.type === 'bagger');
  const cups = s.run.machines.find((m) => m.type === 'P01');
  expect(bagger.done, 'the bagger sealed packs').toBeGreaterThan(0);
  expect(cups.done, 'the cup feeder filled cups').toBeGreaterThan(0);
  expect(s.run.portions_everywhere, 'every portion is somewhere').toBe(st.made_portions);
  test.info().annotations.push({ type: 'packing', description: JSON.stringify({ cups_sold: st.sold_size_1 || 0, small: st.sold_size_2 || 0, large: st.sold_size_4 || 0, bagger: bagger.done, cup_feeder: cups.done, packed: st.packed, upkeep: st.upkeep_paid }) });
  await pop.shot('factory30_running');
  expect(pop.errors).toEqual([]);
});

test('the dispenser sells large bags at tier 1; an empty floor stops and pays nothing', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop runs the details');
  test.setTimeout(200_000);
  await opened(pop, 1);
  expect((await pop.state()).run.sizes_open, 'tier 1: the small bag only').toEqual([2]);
  await build(pop, 'packing', [[0, 'P02']]);
  await expect.poll(async () => (await pop.state()).run.sizes_open, { message: 'with the dispenser, the large bag' }).toEqual([2, 4]);
  await build(pop, 'packing', [[1, 'bagger']]);
  const before = (await pop.state()).run.stats;
  for (let i = 0; i < 12; i++) await pop.call('dev_advance', 5000);
  let s = await pop.state();
  expect(s.run.stats.upkeep_paid, 'no popcorn: the packing floor pays nothing').toBe(before.upkeep_paid);
  expect(s.run.stats.packed, 'and packs nothing').toBe(before.packed);
  for (let i = 0; i < 24; i++) {
    const x = (await pop.state()).run;
    if (!x.heating && Object.keys(x.glass).length === 0) await pop.hold('ring', Math.round(x.window[0] + (x.window[1] - x.window[0]) * 0.25));
    await pop.call('dev_advance', 5000);
  }
  s = await pop.state();
  expect(s.run.stats.sold_size_4 || 0, 'large bags sold at tier 1').toBeGreaterThan(0);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
  expect(pop.errors).toEqual([]);
});

test('frame rate with several packers working at once', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop measures');
  test.setTimeout(200_000);
  await opened(pop, 3);
  await build(pop, 'kitchen', [[0, 'cooker'], [1, 'cooker'], [2, 'cooker'], [3, 'M01'], [4, 'M08']]);
  await build(pop, 'packing', [[0, 'bagger'], [1, 'bagger'], [2, 'P01'], [3, 'P07']]);
  for (let i = 0; i < 6; i++) await pop.call('dev_advance', 5000);   // stock in the bin, packers busy
  const fps = [];
  const info = [];
  const busy = [];
  const t0 = Date.now();
  while (Date.now() - t0 < 30_000) {
    const x = (await pop.state()).run;
    if (!x.heating && Object.keys(x.glass).length === 0) await pop.hold('ring', Math.round(x.window[0] + (x.window[1] - x.window[0]) * 0.25));
    fps.push(await pop.fps(1000));
    info.push(await pop.call('dev_render_info'));
    busy.push((await pop.state()).run.machines.filter((m) => m.floor === 'packing' && m.state === 'run').length);
    await pop.page.waitForTimeout(2000);
  }
  const median = [...fps].sort((a, b) => a - b)[Math.floor(fps.length / 2)];
  const os = await import('node:os');
  const load = os.loadavg()[0];
  test.info().annotations.push({ type: 'perf', description: JSON.stringify({ fps: fps.map((f) => +f.toFixed(1)), median, packers_running: busy, draw_calls: info.map((x) => x.draw_calls), objects: info.map((x) => x.objects), load }) });
  expect(Math.max(...busy), 'several packers ran at once').toBeGreaterThanOrEqual(2);
  if (load < 6) expect(median, `frame rate with several packers (load ${load.toFixed(1)})`).toBeGreaterThan(20);
  expect(pop.errors).toEqual([]);
});
