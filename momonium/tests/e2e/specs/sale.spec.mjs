// Step 15: a harvested batch waits in the store and is sold for $5 at the next
// day boundary; the HUD shows the store line before and the new money after.
// The clock is stopped and moved in exact steps so the test is deterministic.
import { test, expect } from '../lib/fixtures.mjs';

test('harvest today, $5 tomorrow', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const { id } = await game.query('dev_place_building', ['farm', 0, 0]);
  // sow, water, (30 s), water, (30 s), water, (30 s), harvest: 115 s, ends on Day 4.
  for (const wait of [5000, 35000, 35000, 35000, 5000]) {
    expect((await game.command({ type: 'building.tap', id })).ok).toBe(true);
    await game.query('dev_advance_ms', wait);
  }
  let s = await game.state();
  expect(s.inventory.items.crop).toBe(1);
  expect(s.economy.money).toBe(10);
  await game.page.waitForTimeout(150);
  expect((await game.query('hud')).money).toBe('10');
  await game.query('dev_advance_to', [s.day + 1, 0.0]);
  await game.page.waitForTimeout(200);
  s = await game.state();
  expect(s.economy.money).toBe(15);
  expect(s.inventory.items.crop ?? 0).toBe(0);
  expect((await game.query('hud')).money).toBe('15');
});
