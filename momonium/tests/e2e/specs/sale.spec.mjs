// Step 15, Step 50: a harvested batch is sold the moment it is picked -- the
// money and the HUD change at once -- and the next dawn pays nothing more (no
// sale is ever paid twice). The clock is stopped and moved in exact steps so
// the test is deterministic.
import { test, expect } from '../lib/fixtures.mjs';

test('the harvest is money at once, and dawn pays nothing more', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const { id } = await game.query('dev_place_building', ['farm', 0, 0]);
  const money0 = (await game.state()).economy.money;
  for (let stage = 0; stage < 3; stage++) {
    let s = await game.state();
    let f = s.buildings.buildings.find((x) => x.id === id);
    if (f.state === 'cooldown') await game.query('dev_advance_ms', f.ready_at - s.now_ms + 5);
    expect((await game.command({ type: 'building.tap', id })).ok).toBe(true);
    s = await game.state();
    f = s.buildings.buildings.find((x) => x.id === id);
    await game.query('dev_advance_ms', f.task_end - s.now_ms + 5);
  }
  let s = await game.state();
  const paid = s.economy.money - money0;
  expect(paid, 'paid as it was picked').toBeGreaterThan(0);
  expect(s.inventory.items.crop ?? 0).toBe(0);
  await expect.poll(async () => (await game.query('hud')).money, { timeout: 5_000 }).toBe(String(s.economy.money));
  await game.query('dev_advance_to', [s.day + 1, 0.0]);
  await game.page.waitForTimeout(200);
  expect((await game.state()).economy.money, 'dawn sells nothing').toBe(money0 + paid);
});
