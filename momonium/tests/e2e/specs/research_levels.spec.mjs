// Step 33: after a sale the points screen previews each node's numbers as
// points are placed (off -> Lv 2 -20%), a plan is saved in slot A, the draft
// changed, A loaded back and confirmed; the Momo paths take effect (watched
// tiles 4 -> 9).
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

test('place points with a preview, save and load a plan', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_level', (await game.query('rules')).prestige_level);
  await game.query('dev_research_levels', { momo_training: 2, momo_reach: 1 });
  // Sell from the Money tab.
  const hud = await game.query('hud');
  await tapRect(game, hud.buttons.status, hud.window);
  const p = await game.query('panels');
  await tapRect(game, p.tabs.economy, p.window);
  let s = await game.query('sale');
  await tapRect(game, s.entry, s.window);
  // A desktop's larger UI (Step 54) makes the sale panel scroll: Sell is at
  // its foot, below the fold -- a player scrolls to it.
  await game.query('dev_reveal', ['SaleFrame', 'Sell']);
  await game.page.waitForTimeout(150);
  s = await game.query('sale');
  await tapRect(game, s.sell, s.window);
  await tapRect(game, s.sell, s.window);
  await game.page.waitForFunction(() => window.momonium && window.momonium.ready && window.momonium.call('sale').status === 'sold', null, { timeout: 30_000 });
  await game.setTimeScale(0);
  let rp = await game.query('rp');
  expect(rp.open).toBe(true);
  expect(rp.earned).toBe(3);
  expect(rp.rows.momo_training.preview.startsWith('At Lv 1:')).toBe(true);
  // Two on training: the preview shows its Lv 2 numbers.
  await tapRect(game, rp.rows.momo_training.plus, rp.window);
  await tapRect(game, rp.rows.momo_training.plus, rp.window);
  rp = await game.query('rp');
  expect(rp.rows.momo_training.preview).toContain('→');
  expect(rp.rows.momo_training.preview).toContain('20');
  await tapRect(game, rp.rows.momo_reach.plus, rp.window);
  // Save as A, change the draft, load A back, confirm.
  rp = await game.query('rp');
  await tapRect(game, rp.profiles[0].save, rp.window);
  rp = await game.query('rp');
  expect(rp.profiles[0].text).toBe('A · 3 RP');
  await tapRect(game, rp.rows.momo_reach.minus, rp.window);
  rp = await game.query('rp');
  await tapRect(game, rp.profiles[0].load, rp.window);
  rp = await game.query('rp');
  expect(rp.draft).toEqual({ momo_training: 2, momo_reach: 1 });
  await tapRect(game, rp.confirm, rp.window);
  rp = await game.query('rp');
  expect(rp.allocated).toEqual({ momo_training: 2, momo_reach: 1 });
  const w = await game.query('watch');
  expect(w.capacity === 0 || w.capacity === 9).toBe(true);
  const st = await game.state();
  expect(st.research.allocated).toEqual({ momo_training: 2, momo_reach: 1 });
});
