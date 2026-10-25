// Step 19: an assigned Momo runs the farm with no taps -- every stage at four
// times the player's work time, with the world's 30-second waits unchanged --
// and the harvest is sold; a player tap during Momo's work is refused.
import { test, expect } from '../lib/fixtures.mjs';

test('Momo farms alone', async ({ game }) => {
  await game.setTimeScale(0);
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  expect((await game.command({ type: 'momo.assign', momo: 1, building: id })).ok).toBe(true);
  let s = await game.state();
  const arrive = s.momo.momos[0].end;
  await game.query('dev_advance_ms', arrive - s.now_ms + 1000);
  let farm = (await game.state()).buildings.buildings.find((b) => b.id === id);
  expect(farm.state).toBe('working');
  expect(farm.worker).toBe(1);
  expect(farm.task_end - farm.task_start).toBe(20000);
  expect((await game.command({ type: 'building.tap', id })).reason).toBe('err.busy');
  // The rest of the cycle: 19 s of sowing left, then water, wait, water, wait, water, wait, harvest.
  await game.query('dev_advance_ms', 19000 + 20000 + 30000 + 20000 + 30000 + 20000 + 30000 + 20000 + 10);
  s = await game.state();
  farm = s.buildings.buildings.find((b) => b.id === id);
  expect(farm.completed).toBe(5);
  expect((s.inventory.items.crop ?? 0) + (s.economy.money - 10) / 5).toBe(1);
  const poses = await game.query('momo_poses');
  expect(['work', 'idle', 'sleep']).toContain(poses['1'].state);
});
