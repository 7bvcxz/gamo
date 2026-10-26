// Step 17: a Momo on the island idles (and blinks) by day and sleeps at
// night, on the simulation's clock. Step 53: a fresh island has none -- the
// player hires the first, and it stands idle.
import { test, expect } from '../lib/fixtures.mjs';

test('Momo idles by day and sleeps at night', async ({ game }) => {
  await game.setTimeScale(0);
  expect((await game.state()).momo.momos.length, 'a fresh island: no Momo').toBe(0);
  await game.query('dev_add_money', 100);
  expect((await game.command({ type: 'momo.hire' })).ok).toBe(true);
  await game.page.waitForTimeout(200);
  const s = await game.state();
  expect(s.momo.momos.length).toBe(1);
  expect(s.momo.momos[0].name).toBe('momo.name.0');
  expect(s.momo.momos[0].assigned, 'a hire waits to be placed').toBe(0);
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
