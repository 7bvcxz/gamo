// Step 17: the starting Momo is on the island, idles (and blinks) by day and
// sleeps at night, on the simulation's clock.
import { test, expect } from '../lib/fixtures.mjs';

test('Momo idles by day and sleeps at night', async ({ game }) => {
  await game.setTimeScale(0);
  const s = await game.state();
  expect(s.momo.momos.length).toBe(1);
  expect(s.momo.momos[0].name).toBe('momo.name.0');
  let poses = await game.query('momo_poses');
  expect(['idle', 'sit']).toContain(poses['1'].state);
  let blinked = false;
  for (let i = 0; i < 40 && !blinked; i++) {
    await game.page.waitForTimeout(150);
    blinked = (await game.query('momo_poses'))['1'].blinking;
  }
  expect(blinked).toBe(true);
  await game.query('dev_advance_to', [1, 0.82]);
  await game.page.waitForTimeout(200);
  poses = await game.query('momo_poses');
  expect(poses['1'].state).toBe('sleep');
});
