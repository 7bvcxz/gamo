// Step 33: forty machines at once in a real browser, built the way a player builds them -- a
// place tapped, a machine picked, the card's button -- and each floor's next line bought from
// the overview card when the floor is full (kitchen 3 lines, packing 3, shop 2: 44 places).
// Then: every place is inside its floor and none overlaps another; the factory runs a minute
// with forty-four machines (every portion somewhere, nearly every machine worked); the overview
// shows the three rates and picks a machine's diagnostics without closing; a stopped packing
// line receives nothing and keeps nothing (the route balancer moves its goods); a hidden tab
// stops the factory and a shown one goes on (no catch-up burst); a touch drag across the floors
// builds and sells nothing; on desktop the frame rate, draw calls, kept memory and redraws.
import { test, expect } from '../lib/pop.mjs';
import os from 'node:os';

// The unit test's FORTY_PLAN (tests/unit/test_factory_rules.gd); M07 is the kitchen's auto kettle.
const PLAN = [['M07', 'kitchen'], ['bagger', 'packing'], ['S03', 'shop'], ['M01', 'kitchen'], ['M07', 'kitchen'],
  ['S05', 'shop'], ['M07', 'kitchen'], ['P07', 'packing'], ['M13', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'],
  ['S08', 'shop'], ['M08', 'kitchen'], ['U04', 'packing'], ['S01', 'shop'], ['M06', 'kitchen'], ['M07', 'kitchen'],
  ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['kiosk', 'shop'], ['M14', 'kitchen'], ['U08', 'packing'],
  ['S04', 'shop'], ['M07', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'], ['S06', 'shop'], ['M02', 'kitchen'],
  ['P01', 'packing'], ['kiosk', 'shop'], ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['M03', 'kitchen'],
  ['U05', 'packing'], ['M07', 'kitchen'], ['U03', 'kitchen'], ['bagger', 'packing'], ['M07', 'kitchen'], ['M05', 'kitchen'],
  ['U02', 'kitchen'], ['M07', 'kitchen'], ['P04', 'packing']];

async function memory(pop) {
  const cdp = await pop.page.context().newCDPSession(pop.page);
  await cdp.send('HeapProfiler.enable');
  await cdp.send('HeapProfiler.collectGarbage');
  const h = await cdp.send('Runtime.getHeapUsage');
  await cdp.detach();
  return h.usedSize + h.backingStorageSize;
}

async function popIfFree(pop) {
  const s = await pop.state();
  if (!s.run.heating && Object.keys(s.run.glass).length === 0) {
    await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  }
}

async function opened(pop) {
  await pop.open('./#factory');
  const s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 400000);
  await pop.tap('floor_top');
  for (let i = 0; i < 6; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(6);
  await pop.tap('floor_mid');
  for (let i = 0; i < 3; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(3);
}

function freeSlot(run, floor) {
  const taken = new Set(run.machines.filter((m) => m.floor === floor).map((m) => m.slot));
  for (let k = 0; k < run.slots[floor]; k++) if (!taken.has(k)) return k;
  return -1;
}

async function toggleOverview(pop, open) {
  if (!!(await pop.state()).rects.pause_all !== open) await pop.tap('overview');
  await expect.poll(async () => !!(await pop.state()).rects.pause_all, { message: `overview ${open ? 'open' : 'closed'}` }).toBe(open);
}

const inside = (a, b) => a[0] >= b[0] - 0.5 && a[1] >= b[1] - 0.5 && a[0] + a[2] <= b[0] + b[2] + 0.5 && a[1] + a[3] <= b[1] + b[3] + 0.5;
const overlap = (a, b) => a[0] < b[0] + b[2] - 0.5 && b[0] < a[0] + a[2] - 0.5 && a[1] < b[1] + b[3] - 0.5 && b[1] < a[1] + a[3] - 0.5;

async function buildAll(pop) {
  for (const [id, floor] of PLAN) {
    const type = id === 'M07' ? 'cooker' : id;
    let s = await pop.state();
    if (freeSlot(s.run, floor) < 0) {
      // A full floor grows: its next line, bought from the overview card.
      const lines = s.run.lines[floor];
      await toggleOverview(pop, true);
      await expect.poll(async () => !!(await pop.state()).rects[`ov_line_${floor}`], { message: `${floor}'s line button` }).toBe(true);
      await pop.tap(`ov_line_${floor}`);
      await expect.poll(async () => (await pop.state()).run.lines[floor], { message: `${floor} bought a line` }).toBe(lines + 1);
      await toggleOverview(pop, false);
      s = await pop.state();
    }
    const n = s.run.machines.length;
    const k = freeSlot(s.run, floor);
    // An open card covers a floor (on a phone, the last machine's card): close it first, as a
    // player does -- the open floor's badge.
    if (s.rects.detail && s.view.selected >= 0 && overlap(s.rects[`slot_${floor}_${k}`], s.rects.detail)) {
      await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
      await expect.poll(async () => !!(await pop.state()).rects.detail, { message: 'the card closed' }).toBe(false);
    }
    await pop.tap(`slot_${floor}_${k}`);
    try {
      await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the ${floor} picker` }).toBe(true);
    } catch (e) {
      const x = await pop.state();
      test.info().annotations.push({ type: 'picker', description: JSON.stringify({ k, floor, slot: s.rects[`slot_${floor}_${k}`], rects: Object.keys(x.rects).filter((a) => a.startsWith('pick') || a.startsWith('m_') || a === 'detail' || a === 'pause_all'), sel: x.view.ov_machine, run_sel: x.run.machines.length }) });
      await pop.shot(`factory33_picker_fail_${floor}_${k}`);
      throw e;
    }
    await pop.tap(`pick_${type}`);
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built on ${floor} ${k}` }).toBe(n + 1);
  }
}


test('forty-four machines at once: built by hand, readable, routed, recovering, measured', async ({ pop }, testInfo) => {
  test.setTimeout(900_000);
  await opened(pop);
  await buildAll(pop);
  let s = await pop.state();
  expect(s.run.machines.length, 'forty-four machines stand in the factory').toBe(44);
  expect(s.run.lines).toEqual({ kitchen: 3, packing: 3, shop: 2 });
  expect(s.run.parallel, 'three packing lines are parallel lines').toBe(true);
  expect(s.view.dense, 'every floor draws its lines compactly').toEqual({ kitchen: true, packing: true, shop: true });
  expect(s.view.machine_nodes, 'a node per machine').toBe(44);

  // Every place inside its floor, none over another, none too small to tap.
  const floorOf = { kitchen: 'floor_low', packing: 'floor_mid', shop: 'floor_top' };
  const all = [];
  let smallest = 1e9;
  for (const f of ['kitchen', 'packing', 'shop']) {
    for (let k = 0; k < s.run.slots[f]; k++) {
      const r = s.rects[`slot_${f}_${k}`];
      expect(r, `place ${f} ${k} on screen`).toBeTruthy();
      expect(inside(r, s.rects[floorOf[f]]), `place ${f} ${k} inside its floor`).toBe(true);
      smallest = Math.min(smallest, r[2], r[3]);
      for (const [g, q] of all) expect(overlap(r, q), `${f} ${k} does not cover ${g}`).toBe(false);
      all.push([`${f} ${k}`, r]);
    }
  }
  expect(all.length).toBe(44);
  testInfo.annotations.push({ type: 'layout', description: JSON.stringify({ smallest_place_px: Math.round(smallest), window: s.window }) });
  expect(smallest, 'the smallest place is still a target').toBeGreaterThanOrEqual(testInfo.project.name === 'desktop' ? 18 : 24);
  await pop.shot('factory33_forty');

  // A minute and a half of the forty-four: the hand pops now and then; who works (seen
  // working, or with work done -- a kiosk serves only while the counter is full, the
  // balancer only moves a stopped line's goods).
  const ran = new Set();
  const waited = new Set();   // kettles holding a finished lot, the bin full (Step 44, D-64)
  const done0 = Object.fromEntries(s.run.machines.map((m) => [m.id, m.done]));
  let people = 0;
  for (let i = 0; i < 36; i++) {
    if (i % 2 === 0) await popIfFree(pop);
    const r = await pop.call('dev_advance', 2500);
    for (const m of r.state.run.machines) if (m.state === 'run' || m.done > (done0[m.id] || 0)) ran.add(m.id);
    for (const m of r.state.run.machines) if (m.type === 'cooker' && m.state === 'blocked') waited.add(m.id);
    people = Math.max(people, r.state.view.customers + r.state.view.leaving);
    expect(r.state.run.portions_everywhere, 'every portion is somewhere').toBe(r.state.run.stats.made_portions);
    expect(r.state.run.money).toBeGreaterThanOrEqual(0);
  }
  s = await pop.state();
  const idle = s.run.machines.filter((m) => !ran.has(m.id)).map((m) => m.type);
  const holding = s.run.machines.filter((m) => !ran.has(m.id) && waited.has(m.id)).map((m) => m.type);
  testInfo.annotations.push({ type: 'ran', description: JSON.stringify({ ran: ran.size, never: idle, holding_a_lot: holding }) });
  // Forty-four run every step; in 90 s the ones with nothing to do stay idle: the kiosks while
  // the counter's lanes keep up, the balancer until a line stops (below), a spare filler while
  // the shelf is stocked (the unit test: at most two never work in ten minutes). Step 44 (D-64):
  // while the hand's glass waits and the bin drains, the bin keeps the glass's room, so a spare
  // kettle can hold its finished lot the whole 90 s (blocked: the packers are the bottleneck,
  // the lots are alike, sales are the same). It made its lot and waits -- it is not dead. In
  // 0.43.0 at most one kettle stayed idle; with the reserve, two in 3 of 4 desktop runs.
  expect(holding.length, 'only spare kettles wait with a lot').toBeLessThanOrEqual(3);
  expect(ran.size + holding.length, `nearly every machine worked or holds its work (never: ${idle})`).toBeGreaterThanOrEqual(38);
  expect(idle.filter((t) => t === 'cooker').length, 'every idle kettle holds a finished lot').toBe(holding.length);
  expect(s.run.stats.wrong_sku || 0).toBe(0);
  expect(s.run.stats.sold, 'customers were served').toBeGreaterThan(20);
  // A shop with lanes to spare serves people the step they come in: they are still drawn.
  expect(people, 'the customers who buy are on screen').toBeGreaterThan(0);

  // The overview: three rates, no more lines to buy, a machine's diagnostics without closing.
  await toggleOverview(pop, true);
  s = await pop.state();
  for (const f of ['kitchen', 'packing', 'shop']) expect(s.rects[`ov_line_${f}`], `${f}: every line built`).toBeUndefined();
  const kettle = s.run.machines.find((m) => m.type === 'cooker');
  await pop.tap(`ovm_${kettle.id}`);
  await expect.poll(async () => (await pop.state()).view.ov_machine, { message: 'the kettle picked in the overview' }).toBe(kettle.id);
  expect(!!(await pop.state()).rects.pause_all, 'the card stays open').toBe(true);
  await pop.shot('factory33_overview');
  await toggleOverview(pop, false);

  // A stopped packing line: its fillers paused by hand -- it gets no new lots. Then the
  // kitchen is paused (its floor's button on a kettle's card): the other lines run dry, and
  // the route balancer brings the stopped line's popcorn to them.
  s = await pop.state();
  const line2 = s.run.machines.filter((m) => m.type === 'bagger' && m.floor === 'packing' && m.line === 1);
  expect(line2.length, 'the second packing line has fillers').toBeGreaterThan(0);
  for (const m of line2) {
    await pop.tap(`slot_packing_${m.slot}`);
    await expect.poll(async () => !!(await pop.state()).rects.m_pause).toBe(true);
    await pop.tap('m_pause');
    await expect.poll(async () => (await pop.state()).run.machines.find((x) => x.id === m.id).state).toBe('paused');
  }
  const atPause = (await pop.state()).run.line_portions[1];
  for (let i = 0; i < 4; i++) {
    await popIfFree(pop);
    await pop.call('dev_advance', 5000);
  }
  s = await pop.state();
  expect(s.run.line_portions[1], 'a stopped line is sent nothing new').toBeLessThanOrEqual(atPause);
  const moved0 = s.run.stats.moved_lots || 0;
  const kettle2 = s.run.machines.find((m) => m.type === 'cooker');
  await pop.tap(`slot_kitchen_${kettle2.slot}`);
  await expect.poll(async () => !!(await pop.state()).rects.m_group).toBe(true);
  await pop.tap('m_group');
  await expect.poll(async () => (await pop.state()).run.machines.filter((m) => m.floor === 'kitchen').every((m) => m.state === 'paused'), { message: 'the kitchen paused' }).toBe(true);
  const before2 = (await pop.state()).run.line_portions[1];
  let moved = moved0;
  for (let i = 0; i < 40 && (await pop.state()).run.line_portions[1] > 0; i++) {
    const r = await pop.call('dev_advance', 5000);
    moved = r.state.run.stats.moved_lots || 0;
  }
  s = await pop.state();
  testInfo.annotations.push({ type: 'lines', description: JSON.stringify({ at_pause: atPause, before_kitchen_pause: before2, moved: moved - moved0, line_portions: s.run.line_portions }) });
  if (before2 > 0) expect(moved - moved0, 'the balancer moved the stopped line\'s lots').toBeGreaterThan(0);
  expect(s.run.line_portions[1], 'and the stopped line keeps no popcorn while another line waits for some').toBe(0);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
  await pop.tap(`slot_kitchen_${kettle2.slot}`);
  await expect.poll(async () => !!(await pop.state()).rects.m_group).toBe(true);
  await pop.tap('m_group');
  for (const m of line2) {
    await pop.tap(`slot_packing_${m.slot}`);
    await expect.poll(async () => !!(await pop.state()).rects.m_pause).toBe(true);
    await pop.tap('m_pause');
  }
  await expect.poll(async () => (await pop.state()).run.machines.filter((x) => x.state === 'paused').length, { message: 'the line and the kitchen resumed' }).toBe(0);

  // A hidden tab: the factory waits (no frames, no time); shown again it goes on from where
  // it was -- at most a second of catch-up, never the whole absence at once.
  const before = (await pop.state()).run.now_ms;
  await pop.tab(true);
  await pop.page.waitForTimeout(6000);
  const hidden = (await pop.state()).run.now_ms;
  await pop.tab(false);
  await pop.page.waitForTimeout(2500);
  s = await pop.state();
  testInfo.annotations.push({ type: 'hidden', description: JSON.stringify({ before, hidden, after: s.run.now_ms }) });
  expect(hidden - before, 'no time passes while the tab is hidden').toBeLessThan(1500);
  expect(s.run.now_ms - hidden, 'shown again: it goes on, at most a second of catch-up beyond the real time').toBeLessThan(2500 + 1000 + 1500);
  expect(s.run.now_ms, 'and it does go on').toBeGreaterThan(hidden);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);

  // A touch drag across the floors (phones): it builds, sells and moves nothing.
  if (testInfo.project.use.hasTouch) {
    s = await pop.state();
    const n = s.run.machines.length;
    const where = s.run.machines.map((m) => `${m.id}:${m.floor}:${m.slot}`).join();
    const box = await pop.canvas.boundingBox();
    const k = box.width / s.window[0];
    const mid = s.rects.floor_mid;
    const low = s.rects.floor_low;
    const a = [box.x + (mid[0] + mid[2] * 0.3) * k, box.y + (mid[1] + mid[3] * 0.35) * k];
    const b = [box.x + (low[0] + low[2] * 0.1) * k, box.y + (low[1] + low[3] * 0.15) * k];
    const cdp = await pop.cdp();
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: a[0], y: a[1] }] });
    for (let i = 1; i <= 12; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: a[0] + (b[0] - a[0]) * i / 12, y: a[1] + (b[1] - a[1]) * i / 12 }] });
      await pop.page.waitForTimeout(30);
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await pop.page.waitForTimeout(500);
    s = await pop.state();
    expect(s.run.machines.length, 'a drag builds nothing and sells nothing').toBe(n);
    expect(s.run.machines.map((m) => `${m.id}:${m.floor}:${m.slot}`).join(), 'and moves no machine').toBe(where);
  }

  // Desktop: a real minute of the forty-four -- frame rate, draw calls, kept memory, redraws.
  if (testInfo.project.name === 'desktop') {
    const load0 = os.loadavg()[0];
    const heap0 = await memory(pop);
    const r0 = (await pop.state()).view.redraws;
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
    s = await pop.state();
    const r1 = s.view.redraws;
    const median = [...fps].sort((x, y) => x - y)[Math.floor(fps.length / 2)];
    const redraws = Object.fromEntries(Object.keys(r1).map((key) => [key, r1[key] - r0[key]]));
    const rec = { machines: s.run.machines.length, fps, median, heap0, heap1, kept_mb: (heap1 - heap0) / 1e6,
      draw_calls: info.map((x) => x.draw_calls), objects: info.map((x) => x.objects), nodes: info.map((x) => x.nodes), static_mem: info.map((x) => x.static_mem),
      redraws_per_min: redraws, cargo: s.view.cargo_stats, pool: s.view.pool, actor_nodes: s.view.actor_nodes, load: [load0, os.loadavg()[0]] };
    testInfo.annotations.push({ type: 'perf', description: JSON.stringify(rec) });
    expect(heap1 - heap0, 'kept memory grows less than 20 MB over a minute').toBeLessThan(20e6);
    expect(redraws.floors, 'the floors are not redrawn for the machines\' states').toBeLessThan(30);
    expect(s.view.cargo_stats.reused, 'lots and bags are reused, not made each time').toBeGreaterThan(s.view.cargo_stats.made);
    if (load0 < 6) expect(median, `frame rate with forty-four machines (load ${load0.toFixed(1)})`).toBeGreaterThan(20);
  }
  expect(pop.errors).toEqual([]);
});
