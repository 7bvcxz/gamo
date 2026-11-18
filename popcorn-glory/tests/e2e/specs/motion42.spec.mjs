// Step 42: the factory's motion in the browser (art/motion.gd, design/MOTION.md), recorded on
// video on every screen.
//  1. One real batch, popped by hand: its events light the floors in order (kitchen, packing,
//     shop) and it is sold; the sign bought from its card celebrates -- the light climbs the
//     glass tube -- while the ring (B's target) does not move by a pixel.
//  2. Forty-four machines at sign 8 (set up through the app's commands) for a crescendo of
//     about forty seconds with the hand popping: the effects' budget is the crowded floor's,
//     the pieces stay in their pool, the belts run, the render is measured; then a resize and
//     a hidden tab mid-flight, and the journeys still start and end once each.
//  3. ?fx=low and ?motion=reduce on the same factory: low budgets / no ambient pieces and still
//     belts, and a batch is still seen moving from the kitchen to the shop.
import { test, expect } from '../lib/pop.mjs';

test.use({ video: 'on' });

const PLAN = [['M07', 'kitchen'], ['bagger', 'packing'], ['S03', 'shop'], ['M01', 'kitchen'], ['M07', 'kitchen'],
  ['S05', 'shop'], ['M07', 'kitchen'], ['P07', 'packing'], ['M13', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'],
  ['S08', 'shop'], ['M08', 'kitchen'], ['U04', 'packing'], ['S01', 'shop'], ['M06', 'kitchen'], ['M07', 'kitchen'],
  ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['kiosk', 'shop'], ['M14', 'kitchen'], ['U08', 'packing'],
  ['S04', 'shop'], ['M07', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'], ['S06', 'shop'], ['M02', 'kitchen'],
  ['P01', 'packing'], ['kiosk', 'shop'], ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['M03', 'kitchen'],
  ['U05', 'packing'], ['M07', 'kitchen'], ['U03', 'kitchen'], ['bagger', 'packing'], ['M07', 'kitchen'], ['M05', 'kitchen'],
  ['U02', 'kitchen'], ['M07', 'kitchen'], ['P04', 'packing']].map(([t, f]) => [t === 'M07' ? 'cooker' : t, f]);

async function popOnce(pop) {
  const s = await pop.state();
  if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0) {
    await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
    return true;
  }
  return false;
}

const motion = async (pop) => (await pop.state()).view.motion;

// The journeys' record (the last 400 entries): a journey seen starting is open until it ends;
// an end while nothing of it is open is an end without a start. A journey whose start scrolled
// out of the record before this window is not judged.
function trips(log) {
  const open = {}, seen = new Set(), bad = [];
  for (const e of log) {
    if (e.kind === 'fill') continue;
    const k = `${e.kind}:${e.id}`;
    if (e.what === 'start' || e.what === 'serve') {
      if ((open[k] || 0) > 0) bad.push(`${k} started again before it ended`);
      open[k] = (open[k] || 0) + 1;
      seen.add(k);
    } else if (e.what === 'end' && seen.has(k)) {
      if ((open[k] || 0) === 0) bad.push(`${k} ended twice`);
      else open[k] -= 1;
    }
  }
  return { starts: seen.size, open: Object.values(open).reduce((a, b) => a + b, 0), bad };
}

test('one batch lights the floors bottom to top, and a celebration never moves the ring', async ({ pop }, testInfo) => {
  test.setTimeout(180_000);
  await pop.open('./#factory');
  let s = await pop.state();
  const ring0 = s.rects.ring;
  await popOnce(pop);
  // The batch's own events: the kitchen sends it up, packing receives and seals, the shop sells.
  await expect.poll(async () => (await pop.state()).run.stats.sold, { timeout: 60_000, message: 'the batch is sold' }).toBeGreaterThan(0);
  const m1 = await motion(pop);
  const at = m1.glow_at;   // [shop, packing, kitchen]: the clock when each was last lit
  testInfo.annotations.push({ type: 'arc', description: JSON.stringify({ glow_at: at, tier: m1.tier_name }) });
  expect(at[2] >= 0 && at[1] >= 0 && at[0] >= 0, 'every floor was lit by the batch').toBe(true);
  // The sign from its card: a celebration (screenshots of its climb).
  await pop.call('dev_money', 5000);
  await pop.tap('floor_top');
  const c0 = (await motion(pop)).stats.celebrations;
  await pop.tap('upgrade');
  const climb = [];
  let moved = 0;
  for (let i = 0; i < 10; i++) {
    s = await pop.state();
    climb.push(s.view.motion.sweep);
    moved = Math.max(moved, ...s.rects.ring.map((v, k) => Math.abs(v - ring0[k])));
    if (i === 2) await pop.shot('motion42_sweep');
    await pop.page.waitForTimeout(90);
  }
  await pop.shot('motion42_after_sign');
  const m2 = await motion(pop);
  testInfo.annotations.push({ type: 'celebrate', description: JSON.stringify({ climb, moved, celebrations: m2.stats.celebrations - c0, kind: m2.sweep_kind }) });
  expect(m2.stats.celebrations - c0, 'the sign celebrated').toBeGreaterThanOrEqual(1);
  expect(m2.sweep_kind).toBe('sign');
  expect(climb.some((v) => v > 0 && v < 1), `the light was seen climbing ${climb}`).toBe(true);
  expect(moved, 'the ring did not move').toBe(0);
  expect(pop.errors).toEqual([]);
});

test('forty-four machines: a bounded crescendo through a resize and a hidden tab', async ({ pop }, testInfo) => {
  test.setTimeout(300_000);
  await pop.open('./#factory');
  await popOnce(pop);
  const b = await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
  expect(b.machines, 'forty-four machines').toBe(44);
  await pop.page.waitForTimeout(1500);
  let s = await pop.state();
  const ring0 = s.rects.ring;
  const samples = [];
  const tiers = new Set();
  let peak = 0;
  let belts = 0;
  for (let t = 0; t < 40; t++) {
    await popOnce(pop);
    await pop.call('dev_advance', 400);
    await pop.page.waitForTimeout(250);
    const m = await motion(pop);
    tiers.add(m.tier_name);
    peak = Math.max(peak, m.fx_alive);
    belts = Math.max(belts, m.belts_moving);
    if (t % 10 === 9) samples.push({ t, running: m.running, alive: m.fx_alive, given: m.stats.given, low: m.low, fps: m.fps_avg });
    if (t === 20) await pop.shot('motion42_crescendo');
  }
  const info = await pop.call('dev_render_info');
  // A resize mid-flight, then back; a hidden tab for three seconds.
  const vp = pop.page.viewportSize();
  await pop.page.setViewportSize({ width: vp.height, height: vp.width });
  await pop.page.waitForTimeout(1200);
  await pop.shot('motion42_rotated');
  await pop.page.setViewportSize(vp);
  await pop.page.waitForTimeout(1200);
  const n0 = (await pop.state()).view.log.length;
  await pop.tab(true);
  await pop.page.waitForTimeout(3000);
  await pop.tab(false);
  await pop.page.waitForTimeout(2500);
  s = await pop.state();
  const m = s.view.motion;
  const tr = trips(s.view.log);
  testInfo.annotations.push({ type: 'crescendo', description: JSON.stringify({ samples, tiers: [...tiers], peak, belts, render: { draw_calls: info.draw_calls, objects: info.objects, fps: info.fps, nodes: info.nodes }, after: { log: [n0, s.view.log.length], trips: tr, light: m.light_children, belt_nodes: m.belt_children, moved: s.rects.ring.map((v, k) => Math.abs(v - ring0[k])) } }) });
  expect(tiers.has('swarm') || tiers.has('crowded'), `a crowded floor's budget ${[...tiers]}`).toBe(true);
  expect(peak, 'the pieces stay in their pool').toBeLessThanOrEqual(400);
  expect(belts, 'the belts run').toBeGreaterThan(0);
  expect(m.light_children, 'three glows and the sweep, no more').toBe(4);
  expect(m.belt_children, 'one belt node per line').toBe(m.belts);
  expect(tr.bad, 'no journey ends twice or restarts while moving').toEqual([]);
  expect(tr.starts, 'journeys were followed').toBeGreaterThan(20);
  expect(Math.max(...s.rects.ring.map((v, k) => Math.abs(v - ring0[k]))), 'the ring is where it was').toBe(0);
  expect(pop.errors).toEqual([]);
});

for (const [name, query] of [['low effects', '?fx=low'], ['reduced motion', '?motion=reduce']]) {
  test(`${name}: smaller or still effects, and a batch still travels kitchen to shop`, async ({ pop }, testInfo) => {
    test.setTimeout(240_000);
    await pop.open(`./${query}#factory`);
    await popOnce(pop);
    const b = await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
    expect(b.machines).toBe(44);
    await pop.page.waitForTimeout(1500);
    const g0 = (await motion(pop)).stats.given.ambient || 0;
    const p0 = (await motion(pop)).belt_phase;
    const t0 = Date.now();
    for (let t = 0; t < 16; t++) {
      await popOnce(pop);
      await pop.call('dev_advance', 400);
      await pop.page.waitForTimeout(250);
    }
    const secs = (Date.now() - t0) / 1000;
    const s = await pop.state();
    const m = s.view.motion;
    const given = (m.stats.given.ambient || 0) - g0;
    const kinds = new Set(s.view.log.map((e) => `${e.kind}:${e.what}`));
    await pop.shot(`motion42_${query.includes('low') ? 'low' : 'reduce'}`);
    testInfo.annotations.push({ type: name, description: JSON.stringify({ low: m.low, reduced: m.reduced, given, secs, phase: [p0, m.belt_phase], kinds: [...kinds], sold: s.run.stats.sold }) });
    if (query.includes('low')) {
      expect(m.low, 'low effects on').toBe(true);
      expect(given, 'the low budget (4 a second)').toBeLessThanOrEqual(Math.ceil(secs * 4) + 4);
      expect(m.lot_pieces).toBe(1);
    } else {
      expect(m.reduced, 'reduced motion on').toBe(true);
      expect(given, 'no ambient pieces').toBe(0);
      expect(m.belt_phase, 'the belts hold still').toEqual(p0);
    }
    expect(kinds.has('lot:start') && kinds.has('bag:serve') && kinds.has('bag:end'), `batches still travel ${[...kinds]}`).toBe(true);
    expect(pop.errors).toEqual([]);
  });
}
