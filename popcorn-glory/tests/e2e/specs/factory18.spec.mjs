// Step 18: one real batch followed with the eyes in a real browser -- a hold into the gold,
// the lot rides the glass tube up to the bin, the packer makes a bag, the bag rides up to the
// counter while the customer steps to the hand-over spot, and the coin appears only at the
// sale. The picture's journeys are checked against the model's ids: every journey that
// started ended once, the sold pack's journey ended at the sale, nothing lingers.
import { test, expect } from '../lib/pop.mjs';

test('one batch from the kettle to a satisfied customer', async ({ pop }) => {
  test.setTimeout(90_000);
  await pop.open('./#factory');
  let s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  // The lot in the tube.
  await expect.poll(async () => (await pop.state()).view.flying.some((f) => f.kind === 'lot'), { message: 'the lot rides the lift', timeout: 5000 }).toBe(true);
  await pop.shot('factory18_lot_lifting');
  // The bag on its way to the counter.
  await expect.poll(async () => (await pop.state()).view.flying.some((f) => f.kind === 'bag' && f.to === 'counter'), { message: 'a bag rides up to the counter', timeout: 15_000 }).toBe(true);
  s = await pop.state();
  expect(s.run.money, 'no money while the bag travels').toBe(0);
  await pop.shot('factory18_bag_to_counter');
  await expect.poll(async () => (await pop.state()).run.stats.sold, { message: 'sold', timeout: 10_000 }).toBe(1);
  await pop.page.waitForTimeout(800);
  s = await pop.state();
  expect(s.run.money).toBe(s.run.stats.revenue);
  await pop.shot('factory18_sold');
  const log = s.view.log;
  const started = {}; const ended = {};
  for (const e of log) {
    const k = `${e.kind}:${e.id}`;
    if (e.what === 'start' || e.what === 'serve') started[k] = (started[k] || 0) + 1;
    if (e.what === 'end') ended[k] = (ended[k] || 0) + 1;
  }
  const sold = log.find((e) => e.what === 'sold');
  expect(sold, 'the sale is in the journey record').toBeTruthy();
  for (const k of Object.keys(started)) {
    const flying = s.view.flying.some((f) => `${f.kind}:${f.id}` === k);
    if (!flying) expect(ended[k] || 0, `${k}: every journey that started ended once`).toBe(started[k]);
  }
  expect(s.view.flying.filter((f) => f.kind === 'bag' && f.id === sold.id).length, 'the sold bag no longer flies').toBe(0);
  expect(pop.errors).toEqual([]);
});
