// Step 20: the panels -- Status opens from its corner button, its tabs are
// tapped with a finger (or clicked), the money tab shows the ledger, a tap
// outside closes it; a building's name opens its details, ✕ closes them.
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('status tabs and the money ledger', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_add_money', 100);
  const hud = await game.query('hud');
  const btn = await centre(game, hud.buttons.status, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(250);
  let p = await game.query('panels');
  expect(p.status_open).toBe(true);
  expect(p.tab).toBe('status');
  const money = await centre(game, p.tabs.economy, p.window);
  await game.tap(money.x, money.y);
  await game.page.waitForTimeout(250);
  p = await game.query('panels');
  expect(p.tab).toBe('economy');
  const s = await game.state();
  expect(p.money).toBe('$' + s.economy.money);
  expect(p.today.dev).toBe('+$100');
  const store = await centre(game, p.tabs.store, p.window);
  await game.tap(store.x, store.y);
  await game.page.waitForTimeout(250);
  p = await game.query('panels');
  expect(p.store.crop).toBe('0 / 20');
  // A tap on the island below the card puts the panel away.
  const box = await game.canvas.boundingBox();
  const below = { x: (p.card[0] + 30) * (box.width / p.window[0]), y: (p.card[1] + p.card[3] + 40) * (box.height / p.window[1]) };
  await game.tap(below.x, below.y);
  await game.page.waitForTimeout(250);
  expect((await game.query('panels')).status_open).toBe(false);
});

test('a building name opens its details', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_place_building', ['farm', 1, 0]);
  await game.page.waitForTimeout(200);
  const f = await clearPointOnCell(game, [1, 0]);
  await game.tap(f.x, f.y);
  await game.page.waitForTimeout(250);
  let p = await game.query('panels');
  expect(p.context_title.length).toBe(4);
  const t = await centre(game, p.context_title, p.window);
  await game.tap(t.x, t.y);
  await game.page.waitForTimeout(250);
  p = await game.query('panels');
  expect(p.detail_open).toBe(true);
  expect(p.detail_title).toBe('Farm');
  // A cycle: five 5 s stages and three waits -- by hand, and at Momo pace.
  const rules = await game.query('rules');
  const fmt = (sec) => (sec < 60 ? `${sec} s` : sec % 60 === 0 ? `${sec / 60} min` : `${Math.floor(sec / 60)} min ${sec % 60} s`);
  expect(p.detail.you).toBe(fmt(25 + (3 * rules.farm_wait_ms) / 1000));
  expect(p.detail.momo).toBe(fmt(Math.round(25 * rules.momo_x + (3 * rules.farm_wait_ms) / 1000)));
  // The tap that selected the farm also sowed it: you work, the Momo spot is empty.
  expect(p.detail.workers).toEqual(['you', 'empty']);
  expect(p.detail.state).toMatch(/^Sow · \d s left$/);
  const close = await centre(game, p.close, p.window);
  await game.tap(close.x, close.y);
  await game.page.waitForTimeout(250);
  expect((await game.query('panels')).detail_open).toBe(false);
});
