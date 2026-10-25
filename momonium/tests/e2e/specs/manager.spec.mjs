// Step 28: on the demo island an office manager moves workers; a building's
// details set its priority by tap; a Momo's card shows its skill and lets
// the player pin it.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('manager, priorities and skill', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const hud = await game.query('hud');
  const gear = await centre(game, hud.buttons.settings, hud.window);
  await game.tap(gear.x, gear.y);
  await game.page.waitForTimeout(300);
  const st = await game.query('settings_ui');
  const demo = await centre(game, st.demo, st.window);
  await game.tap(demo.x, demo.y);
  await game.page.waitForFunction(() => window.momonium && window.momonium.call && window.momonium.call('settings_ui').in_demo === true, null, { timeout: 30_000 });
  await game.setTimeScale(0);
  await game.page.waitForTimeout(400);
  let s = await game.state();
  expect(s.manager.moves_made).toBeGreaterThan(0);
  const office = s.buildings.buildings.find((b) => b.type === 'office');
  expect(office).toBeTruthy();
  // The second mine (behind the tall apartment, so selected directly): open
  // its details from its name and set High -- by taps.
  await game.query('dev_select_cell', [3, 1]);
  await game.page.waitForTimeout(250);
  const p = await game.query('panels');
  const title = await centre(game, p.context_title, p.window);
  await game.tap(title.x, title.y);
  await game.page.waitForTimeout(300);
  const d = await game.query('details');
  expect(d.open).toBe(true);
  expect(d.priority).toBeTruthy();
  const high = await centre(game, d.priority.high, d.window);
  await game.tap(high.x, high.y);
  await game.page.waitForTimeout(200);
  s = await game.state();
  const mine = s.buildings.buildings.find((b) => b.type === 'mine' && b.anchor[0] === 3 && b.anchor[1] === 1);
  expect(mine.priority).toBe('high');
  const momo = s.momo.momos.find((m) => Object.keys(m.experience).length > 0);
  expect(momo).toBeTruthy();
});
