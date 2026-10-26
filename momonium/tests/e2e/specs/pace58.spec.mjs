// Step 58: in the real web build the work takes 2.5 times its data seconds and
// a Momo walks 1.3 times as long: the rules say so, a real tap's stage runs
// for the scaled time on the game clock, the job cards say the time it
// really takes, and a Momo crossing tiles takes the longer walk.
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

test('work x2.5 and walking x1.3, as played', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const rules = await game.query('rules');
  expect(rules.work_scale).toBeCloseTo(2.5, 3);
  expect(rules.travel_scale).toBeCloseTo(1.3, 3);
  expect(rules.farm_stages.map((s) => s[1]), 'sow, water, harvest: 2.5 s of work each').toEqual([2500, 2500, 2500]);
  expect(rules.farm_stages[1][2], 'the wait after watering is unchanged').toBe(2000);
  // A farm, and a real tap: the sowing takes 2.5 s on the game clock.
  const farm = { id: (await game.query('dev_place_building', ['farm', 1, 0])).id, anchor: [1, 0] };
  expect(farm.id).toBeGreaterThan(0);
  await game.page.waitForTimeout(200);
  const p = await clearPointOnCell(game, farm.anchor);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(300);
  let s = await game.state();
  const b = s.buildings.buildings.find((x) => x.id === farm.id);
  expect(b.state).toBe('working');
  expect(b.task_end - b.task_start, 'a sowing by hand: 2.5 s').toBe(2500);
  const sel = await game.query('selection');
  expect(sel.card_times.length).toBe(3);
  for (const t of sel.card_times) expect(t, 'each card says what it takes').toMatch(/^2\.5 ?(sec|s)/);
  // A Momo sent to the farm walks there at 1.3 times the walking time.
  const { id } = await game.query('dev_add_momo', [0.2, 0.2]);
  await game.command({ type: 'momo.assign', momo: id, building: farm.id });
  s = await game.state();
  const m = s.momo.momos.find((x) => x.id === id);
  const dist = Math.hypot(m.to[0] - m.from[0], m.to[1] - m.from[1]);
  expect(dist, 'it has a walk to make').toBeGreaterThan(0.5);
  expect(m.end - m.start, `${dist.toFixed(2)} tiles at ${(rules.walk_speed / 1.3).toFixed(3)} tiles/s`).toBe(Math.round((dist / (rules.walk_speed / rules.travel_scale)) * 1000));
});
