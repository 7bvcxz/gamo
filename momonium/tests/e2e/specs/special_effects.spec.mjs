// Step 37: the landmarks do something. A Clock Tower shows its small dial;
// work started in its burst takes half as long; a School makes a Momo's ten
// jobs worth twelve skill points; a Momo Monument adds 10% (rounded) to the
// legacy a sale pays, shown on the sale screen.
import { test, expect } from '../lib/fixtures.mjs';

test('the landmarks change the game', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_grow_island', 3);
  const { id: yard } = await game.query('dev_place_building', ['lumberyard', 0, 0]);
  await game.query('dev_place_building', ['clock_tower', 2, 2]);
  // Day 7 begins at 180 s of game time: a burst begins with it.
  await game.query('dev_advance_to', [7, 0.0]);
  await game.page.waitForTimeout(300);
  let hud = await game.query('hud');
  expect(hud.burst.visible).toBe(true);
  expect(hud.burst.active).toBe(true);
  // A Momo set to chop during the burst: half the time.
  await game.command({ type: 'momo.assign', momo: 1, building: yard });
  await game.query('dev_advance_ms', 4000);
  let s = await game.state();
  const b = s.buildings.buildings.find((x) => x.id === yard);
  expect(b.task_end - b.task_start).toBe(6000 * (await game.query('rules')).momo_x * 0.5);
  // School: skill points 1.2 per job.
  await game.query('dev_place_building', ['school', 1, 2]);
  const before = (await game.state()).momo.momos.find((m) => m.id === 1).experience.lumberyard ?? 0;
  await game.query('dev_advance_ms', 30000 * 6);
  s = await game.state();
  const after = s.momo.momos.find((m) => m.id === 1).experience.lumberyard ?? 0;
  expect(after - before).toBeGreaterThan(0);
  // Monument: the sale screen counts it.
  await game.query('dev_place_building', ['momo_monument', 2, 1]);
  await game.query('dev_level', 9);
  const sale = await game.query('sale');
  const a = sale.appraisal;
  expect(a.monument).toBe(Math.floor(a.points_base * 0.1 + 0.5));
  expect(a.points).toBe(a.points_base + a.monument);
});
