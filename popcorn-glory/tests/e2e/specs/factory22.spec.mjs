// Step 22: foot traffic in a real browser. The shop's card sells the sign (denied without the
// money, bought with it: customers come more often -- the model's expected wait drops, the sign
// changes); the whole factory survives a reload (goods, money, tiers, the next customer); a
// seeded session (?seed=N) starts fresh and is never saved.
import { test, expect } from '../lib/pop.mjs';

const KEY = 'popcorn-glory.factory.v1';
const saved = (pop) => pop.page.evaluate((k) => { const v = localStorage.getItem(k); return v ? JSON.parse(v) : null; }, KEY);

test('the shop card sells the sign; the factory is saved across a reload', async ({ pop }) => {
  test.setTimeout(120_000);
  await pop.open('./#factory');
  await pop.page.evaluate((k) => localStorage.removeItem(k), KEY);
  // Step 24: the sign is for sale after the first sale.
  let s0 = await pop.state();
  expect(s0.run.open.sign, 'the sign is not for sale before the first sale').toBe(false);
  await pop.hold('ring', Math.round((s0.run.window[0] + s0.run.window[1]) / 2));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 20_000 }).toBe(true);
  await pop.tap('floor_top');
  await expect.poll(async () => !!(await pop.state()).rects.detail).toBe(true);
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.call('log')).some((l) => l.type === 'denied' && l.data.offer === 'sign'), { message: 'the sign card answers' }).toBe(true);
  let s = await pop.state();
  const wait0 = s.run.mean_wait_ms;
  await pop.call('dev_money', 80 - (await pop.state()).run.money + 5);
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(1);
  s = await pop.state();
  expect(s.run.mean_wait_ms, 'customers come more often').toBeLessThan(wait0);
  expect(s.run.level + s.run.packer_tier, 'nothing else bought').toBe(0);
  await pop.shot('factory22_sign');
  // A lot in the works, then a reload.
  await pop.hold('ring', Math.round((s.run.window[0] + s.run.window[1]) / 2));
  await pop.page.waitForTimeout(2500);
  await pop.call('dev_save');
  const before = (await pop.state()).run;
  expect((await saved(pop))?.rules?.sign_tier, 'saved').toBe(1);
  await pop.page.reload();
  await pop.ready();
  await expect.poll(async () => (await pop.state()).exp).toBe('factory');
  const after = (await pop.state()).run;
  for (const k of ['sign_tier', 'packer_tier', 'level']) expect(after[k], `${k} after a reload`).toBe(before[k]);
  expect(after.stats.made_portions, 'the popcorn made').toBe(before.stats.made_portions);
  expect(after.portions_everywhere, 'every portion still somewhere').toBe(after.stats.made_portions);
  expect(after.money).toBeGreaterThanOrEqual(before.money);
  expect(pop.errors).toEqual([]);
});

test('a seeded session is fresh and never saved', async ({ pop }) => {
  await pop.open('./?seed=5#factory');
  await pop.page.evaluate((k) => localStorage.removeItem(k), KEY);
  const s = await pop.state();
  expect(s.run.arrivals, 'one customer waiting at the start').toEqual([0]);
  await pop.call('dev_save');
  expect(await saved(pop), 'nothing written').toBe(null);
  expect(pop.errors).toEqual([]);
});
