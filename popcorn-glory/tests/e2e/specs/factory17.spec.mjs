// Step 17: the factory's model in a real browser with real input. The first customer is
// already waiting; a hold into the gold makes a lot but no money; money appears only when the
// pack reaches the customer -- exactly the pack's price, and always equal to the model's
// revenue; every portion made is somewhere (the state's own count against what was made).
import { test, expect } from '../lib/pop.mjs';

test('the factory: no money at the pop, the first sale pays the pack price, goods are conserved', async ({ pop }) => {
  test.setTimeout(90_000);
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.run.queue, 'the first customer is waiting when the shop opens').toBe(1);
  expect(s.run.money).toBe(0);
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.stats.lots).toBe(1);
  s = await pop.state();
  expect(s.run.stats.sold, 'not sold yet at the pop').toBe(0);
  expect(s.run.money, 'the pop itself pays nothing').toBe(0);
  await expect.poll(async () => (await pop.state()).run.stats.sold, { message: 'the waiting customer buys', timeout: 20_000 }).toBe(1);
  s = await pop.state();
  expect(s.run.money, 'money = the model revenue').toBe(s.run.stats.revenue);
  expect([10, 9, 8, 7].includes(s.run.money), `one pack's price (${s.run.money})`).toBe(true);
  expect(s.run.portions_everywhere, 'every portion made is somewhere').toBe(s.run.stats.made_portions);
  await pop.shot('factory17_sale');
  expect(pop.errors).toEqual([]);
});
