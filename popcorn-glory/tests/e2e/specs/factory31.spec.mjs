// Step 31: the storefront in a real browser. A kitchen (two kettles and a hopper) and two baggers
// feed the counter; the shop's four places take the auto cashier, the express window, the serving
// robot and the queue router from its picker. Over two and a half minutes (fast-forward) with a hand
// popping: the cashier takes payments, the express window serves small orders, the robot's lanes
// serve, nobody gets a SKU or size they did not order, every portion is accounted for. Then
// (desktop) a paused cashier holds its customers' sales until it is resumed.
import { test, expect } from '../lib/pop.mjs';

// Step 44: the picker's icons grew to a finger's size and now cover the card over the shop floor;
// a shop place under an open card is closed first, as a player would (the floor's badge).
const overlap = (a, b) => a && b && a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
async function closeCardOver(pop, rect) {
  const s = await pop.state();
  if (s.rects.detail && s.view.selected >= 0 && overlap(rect, s.rects.detail)) {
    await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
    await expect.poll(async () => !!(await pop.state()).rects.detail).toBe(false);
  }
}

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
    await closeCardOver(pop, (await pop.state()).rects[`slot_${floor}_${slot}`]);
    await pop.tap(`slot_${floor}_${slot}`);
    await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the picker` }).toBe(true);
    await pop.tap(`pick_${type}`);
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built` }).toBe(n + 1);
  }
}

async function play(pop, n) {
  for (let i = 0; i < n; i++) {
    const x = (await pop.state()).run;
    if (!x.heating && Object.keys(x.glass).length === 0) await pop.hold('ring', Math.round(x.window[0] + (x.window[1] - x.window[0]) * 0.25));
    await pop.call('dev_advance', 5000);
  }
}

test('the storefront: cashier, express window, robot lanes, router -- honest sales', async ({ pop }) => {
  test.setTimeout(260_000);
  await opened(pop);
  await build(pop, 'kitchen', [[0, 'cooker'], [1, 'cooker'], [2, 'M01'], [3, 'M08']]);
  await build(pop, 'packing', [[0, 'bagger'], [1, 'bagger']]);
  await closeCardOver(pop, (await pop.state()).rects.slot_shop_0);
  await pop.tap('slot_shop_0');
  const rects = (await pop.state()).rects;
  for (const id of ['kiosk', 'S01', 'S02', 'S03', 'S04', 'S05', 'S06', 'S08']) expect(rects[`pick_${id}`], `${id} in the shop picker`).toBeTruthy();
  await pop.shot('factory31_picker');
  await build(pop, 'shop', [[0, 'S03'], [1, 'S05'], [2, 'S08'], [3, 'S04']]);
  let s = await pop.state();
  expect(s.run.counter_lanes, 'the robot adds counter lanes').toBeGreaterThanOrEqual(4);
  await play(pop, 30);
  s = await pop.state();
  const st = s.run.stats;
  const by = Object.fromEntries(s.run.machines.map((m) => [m.type, m]));
  expect(by.S03.done, 'the cashier took payments').toBeGreaterThan(0);
  expect(by.S05.done, 'the express window served').toBeGreaterThan(0);
  expect(st.wrong_sku || 0).toBe(0);
  for (const e of s.run.ledger) {
    expect(e.recipe).toBe(e.ordered_recipe);
    expect(e.size).toBe(e.ordered);
  }
  expect(s.run.money).toBeGreaterThanOrEqual(0);
  expect(s.run.portions_everywhere, 'every portion is somewhere').toBe(st.made_portions);
  test.info().annotations.push({ type: 'shop', description: JSON.stringify({ sold: st.sold, cashier: by.S03.done, express: by.S05.done, routed: st.routed || 0, express_jumped: st.express_jumped || 0, lanes: s.run.counter_lanes, lost: (st.abandoned || 0) + (st.passed_by || 0), upkeep: st.upkeep_paid, revenue: st.revenue }) });
  await pop.shot('factory31_running');
  expect(pop.errors).toEqual([]);
});

test('a paused cashier holds its customers sales until it is resumed', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop runs the details');
  test.setTimeout(200_000);
  await opened(pop);
  await build(pop, 'kitchen', [[0, 'cooker'], [1, 'cooker'], [2, 'M01']]);
  await build(pop, 'packing', [[0, 'bagger']]);
  await build(pop, 'shop', [[0, 'S03']]);
  await play(pop, 6);
  // Choose the drawer, then pause it from its own button the moment a customer is paying.
  await pop.tap('slot_shop_0');
  await expect.poll(async () => !!(await pop.state()).rects.m_pause).toBe(true);
  // A payment lasts 0.9 s: pause when someone is at the drawer; if they finished paying before
  // the pause landed, resume and try again (a few times).
  let caught = 0;
  for (let attempt = 0; attempt < 6 && caught === 0; attempt++) {
    await expect.poll(async () => (await pop.state()).run.paying, { timeout: 90_000, intervals: [50] }).toBeGreaterThan(0);
    await pop.tap('m_pause');
    await expect.poll(async () => (await pop.state()).run.machines.find((m) => m.type === 'S03').state).toBe('paused');
    caught = (await pop.state()).run.paying;
    if (caught === 0) { await pop.tap('m_pause'); await pop.page.waitForTimeout(300); }
  }
  expect(caught, 'a customer was caught at the paused drawer').toBeGreaterThan(0);
  const sold0 = (await pop.state()).run.stats.sold;
  await play(pop, 4);
  let s = await pop.state();
  expect(s.run.paying, 'customers wait at the paused drawer').toBeGreaterThan(0);
  const held = s.run.paying_ids;
  const heldSales = s.run.stats.sold - sold0;
  await pop.tap('m_pause');
  await play(pop, 4);
  s = await pop.state();
  for (const id of held) expect(s.run.paying_ids, `resumed, customer ${id} paid and left the drawer`).not.toContain(id);
  expect(s.run.stats.sold - sold0, 'and the held sales happen').toBeGreaterThan(heldSales);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
  expect(pop.errors).toEqual([]);
});
