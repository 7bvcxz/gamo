// Step 19: the factory's hand kettle in a real browser. A perfect hold makes a lot of the
// kettle's portions (no money at the pop); an unaffordable upgrade card answers (the frame's
// 'denied' is logged, the money unchanged); the crescendo meter fills (2 kernels a perfect);
// the kitchen detail shows the next level's numbers. Works the same on the 360-wide phone.
import { test, expect } from '../lib/pop.mjs';

test('the factory kettle: a real lot, the crescendo fills, an unaffordable card answers', async ({ pop }) => {
  test.setTimeout(90_000);
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.run.burst_mode, 'the factory has the crescendo').toBe(true);
  const cap = s.run.kettle_capacity;
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.stats.lots).toBe(1);
  s = await pop.state();
  const perfect = s.run.outcomes.perfect === 1;
  expect(s.run.stats.made_portions, 'the lot: the kettle\'s portions by grade').toBe(perfect ? cap : s.run.stats.made_portions);
  expect(s.run.crescendo, 'the meter').toBe(perfect ? 2 : s.run.outcomes.near ? 1 : 0);
  // The upgrade costs 30; with less, the card answers.
  expect(s.run.money).toBeLessThan(30);
  const money = s.run.money;
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.call('log')).some((l) => l.type === 'denied'), { message: 'the card answers (denied)' }).toBe(true);
  expect((await pop.state()).run.money, 'nothing bought').toBe(money);
  expect((await pop.state()).run.level).toBe(0);
  await pop.shot('factory19');
  expect(pop.errors).toEqual([]);
});
