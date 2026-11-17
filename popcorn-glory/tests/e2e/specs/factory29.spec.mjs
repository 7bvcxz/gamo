// Step 29: the advanced kitchen in a real browser. With the sign at 6 and the station at 2, a
// distributor (M10) opens two more kitchen places; kettles, the rotary popper (M16), a hopper and
// the sorter, quality sensor, vents, recycler and dispatcher are built from the picker. Over two
// and a half minutes (fast-forward) with a hand popping now and then: the drum pours, the hand's
// perfect lots become premium and premium customers buy premium packs (every sale the SKU that
// was ordered), the vents keep three kettles cooking, every portion is accounted for. Then the
// kitchen without vents overheats (desktop), and a minute of real time measures the frame rate and
// the memory the page keeps with a busy factory (desktop).
import { test, expect } from '../lib/pop.mjs';
import os from 'node:os';

async function memory(pop) {
  const cdp = await pop.page.context().newCDPSession(pop.page);
  await cdp.send('HeapProfiler.enable');
  await cdp.send('HeapProfiler.collectGarbage');
  const h = await cdp.send('Runtime.getHeapUsage');
  await cdp.detach();
  return h.usedSize + h.backingStorageSize;
}

async function opened(pop, money) {
  await pop.open('./#factory');
  let s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', money);
  await pop.tap('floor_top');
  for (let i = 0; i < 6; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(6);
  await pop.tap('floor_mid');
  for (let i = 0; i < 2; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(2);
}

async function build(pop, list) {
  for (const [slot, type] of list) {
    const n = (await pop.state()).run.machines.length;
    await pop.tap(`slot_kitchen_${slot}`);
    await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the picker` }).toBe(true);
    await pop.tap(`pick_${type}`);
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built` }).toBe(n + 1);
  }
}

async function popIfFree(pop) {
  const s = await pop.state();
  if (!s.run.heating && Object.keys(s.run.glass).length === 0) {
    await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  }
}

test('the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents', async ({ pop }) => {
  test.setTimeout(240_000);
  await opened(pop, 90000);
  await build(pop, [[0, 'cooker'], [1, 'M10']]);
  await expect.poll(async () => (await pop.state()).run.kitchen_slots, { message: 'two more kitchen places' }).toBe(10);
  await pop.tap('slot_kitchen_2');
  const rects = (await pop.state()).rects;
  const picks = Object.keys(rects).filter((k) => k.startsWith('pick_'));
  expect(picks.length, `the picker lists the open kitchen machines (${picks})`).toBeGreaterThanOrEqual(14);
  // Step 34 woke the flavor base mixer (it shortens coating batches); U07 still waits for the news.
  expect(rects.pick_M12, 'the flavor mixer is sold since flavors (Step 34)').toBeTruthy();
  expect(rects.pick_U07, 'the demand scheduler is not sold before the news').toBeUndefined();
  await pop.shot('factory29_picker');
  await build(pop, [[2, 'cooker'], [3, 'M16'], [4, 'M01'], [5, 'M09'], [6, 'M11'], [7, 'M13'], [8, 'M14'], [9, 'M15']]);
  let s = await pop.state();
  expect(s.run.machines.map((m) => m.type)).toEqual(['cooker', 'M10', 'cooker', 'M16', 'M01', 'M09', 'M11', 'M13', 'M14', 'M15']);
  await pop.shot('factory29_kitchen');
  for (let i = 0; i < 30; i++) {
    await popIfFree(pop);
    await pop.call('dev_advance', 5000);
  }
  s = await pop.state();
  const st = s.run.stats;
  const rot = s.run.machines.find((m) => m.type === 'M16');
  expect(rot.done, 'the rotary popper poured lots').toBeGreaterThan(10);
  expect(st.premium_lots || 0, 'the hand\'s perfect lots became premium').toBeGreaterThan(0);
  expect(st.wrong_sku || 0, 'no customer got a SKU they did not order').toBe(0);
  for (const e of s.run.ledger) expect(e.recipe, 'each sale the SKU that was ordered').toBe(e.ordered_recipe);
  expect(st.overheat_stops || 0, 'with the vents, no overheat stop').toBe(0);
  expect(s.run.money).toBeGreaterThanOrEqual(0);
  expect(s.run.portions_everywhere, 'every portion is somewhere').toBe(st.made_portions);
  test.info().annotations.push({ type: 'kitchen', description: JSON.stringify({ rotary: rot.done, auto_lots: st.auto_lots, premium_lots: st.premium_lots, premium_sold: st.premium_sold || 0, sorted: st.sorted_lots || 0, dispatch_held_ms: st.dispatch_held_ms || 0, vent_saves: st.vent_saves || 0, upkeep: st.upkeep_paid, kernels: st.kernels_paid }) });
  await pop.shot('factory29_running');
  expect(pop.errors).toEqual([]);
});

test('without vents five kettles overheat; with them the kitchen keeps cooking', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop runs the heat');
  test.setTimeout(200_000);
  await opened(pop, 90000);
  await build(pop, [[0, 'cooker'], [1, 'cooker'], [2, 'cooker'], [3, 'cooker'], [4, 'M16'], [5, 'M01'], [6, 'M01']]);
  for (let i = 0; i < 24; i++) await pop.call('dev_advance', 5000);
  let s = await pop.state();
  const stops = s.run.stats.overheat_stops || 0;
  expect(stops, 'five kettles without vents overheat').toBeGreaterThan(0);
  await expect.poll(async () => (await pop.state()).run.overheat_left > 0 || (await pop.state()).run.kitchen_heat > 40, { timeout: 30_000 }).toBe(true);
  await pop.shot('factory29_hot');
  await build(pop, [[7, 'M13']]);
  for (let i = 0; i < 24; i++) await pop.call('dev_advance', 5000);
  s = await pop.state();
  expect(s.run.stats.overheat_stops, 'with the vents no new stop').toBe(stops);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
  expect(pop.errors).toEqual([]);
});

test('a minute of a busy advanced factory: frame rate and kept memory', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop measures');
  test.setTimeout(240_000);
  await opened(pop, 90000);
  await build(pop, [[0, 'cooker'], [1, 'M10'], [2, 'cooker'], [3, 'M16'], [4, 'M01'], [5, 'M09'], [6, 'M11'], [7, 'M13'], [8, 'M14'], [9, 'M15']]);
  const load0 = os.loadavg()[0];
  const heap0 = await memory(pop);
  const fps = [];
  const info = [];
  const t0 = Date.now();
  while (Date.now() - t0 < 60_000) {
    await popIfFree(pop);
    if (fps.length < 6 && (Date.now() - t0) > fps.length * 10_000) {
      fps.push(await pop.fps(1000));
      info.push(await pop.call('dev_render_info'));
    }
    await pop.page.waitForTimeout(1500);
  }
  const heap1 = await memory(pop);
  const median = [...fps].sort((a, b) => a - b)[Math.floor(fps.length / 2)];
  const rec = { fps, median, heap0, heap1, kept_mb: (heap1 - heap0) / 1e6, draw_calls: info.map((x) => x.draw_calls), objects: info.map((x) => x.objects), load: [load0, os.loadavg()[0]] };
  test.info().annotations.push({ type: 'perf', description: JSON.stringify(rec) });
  expect(heap1 - heap0, 'kept memory grows less than 20 MB over a minute').toBeLessThan(20e6);
  if (load0 < 6) expect(median, `frame rate with a busy kitchen (load ${load0.toFixed(1)})`).toBeGreaterThan(20);
  expect(pop.errors).toEqual([]);
});
