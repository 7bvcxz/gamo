// Step 32: Status -> Money -> the island's worth -> Sell (two taps) -> a new
// island that opens on its research points: 3/1/1 researched becomes 5 RP,
// placed again as 1/2/2 with - and +, confirmed; the legacy shows on the next
// sale screen. Selling again without new research mints no RP.
import { test, expect } from '../lib/fixtures.mjs';

const toCss = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};
const tapRect = async (game, rect, win) => {
  const p = await toCss(game, rect, win);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(250);
};
const ready = async (game) => game.page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.call === 'function' && window.momonium.call('rp') && window.momonium.call('sale').status === 'sold', null, { timeout: 30_000 });

async function sellFromTheMoneyTab(game) {
  const hud = await game.query('hud');
  await tapRect(game, hud.buttons.status, hud.window);
  const p = await game.query('panels');
  await tapRect(game, p.tabs.economy, p.window);
  let s = await game.query('sale');
  expect(s.entry.length).toBe(4);
  await tapRect(game, s.entry, s.window);
  s = await game.query('sale');
  expect(s.open).toBe(true);
  expect(s.sell_disabled).toBe(false);
  await tapRect(game, s.sell, s.window);
  s = await game.query('sale');
  expect(s.confirming).toBe(true);
  await tapRect(game, s.sell, s.window);
  await ready(game);
  await game.setTimeScale(0);
}

test('sell, and place the research points again', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_level', 6);
  await game.query('dev_research_levels', { momo_training: 3, momo_reach: 1, momo_wide_reach: 1 });
  let s = await game.query('sale');
  expect(s.appraisal.rp_new).toBe(5);
  await sellFromTheMoneyTab(game);
  // The new island, on its research points.
  let rp = await game.query('rp');
  expect(rp.open).toBe(true);
  expect(rp.earned).toBe(5);
  expect(rp.unspent).toBe(5);
  expect(rp.head).toBe('Research points 5 / 5');
  const st = await game.state();
  expect(st.progression.level).toBe(1);
  expect(st.world.land.length).toBe(4);
  // 1 / 2 / 2 with real taps.
  const plan = { momo_training: 1, momo_reach: 2, momo_wide_reach: 2 };
  for (const [id, n] of Object.entries(plan)) {
    for (let i = 0; i < n; i++) {
      rp = await game.query('rp');
      await tapRect(game, rp.rows[id].plus, rp.window);
    }
  }
  rp = await game.query('rp');
  expect(rp.head).toBe('Research points 0 / 5');
  expect(rp.confirm_disabled).toBe(false);
  await tapRect(game, rp.confirm, rp.window);
  rp = await game.query('rp');
  expect(rp.allocated).toEqual(plan);
  expect(rp.open).toBe(false);
  s = await game.query('sale');
  expect(s.points).toBeGreaterThan(0);
  expect(s.welcome).toBe(false);
  // Selling again with no new research: still 5.
  await game.query('dev_level', 6);
  await sellFromTheMoneyTab(game);
  rp = await game.query('rp');
  expect(rp.earned).toBe(5);
  s = await game.query('sale');
  expect(s.sales).toBe(2);
});
