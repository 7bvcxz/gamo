// Step 21: the storefront in a real browser. One customer is waiting at the start (a calm face);
// the first pop's pack reaches them and is paid once (the ledger's one line = the money); later,
// with the shelf stocked, the queue empties between arrivals; with no stock nobody buys -- the
// queue grows to its cap, faces turn impatient, people leave, the money stays 0.
import { test, expect } from '../lib/pop.mjs';

test('first pop -> first pack -> one paid hand-over; a calm empty shop between customers', async ({ pop }) => {
  test.setTimeout(120_000);
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.run.queue, 'one customer waiting when the shop opens').toBe(1);
  expect(s.view.moods, 'a calm face').toEqual(['wait']);
  await pop.shot('factory21_one_customer');
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.sales_logged, { timeout: 20_000, message: 'the first sale' }).toBe(1);
  s = await pop.state();
  expect(s.run.ledger.length, 'one ledger line').toBe(1);
  expect(s.run.money, 'the money is that line, once').toBe(s.run.ledger[0].coins);
  expect(s.run.stats.sold).toBe(1);
  // Stock up, then wait until the shop is empty between arrivals.
  for (let i = 0; i < 3; i++) {
    s = await pop.state();
    await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
    await pop.page.waitForTimeout(1200);
  }
  await expect.poll(async () => {
    const r = (await pop.state()).run;
    return r.queue === 0 && !r.serving && r.shelf > 0;
  }, { timeout: 60_000, message: 'a moment with nobody in the shop and packs ready' }).toBe(true);
  s = await pop.state();
  expect(s.view.customers, 'no invented customer').toBe(0);
  await pop.shot('factory21_empty_shop');
  const ledger = s.run.ledger;
  expect(new Set(ledger.map((l) => l.pack)).size, 'no pack sold twice').toBe(ledger.length);
  expect(new Set(ledger.map((l) => l.customer)).size, 'nobody bought twice').toBe(ledger.length);
  expect(pop.errors).toEqual([]);
});

test('no stock, no sale: the queue fills, faces change, people leave, money stays 0', async ({ pop }) => {
  test.setTimeout(90_000);
  await pop.open('./#factory');
  await pop.call('dev_advance', 50_000);
  await expect.poll(async () => (await pop.state()).run.queue).toBeGreaterThan(2);
  let s = await pop.state();
  expect(s.view.moods.includes('impatient'), 'someone waiting long looks impatient').toBe(true);
  await pop.page.waitForTimeout(600);
  await pop.shot('factory21_queue_no_stock');
  await pop.call('dev_advance', 120_000);
  s = await pop.state();
  expect(s.run.stats.sold, 'nothing sold').toBe(0);
  expect(s.run.money, 'no money').toBe(0);
  expect(s.run.stats.abandoned, 'people left').toBeGreaterThan(0);
  expect(s.run.queue).toBeLessThanOrEqual(5);
  expect(pop.errors).toEqual([]);
});
