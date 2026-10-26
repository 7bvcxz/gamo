// Step 42: the island's journey (Status > Records). Each first -- the farm
// built, the first harvest and sale, a Momo's first job -- with the time
// played and the time since the island began, and time away counted apart:
// the island catches up on an absence and the journey says how long it was.
import { test, expect } from '../lib/fixtures.mjs';
import { runStages } from '../lib/farm.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('the journey of an island', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const rules = await game.query('rules');
  // A farm, worked by hand through one cycle.
  expect((await game.command({ type: 'building.place', building: 'farm', anchor: [0, 0] })).ok).toBe(true);
  await game.query('dev_advance_ms', 6000);
  const id = (await game.state()).buildings.buildings.find((b) => b.type === 'farm').id;
  await runStages(game, id, rules.farm_stages.length);
  await game.query('dev_advance_ms', 30000);
  let j = await game.query('journey');
  const keys = j.timeline.map((e) => e.key);
  expect(keys).toEqual(expect.arrayContaining(['built:farm', 'harvest', 'sale']));
  expect(j.totals.offline_ms).toBe(0);
  // Away for an hour: the island catches up, the journey counts it apart.
  await game.query('dev_away', 3600000);
  j = await game.query('journey');
  expect(j.totals.offline_ms).toBe(3600000);
  expect(j.totals.wall_ms - j.totals.played_ms).toBe(3600000);
  // Status > Records, by taps.
  const hud = await game.query('hud');
  const btn = await centre(game, hud.buttons.status, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(250);
  const p = await game.query('panels');
  const tab = await centre(game, p.tabs.records, p.window);
  await game.tap(tab.x, tab.y);
  await game.page.waitForTimeout(250);
  j = await game.query('journey');
  expect(j.shown).toBe(true);
  expect(j.head).toBe('Journey');
  expect(j.totals_text).toContain('away 1 h 0 min');
  expect(j.rows['built_farm'][0]).toBe('First Farm');
  expect(j.rows['harvest'][0]).toBe('First harvest');
  expect(j.rows['harvest'][1]).toContain('played');
  expect(j.rows['sale'][0]).toBe('First sale');
});
