// Step 16: a harvest (not a tap) earns EXP and farm mastery -- since Step 42
// a little for each finished sowing and watering too -- and the Status
// button shows the exact numbers and bars.
import { test, expect } from '../lib/fixtures.mjs';

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
  for (const wait of [5000, 35000, 35000, 35000, 5000]) {
    await game.command({ type: 'building.tap', id });
    await game.query('dev_advance_ms', wait);
  }
  const s = await game.state();
  const rules = await game.query('rules');
  expect(s.progression.exp).toBe(rules.farm_cycle_exp);
  expect(s.progression.mastery.farm.exp).toBe(rules.farm_cycle_mastery);
  const hud = await game.query('hud');
  const btn = await centre(game, hud.buttons.status, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(200);
  const st = await game.query('status');
  expect(st.open).toBe(true);
  expect(st.level).toBe('1');
  expect(st.exp).toBe(`${rules.farm_cycle_exp} / 100 EXP`);
  expect(st.mastery.farm).toBe(`${rules.farm_cycle_mastery} / 100 EXP`);
  expect(st.mastery.mine).toBe('0 / 100 EXP');
});
