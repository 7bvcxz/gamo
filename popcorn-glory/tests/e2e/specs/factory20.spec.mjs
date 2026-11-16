// Step 20: the packing station in a real browser. A perfect pop's real portions reach the bin;
// an open bag appears under the head and fills one puff per portion, the head seals it, and the
// same bag leaves for the shelf (the view's record follows the model's pack ids). The middle
// floor's card sells the station: without the money it answers (denied), the kettle untouched.
import { test, expect } from '../lib/pop.mjs';

test('the packing station: fill, seal, shelf; the middle floor card sells the station', async ({ pop }) => {
  test.setTimeout(90_000);
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.view.packer_status, 'nothing to pack yet').toBe('starved');
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).view.filling.length, { message: 'an open bag under the head' }).toBeGreaterThan(0);
  s = await pop.state();
  const fill = s.view.filling[0];
  expect(fill.size, 'it will hold the pack\'s real portions').toBe(s.run.packing[0].size);
  expect(s.run.packing.map((p) => p.id), 'the bag is a pack the model is filling').toContain(fill.id);
  await pop.shot('factory20_filling');
  await expect.poll(async () => {
    const v = (await pop.state()).view;
    const f = v.filling.find((x) => x.id === fill.id);
    return f ? (f.sealed ? 'sealed' : 'filling') : 'left';
  }, { message: 'sealed before it leaves', intervals: [50] }).toMatch(/sealed|left/);
  await expect.poll(async () => (await pop.state()).run.stats.packed, { timeout: 15_000 }).toBeGreaterThan(0);
  const log = (await pop.state()).view.log.filter((l) => l.id === fill.id);
  expect(log.filter((l) => l.kind === 'fill').map((l) => l.what), 'one fill, started and ended').toEqual(['start', 'end']);
  expect(log.filter((l) => l.kind === 'bag' && l.what === 'start').length, 'then the same pack goes to the shelf').toBe(1);
  // The middle floor's card: the station, not the kettle.
  await pop.tap('floor_mid');
  await expect.poll(async () => !!(await pop.state()).rects.detail).toBe(true);
  s = await pop.state();
  expect(s.run.money).toBeLessThan(60);
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.call('log')).some((l) => l.type === 'denied' && l.data.offer === 'packer'), { message: 'the station card answers (denied)' }).toBe(true);
  s = await pop.state();
  expect(s.run.packer_tier, 'not bought without the money').toBe(0);
  expect(s.run.level, 'the kettle untouched').toBe(0);
  await pop.shot('factory20_detail');
  expect(pop.errors).toEqual([]);
});
