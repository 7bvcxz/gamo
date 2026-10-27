// Step 50: the first minutes in the real build. A new player's island opens
// with a ripe crop and the tutorial ringing it -- the first tap is a harvest
// and its money within seconds; a full island with the next tile affordable
// shows that tile glowing with its price, unasked; a building nobody looks
// after and a hire affordable put a dot on Hire (Step 59: never on the Shop).
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

test.describe('a new player island', () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => { window.MOMONIUM_E2E_ISLAND = true; window.MOMONIUM_E2E_TUTORIAL = true; });
  });

  test('the first tap is a harvest and its money', async ({ game }) => {
    const s0 = await game.state();
    expect(s0.buildings.buildings.length, 'one farm waits').toBe(1);
    const farm = s0.buildings.buildings[0];
    expect(farm.stage, 'its crop ripe (the harvest is next)').toBe(2);
    const money0 = s0.economy.money;
    const p = await clearPointOnCell(game, farm.anchor);
    await game.tap(p.x, p.y);
    await expect.poll(async () => (await game.state()).economy.money, { timeout: 5_000 }).toBeGreaterThan(money0);
    const s1 = await game.state();
    expect(s1.inventory.items.crop ?? 0, 'sold as it was picked').toBe(0);
  });
});

test('a full island invites the next tile, and Hire shows a hire is worth it', async ({ game }) => {
  await game.setTimeScale(0);
  for (const [x, y] of [[0, 0], [1, 0], [0, 1], [1, 1]]) await game.query('dev_place_building', ['farm', x, y]);
  await game.query('dev_sale', 200);
  await expect.poll(async () => (await game.query('land_buy')).invite.length, { timeout: 5_000 }).toBe(2);
  const land = await game.query('land_buy');
  const s = await game.state();
  expect(s.world.land.some(([x, y]) => x === land.invite[0] && y === land.invite[1]), 'the invited tile is sea').toBe(false);
  await expect.poll(async () => (await game.query('hud')).badges, { timeout: 5_000 }).toContain('hire');
  expect((await game.query('hud')).badges, 'no hiring dot on the Premium Shop').not.toContain('shop');
});
