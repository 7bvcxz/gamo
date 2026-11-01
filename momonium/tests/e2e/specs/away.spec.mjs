// Step 49: the welcome-back card in the real browser -- a saved island
// opened two hours later said what the island ran, once. Step 79 turned
// offline progress off: the same island, its save marked two hours old,
// opens exactly as it was saved -- nothing run, nothing earned, no card --
// and the next tab too (offline79.spec has the background tab and a clock
// moved on).
import { test, expect } from '../lib/fixtures.mjs';

// Step 53: about what a Momo does -- the old starter Momo, explicitly.
test.use({ starterMomo: true });

async function openTab(context) {
  const page = await context.newPage();
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
  const query = (name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]);
  await query('set_language', 'en');
  await page.evaluate(() => window.momonium.setTimeScale(0));
  return { page, query, state: () => page.evaluate(() => window.momonium.state()) };
}

test('two hours away: the island as it was saved, no card, nothing credited', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_add_money', 500);
  await game.command({ type: 'momo.hire' });
  const farm = (await game.query('dev_place_building', ['farm', 1, 0])).id;
  const yard = (await game.query('dev_place_building', ['lumberyard', 0, 1])).id;
  await game.command({ type: 'momo.assign', momo: 1, building: farm });
  await game.command({ type: 'momo.assign', momo: 2, building: yard });
  expect((await game.query('save_now')).err).toBe(0);
  const saved = await game.state();
  // The save says it was written two hours ago (the checksum covers the
  // island, not the time it was written).
  await game.page.evaluate(() => {
    const env = JSON.parse(localStorage.getItem('momonium_save'));
    env.saved_unix -= 7200;
    localStorage.setItem('momonium_save', JSON.stringify(env));
  });
  const context = game.page.context();
  await game.page.close();
  for (const tab of ['opened two hours later', 'opened again']) {
    const t = await openTab(context);
    const p = await t.query('persistence');
    expect(p.status, `${tab}: the save opened`).toBe('ok');
    expect(p.away_open, `${tab}: no welcome-back card`).toBe(false);
    expect(p.report, `${tab}: nothing caught up`).toEqual({});
    const s = await t.state();
    expect(s.now_ms - saved.now_ms, `${tab}: the clock where it was saved (only the frames seen)`).toBeLessThan(3000);
    expect(s.economy.money, `${tab}: no money for the time away`).toBe(saved.economy.money);
    expect(s.progression.exp, `${tab}: no EXP`).toBe(saved.progression.exp);
    expect(s.buildings.buildings.map((b) => b.completed), `${tab}: no jobs done`).toEqual(saved.buildings.buildings.map((b) => b.completed));
    await t.page.close();
  }
});
