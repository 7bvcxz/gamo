// Step 26: one working machine on each floor, in a real browser, from real goods. The sign and the
// station opened by playing; then a cooker (kitchen), a bagger (packing) and a kiosk (shop) are
// built by tapping their places and the card (at sign 5, where one lane cannot hand over to everyone). Over two minutes of play (fast-forward) the cooker
// makes lots, the bagger seals packs from them, the kiosk hands packs to customers, and upkeep is
// paid from the wallet (money = revenue - purchases - upkeep), every portion accounted for.
import { test, expect } from '../lib/pop.mjs';

test('a cooker, a bagger and a kiosk: built from the screen, working with real goods, paid for', async ({ pop }) => {
  test.setTimeout(150_000);
  await pop.open('./#factory');
  let s = await pop.state();
  await pop.hold('ring', Math.round((s.run.window[0] + s.run.window[1]) / 2));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 4500);
  await pop.tap('floor_top');
  // Sign 5: about 27 customers a minute, more than one lane hands over (25) -- the kiosk has work.
  for (let i = 0; i < 5; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(5);
  await pop.tap('floor_mid');
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(1);
  s = await pop.state();
  expect(s.run.open.cooker && s.run.open.bagger && s.run.open.kiosk, 'all three machines open').toBe(true);
  for (const [slot, type] of [['slot_kitchen_0', 'cooker'], ['slot_packing_0', 'bagger'], ['slot_shop_0', 'kiosk']]) {
    await pop.tap(slot);
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.machines.some((m) => m.type === type), { message: `${type} built` }).toBe(true);
  }
  const spentBefore = (await pop.state()).run;
  await pop.shot('factory26_built');
  // Two minutes of play: a hand pops now and then, the machines do the rest.
  for (let i = 0; i < 24; i++) {
    s = await pop.state();
    if (!s.run.heating && Object.keys(s.run.glass).length === 0) {
      await pop.hold('ring', Math.round((s.run.window[0] + s.run.window[1]) / 2));
    }
    await pop.call('dev_advance', 5000);
  }
  s = await pop.state();
  const by = Object.fromEntries(s.run.machines.map((m) => [m.type, m]));
  expect(by.cooker.done, 'the cooker made lots').toBeGreaterThan(5);
  expect(by.bagger.done, 'the bagger sealed packs').toBeGreaterThan(0);
  expect(by.kiosk.done, 'the kiosk handed packs to customers').toBeGreaterThan(0);
  expect(s.run.stats.upkeep_paid, 'upkeep was paid from the wallet').toBeGreaterThan(0);
  expect(s.run.money).toBeGreaterThanOrEqual(0);
  expect(s.run.portions_everywhere, 'every portion is somewhere').toBe(s.run.stats.made_portions);
  expect(s.run.stats.upkeep_paid).toBeLessThan(s.run.stats.revenue);
  await pop.shot('factory26_working');
  expect(pop.errors).toEqual([]);
});
