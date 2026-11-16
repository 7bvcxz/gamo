// Step 16: the three-floor factory (#factory) in a real browser. On every screen: the floors
// stack inside the screen without overlapping, the ring sits inside the kitchen, the card never
// covers a floor or the ring, the news place is the shop's top right. Real input: a hold on the
// kettle cooks (B), a tap on the packing floor opens its detail and does not cook, a second tap
// closes it; on desktop key 2 opens it. Desktop also measures what the redraw gate is for: the
// memory kept (after GC) while idle, the factory against the stand.
import { test, expect } from '../lib/pop.mjs';

const inside = (a, b) => a[0] >= b[0] - 1 && a[1] >= b[1] - 1 && a[0] + a[2] <= b[0] + b[2] + 1 && a[1] + a[3] <= b[1] + b[3] + 1;
const apart = (a, b) => a[0] + a[2] <= b[0] || b[0] + b[2] <= a[0] || a[1] + a[3] <= b[1] || b[1] + b[3] <= a[1];

test('the factory: three floors fit, the ring is in the kitchen, nothing covers them', async ({ pop }) => {
  await pop.open('./#factory');
  const s = await pop.state();
  const r = s.rects;
  const win = [0, 0, s.window[0], s.window[1]];
  for (const k of ['floor_top', 'floor_mid', 'floor_low', 'ring', 'news', 'badge_top', 'badge_mid', 'badge_low', 'upgrade']) {
    expect(r[k], `${k} exists`).toBeTruthy();
    expect(inside(r[k], win), `${k} inside the window`).toBe(true);
  }
  expect(apart(r.floor_top, r.floor_mid) && apart(r.floor_mid, r.floor_low), 'floors do not overlap').toBe(true);
  expect(r.floor_top[1] < r.floor_mid[1] && r.floor_mid[1] < r.floor_low[1], 'shop above packing above kitchen').toBe(true);
  expect(inside(r.ring, r.floor_low), 'the ring inside the kitchen').toBe(true);
  for (const k of ['floor_top', 'floor_mid', 'floor_low', 'ring']) expect(apart(r.upgrade, r[k]), `the card clear of ${k}`).toBe(true);
  expect(inside(r.news, r.floor_top) && r.news[0] > r.floor_top[0] + r.floor_top[2] * 0.7, 'the news place: the shop, top right').toBe(true);
  await pop.shot('factory16');
  expect(pop.errors).toEqual([]);
});

test('the factory: the kettle cooks, a floor opens its detail without cooking', async ({ pop }, testInfo) => {
  await pop.open('./#factory');
  let s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.presses).toBe(1);
  await expect.poll(async () => (await pop.state()).run.heating).toBe(false);
  s = await pop.state();
  expect(s.run.stats.lots, 'the pop made a lot (Step 17: money comes from the sale)').toBe(1);
  await pop.page.waitForTimeout(500);
  await pop.tap('floor_mid');
  await expect.poll(async () => !!(await pop.state()).rects.detail, { message: 'the packing detail opens' }).toBe(true);
  expect((await pop.state()).run.presses, 'a tap on packing does not cook').toBe(1);
  s = await pop.state();
  expect(apart(s.rects.detail, s.rects.ring), 'the detail clear of the ring').toBe(true);
  await pop.shot('factory16_detail');
  await pop.tap('floor_mid');
  if (testInfo.project.use.hasTouch || !s.rects.detail) {
    await expect.poll(async () => !!(await pop.state()).rects.detail, { message: 'a second tap closes it' }).toBe(false);
  }
  if (!testInfo.project.use.hasTouch) {
    // Desktop (wide): the right column keeps a detail; key 2 chooses packing.
    await pop.canvas.click({ position: { x: 5, y: 5 } }).catch(() => {});
    await pop.page.keyboard.press('2');
    await expect.poll(async () => !!(await pop.state()).rects.detail, { message: 'key 2 opens a detail' }).toBe(true);
  }
  expect(pop.errors).toEqual([]);
});

async function idleSlope(pop, route) {
  await pop.open(route);
  const s = await pop.state();
  const target = s.rects.ring ? 'ring' : 'play';
  await pop.hold(target, Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await pop.page.waitForTimeout(4000);
  const cdp = await pop.page.context().newCDPSession(pop.page);
  await cdp.send('HeapProfiler.enable');
  const heap = async () => { await cdp.send('HeapProfiler.collectGarbage'); await cdp.send('HeapProfiler.collectGarbage'); return (await cdp.send('Runtime.getHeapUsage')).usedSize; };
  const a = await heap();
  await pop.page.waitForTimeout(90_000);
  const b = await heap();
  await cdp.detach();
  return (b - a) / 1.5 / 1e6;   // MB per minute
}

test('idle memory: the factory keeps far less than the stand', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop measures');
  test.setTimeout(300_000);
  const factory = await idleSlope(pop, './#factory');
  const stand = await idleSlope(pop, './#stand');
  testInfo.annotations.push({ type: 'memory', description: `idle, kept JS heap after GC: factory ${factory.toFixed(2)} MB/min, stand ${stand.toFixed(2)} MB/min` });
  console.log(`IDLE factory ${factory.toFixed(2)} stand ${stand.toFixed(2)}`);
  expect(factory, `the factory idles under 0.5 MB/min (stand ${stand.toFixed(2)})`).toBeLessThan(0.5);
  expect(pop.errors).toEqual([]);
});
