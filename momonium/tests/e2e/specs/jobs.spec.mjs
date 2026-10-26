// Step 19, Step 50: an assigned Momo runs the farm with no taps -- every stage
// at the Momo multiple of the player's work time, with the world's waits
// unchanged -- and the harvest is sold the moment it is picked; a player tap
// during Momo's work is refused.
import { test, expect } from '../lib/fixtures.mjs';

test('Momo farms alone', async ({ game }) => {
  await game.setTimeScale(0);
  const rules = await game.query('rules');
  const work = rules.farm_stages.map(([, ms]) => ms * rules.momo_x);
  const waits = rules.farm_stages.map(([, , w]) => w);
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  expect((await game.command({ type: 'momo.assign', momo: 1, building: id })).ok).toBe(true);
  let s = await game.state();
  const arrive = s.momo.momos[0].end;
  const money0 = s.economy.money;
  await game.query('dev_advance_ms', arrive - s.now_ms + Math.floor(work[0] / 2));
  let farm = (await game.state()).buildings.buildings.find((b) => b.id === id);
  expect(farm.state).toBe('working');
  expect(farm.worker).toBe(1);
  expect(farm.task_end - farm.task_start).toBe(work[0]);
  expect((await game.command({ type: 'building.tap', id })).reason).toBe('err.busy');
  // The rest of the cycle: what is left of the sowing, then water, the wait, harvest.
  await game.query('dev_advance_ms', work[0] - Math.floor(work[0] / 2) + work[1] + waits[1] + work[2] + 10);
  s = await game.state();
  farm = s.buildings.buildings.find((b) => b.id === id);
  expect(farm.completed).toBe(rules.farm_stages.length);
  expect(s.inventory.items.crop ?? 0).toBe(0);
  expect(s.economy.money - money0).toBe(rules.crop_price);
  const poses = await game.query('momo_poses');
  expect(['work', 'idle', 'sleep']).toContain(poses['1'].state);
});
