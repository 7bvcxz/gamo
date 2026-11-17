// Step 28: the kitchen's eight basic devices in a real browser. With the sign at 4, a kettle (M07)
// and the seven devices are built by tapping a kitchen place, the device in the picker and the card.
// Over three minutes of play (fast-forward) the hopper buys kernels and keeps the kettle cooking,
// the doser pays for oil, no auto lot burns (M03) or comes out late (M05), upkeep is paid, and every
// portion is accounted for.
import { test, expect } from '../lib/pop.mjs';

test('eight kitchen devices: built from the picker, each doing its own job with real inputs', async ({ pop }) => {
  test.setTimeout(180_000);
  await pop.open('./#factory');
  let s = await pop.state();
  await pop.hold('ring', Math.round((s.run.window[0] + s.run.window[1]) / 2));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 9000);
  await pop.tap('floor_top');
  for (let i = 0; i < 4; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(4);
  const order = ['cooker', 'M01', 'M02', 'M03', 'M04', 'M05', 'M06', 'M08'];
  for (let k = 0; k < order.length; k++) {
    await pop.tap(`slot_kitchen_${k}`);
    await expect.poll(async () => !!(await pop.state()).rects[`pick_${order[k]}`], { message: `${order[k]} in the picker` }).toBe(true);
    await pop.tap(`pick_${order[k]}`);
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${order[k]} built` }).toBe(k + 1);
  }
  s = await pop.state();
  expect(s.run.machines.map((m) => m.type)).toEqual(order);
  await pop.shot('factory28_kitchen');
  for (let i = 0; i < 36; i++) await pop.call('dev_advance', 5000);
  s = await pop.state();
  const st = s.run.stats;
  expect(st.auto_lots, 'the kettle kept cooking past its first 5 lots of kernels').toBeGreaterThan(8);
  expect(st.kernels_paid, 'the hopper bought kernels').toBeGreaterThan(0);
  expect(st.oil_paid, 'the doser paid for oil').toBeGreaterThan(0);
  expect(st.auto_burnt || 0, 'no burnt auto lot (M03)').toBe(0);
  expect(st.auto_late || 0, 'no late auto lot (M05)').toBe(0);
  expect(st.upkeep_paid, 'upkeep paid').toBeGreaterThan(0);
  expect(s.run.money).toBeGreaterThanOrEqual(0);
  expect(s.run.portions_everywhere).toBe(st.made_portions);
  await pop.shot('factory28_after');
  expect(pop.errors).toEqual([]);
});
