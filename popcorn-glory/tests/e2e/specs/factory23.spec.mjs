// Step 23: orders in a real browser, with two products. The large bag opens with the twin-head
// station; customers' bubbles show what each wants; every sale gives the customer the size they
// ordered, once (the ledger against the orders the model drew); the floor that holds things back
// is outlined (production while people wait for popcorn).
import { test, expect } from '../lib/pop.mjs';

test('two products: each customer gets the bag they ordered, once; the cue names the bottleneck', async ({ pop }) => {
  test.setTimeout(150_000);
  await pop.open('./#factory');
  // Step 24: the station is for sale after its first sealed pack.
  const s0 = await pop.state();
  await pop.hold('ring', Math.round((s0.run.window[0] + s0.run.window[1]) / 2));
  await expect.poll(async () => (await pop.state()).run.open.packer, { timeout: 20_000 }).toBe(true);
  await pop.call('dev_money', 2400);
  await pop.tap('floor_mid');
  await expect.poll(async () => !!(await pop.state()).rects.detail).toBe(true);
  await pop.tap('upgrade');
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(2);
  let s = await pop.state();
  expect(s.run.sizes_open, 'the large bag is open').toEqual([2, 4]);
  await pop.tap('floor_mid');
  // Let people come and order, watching the cue while nothing is made.
  await pop.call('dev_advance', 45_000);
  await expect.poll(async () => (await pop.state()).view.cue).toBe('production');
  s = await pop.state();
  expect(s.view.bubbles.length, 'every waiting customer has a bubble').toBe(s.run.queue);
  await pop.shot('factory23_orders');
  // Now cook for a while.
  const t0 = Date.now();
  while (Date.now() - t0 < 50_000) {
    s = await pop.state();
    if (!s.run.heating && Object.keys(s.run.glass).length === 0) {
      await pop.hold('ring', Math.round((s.run.window[0] + s.run.window[1]) / 2));
    } else {
      await pop.page.waitForTimeout(250);
    }
  }
  s = await pop.state();
  const sizes = new Set(s.run.ledger.map((l) => l.size));
  expect(s.run.stats.sold, 'sales happened').toBeGreaterThan(3);
  expect(sizes.has(2) && sizes.has(4), `both bags sold (${[...sizes]})`).toBe(true);
  for (const l of s.run.ledger) expect(l.size, `sale of pack ${l.pack}: the size the customer ordered`).toBe(l.ordered);
  expect(new Set(s.run.ledger.map((l) => l.pack)).size, 'no pack twice').toBe(s.run.ledger.length);
  expect(new Set(s.run.ledger.map((l) => l.customer)).size, 'nobody twice').toBe(s.run.ledger.length);
  expect(s.run.ledger.reduce((a, l) => a + l.coins, 0), 'the ledger is the revenue').toBe(s.run.stats.revenue);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
  await pop.shot('factory23_two_products');
  expect(pop.errors).toEqual([]);
});
