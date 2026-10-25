// Step 36: a village that meets every City milestone -- the Status button
// gets a dot, the Status tab lists land / Momo / research / value with have
// and need, a tap promotes it with a celebration, and the build strip's
// Special now has two slots.
import { test, expect } from '../lib/fixtures.mjs';

const tapRect = async (game, r, win) => {
  const box = await game.canvas.boundingBox();
  await game.tap((r[0] + r[2] / 2) * (box.width / win[0]), (r[1] + r[3] / 2) * (box.height / win[1]));
  await game.page.waitForTimeout(250);
};

test('meet the milestones and become a City', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  let t = await game.query('tier');
  expect(t.tier).toBe('village');
  expect(t.slots).toBe(1);
  expect(t.badge).toBe(false);
  await game.query('dev_grow_island', 3);
  await game.query('dev_add_money', 400);
  await game.command({ type: 'momo.hire' });
  await game.command({ type: 'momo.hire' });
  await game.query('dev_research_levels', { momo_training: 3 });
  await game.query('dev_sale', 1500);
  await game.page.waitForTimeout(400);
  t = await game.query('tier');
  expect(t.progress.every((p) => p.met)).toBe(true);
  expect(t.badge).toBe(true);
  const hud = await game.query('hud');
  await tapRect(game, hud.buttons.status, hud.window);
  t = await game.query('tier');
  expect(t.head).toBe('Village · Special slots 1');
  expect(t.promote_disabled).toBe(false);
  await tapRect(game, t.promote, t.window);
  t = await game.query('tier');
  expect(t.tier).toBe('city');
  expect(t.celebrating).toBe(true);
  expect(t.celebration).toBe('Now a City');
  await game.page.waitForTimeout(2800);
  t = await game.query('tier');
  expect(t.slots).toBe(2);
  // Two specials may now stand at once.
  await game.query('dev_level', 6);
  await game.query('dev_add_money', 3000);
  await game.query('dev_add_items', { stone: 50, wood: 50, copper_ingot: 10 });
  expect((await game.command({ type: 'building.place', building: 'school', anchor: [0, 2] })).ok).toBe(true);
  expect((await game.command({ type: 'building.place', building: 'clock_tower', anchor: [1, 2] })).ok).toBe(true);
  expect((await game.command({ type: 'building.place', building: 'momo_monument', anchor: [2, 2] })).reason).toBe('err.special_slots');
  const st = await game.state();
  expect(st.tiers.tier).toBe(1);
});
