// Step 16: a harvest (not a tap) earns EXP and farm mastery -- since Step 42
// a little for each finished sowing and watering too -- and the Status
// button shows the exact numbers and bars.
import { test, expect } from '../lib/fixtures.mjs';
import { runStages } from '../lib/farm.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('a harvest shows up in Status', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const { id } = await game.query('dev_place_building', ['farm', 0, 0]);
  for (let i = 0; i < 10; i++) await game.command({ type: 'building.tap', id });
  expect((await game.state()).progression.exp).toBe(0);
  const rules = await game.query('rules');
  // The first tap began the sowing: it finishes, then the rest of the cycle.
  await runStages(game, id, rules.farm_stages.length - 1);
  const s = await game.state();
  expect(s.progression.exp).toBe(rules.farm_cycle_exp);
  expect(s.progression.mastery.farm.exp).toBe(rules.farm_cycle_mastery);
  const hud = await game.query('hud');
  const btn = await centre(game, hud.buttons.status, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(200);
  const st = await game.query('status');
  expect(st.open).toBe(true);
  expect(st.level).toBe('1');
  expect(st.exp).toMatch(new RegExp(`^${rules.farm_cycle_exp} / \\d+ EXP$`));
  expect(st.mastery.farm).toBe(`${rules.farm_cycle_mastery} / 100 EXP`);
  expect(st.mastery.mine).toBe('0 / 100 EXP');
});
