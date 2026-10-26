// Step 49: the welcome-back card in the real browser -- a saved island
// opened two hours later says what the island ran (money, EXP, jobs and by
// how many Momo, the time away and the time counted), once: the next tab
// opens on the caught-up island, with no card and no second credit.
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
  return { page, query, state: () => page.evaluate(() => window.momonium.state()) };
}

test('two hours away: the card once, then never again', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_add_money', 500);
  await game.command({ type: 'momo.hire' });
  const farm = (await game.query('dev_place_building', ['farm', 1, 0])).id;
  const yard = (await game.query('dev_place_building', ['lumberyard', 0, 1])).id;
  await game.command({ type: 'momo.assign', momo: 1, building: farm });
  await game.command({ type: 'momo.assign', momo: 2, building: yard });
  expect((await game.query('save_now')).err).toBe(0);
  // The save says it was written two hours ago (the checksum covers the
  // island, not the time it was written).
  await game.page.evaluate(() => {
    const env = JSON.parse(localStorage.getItem('momonium_save'));
    env.saved_unix -= 7200;
    localStorage.setItem('momonium_save', JSON.stringify(env));
  });
  const context = game.page.context();
  await game.page.close();

  const second = await openTab(context);
  const p = await second.query('persistence');
  expect(p.away_open, 'the welcome-back card').toBe(true);
  const r = p.away_report;
  expect(Math.abs(r.away_ms - 7200000), `away ${r.away_ms} ms`).toBeLessThan(15000);
  expect(r.counted_ms).toBe(r.away_ms);
  expect(r.workers, 'both Momo worked').toBe(2);
  expect(r.income).toBeGreaterThan(0);
  expect(r.exp).toBeGreaterThan(0);
  expect(p.away_counted).toMatch(/^Away 2 h 0 min\. Momo kept the island going the whole time\.$/);
  expect(p.away_lines.some((l) => l.startsWith('Earned|+$')), 'money earned').toBe(true);
  expect(p.away_lines.some((l) => l.startsWith('Jobs done|') && l.endsWith('by 2 Momo')), 'jobs, and by whom').toBe(true);
  const caughtUp = await second.state();
  await second.page.close();

  const third = await openTab(context);
  const q = await third.query('persistence');
  expect(q.away_open, 'no second welcome back').toBe(false);
  const s = await third.state();
  expect(s.now_ms - caughtUp.now_ms, 'the two hours were not run again').toBeLessThan(20000);
  expect(s.economy.money, 'nor credited again').toBeLessThanOrEqual(caughtUp.economy.money + 50);
  await third.page.close();
});
