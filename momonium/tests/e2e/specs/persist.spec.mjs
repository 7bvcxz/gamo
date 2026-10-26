// Step 24: the island is saved to the browser's storage and opens again in a
// new tab of the same browser -- farm, Momo at work, money -- and the time away
// is caught up with a welcome-back card. (A new page, not page.reload(): the
// Godot frame detaches on reload and the read races it.)
import { test, expect } from '../lib/fixtures.mjs';

// Step 53: about what a Momo does -- the old starter Momo, explicitly.
test.use({ starterMomo: true });

async function openSecond(context) {
  const page = await context.newPage();
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
  return {
    page,
    state: () => page.evaluate(() => window.momonium.state()),
    query: (name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]),
  };
}

test('the island comes back in a new tab', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_add_money', 500);
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  await game.command({ type: 'momo.assign', momo: 1, building: id });
  await game.query('dev_advance_ms', 30000);
  const before = await game.state();
  const saved = await game.query('save_now');
  expect(saved.err).toBe(0);
  expect(saved.persist).toBe(true);
  expect(saved.userfs_persistent).toBe(true);
  // Closed at once: IndexedDB may not have caught up, the localStorage mirror has.
  await game.page.close();
  const again = await openSecond(game.page.context());
  const p = await again.query('persistence');
  expect(p.status).toBe('ok');
  const after = await again.state();
  expect(after.economy.money).toBeGreaterThanOrEqual(before.economy.money);
  expect(after.buildings.buildings.map((b) => b.type)).toEqual(['farm']);
  expect(after.momo.momos[0].assigned).toBe(id);
  expect(after.now_ms).toBeGreaterThanOrEqual(before.now_ms);
  // An hour away: the card says what happened.
  await again.page.evaluate(() => window.momonium.setTimeScale(0));
  const r = await again.query('dev_away', 3600000);
  expect(r.counted_ms).toBe(3600000);
  expect(r.crops).toBeGreaterThan(0);
  const q = await again.query('persistence');
  expect(q.away_open).toBe(true);
  expect(q.away_lines[0]).toBe('Away|1 h 0 min');
  await again.page.close();
});
