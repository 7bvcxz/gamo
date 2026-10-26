// Step 53: a fresh island has no Momo. The player harvests by hand (paid at
// once), hires the first Momo from the shop with real taps, and it stands
// idle -- however long the island runs -- until the player drags it onto a
// farm. The choice is still there in a new tab of the same browser.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas, clearPointOnCell } from '../lib/coords.mjs';
import { touchDrag } from '../lib/touch.mjs';

const toCss = async (game, r, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (r[0] + (r[2] ?? 0) / 2) * (box.width / win[0]), y: (r[1] + (r[3] ?? 0) / 2) * (box.height / win[1]) };
};

async function drag(game, from, to, touch) {
  if (touch) return touchDrag(game.page, from, to, 12);
  const box = await game.canvas.boundingBox();
  await game.page.mouse.move(box.x + from.x, box.y + from.y);
  await game.page.mouse.down();
  await game.page.mouse.move(box.x + to.x, box.y + to.y, { steps: 12 });
  await game.page.mouse.up();
}

test('alone first, then the first Momo is the player\'s to hire and place', async ({ game }, info) => {
  await game.setTimeScale(0);
  let s = await game.state();
  expect(s.momo.momos.length, 'nobody but the player').toBe(0);
  // A farm worked by hand -- sow, water, harvest by real taps: money at once.
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  const farm = { id, anchor: [1, 0] };
  const money0 = s.economy.money;
  const p = await clearPointOnCell(game, farm.anchor);
  for (let i = 0; i < 3; i++) {
    await game.tap(p.x, p.y);
    for (let k = 0; k < 4; k++) {
      const b = (await game.state()).buildings.buildings.find((x) => x.id === id);
      if (b.state === 'idle') break;
      const now = (await game.state()).now_ms;
      await game.query('dev_advance_ms', Math.max((b.state === 'working' ? b.task_end : b.ready_at) - now, 0) + 5);
    }
  }
  s = await game.state();
  expect(s.economy.money, 'the harvest pays, with no Momo').toBeGreaterThan(money0);
  // The first hire, from the shop.
  const price = (await game.query('rules')).hire_price;
  expect(price, 'the first Momo has its own small price').toBe(15);
  if (s.economy.money < price) await game.query('dev_add_money', price - s.economy.money);
  const hud = await game.query('hud');
  const shop = await toCss(game, hud.buttons.shop, hud.window);
  await game.tap(shop.x, shop.y);
  await game.page.waitForTimeout(250);
  const ui = await game.query('build_ui');
  const card = await toCss(game, ui.cards.momo, ui.window);
  await game.tap(card.x, card.y);
  await game.page.waitForTimeout(250);
  s = await game.state();
  expect(s.momo.momos.length, 'the first Momo').toBe(1);
  expect(s.momo.momos[0].assigned, 'not put to work').toBe(0);
  expect(s.momo.momos[0].watch, 'nor given tiles').toEqual([]);
  // Two minutes of the island running: still the player's to place.
  await game.query('dev_advance_ms', 120000);
  s = await game.state();
  expect(s.momo.momos[0].assigned, 'it waited').toBe(0);
  expect(s.momo.momos[0].watch).toEqual([]);
  // The player drags it onto the farm.
  await game.query('dev_advance_ms', 1);
  const m = await game.query('momos');
  const from = await toCss(game, m.momos['1'].body, m.window);
  const to = await cellToCanvas(game, farm.anchor);
  await drag(game, from, to, info.project.use.hasTouch);
  await game.page.waitForTimeout(250);
  s = await game.state();
  expect(s.momo.momos[0].assigned, 'placed by the player').toBe(farm.id);
  expect(s.momo.momos[0].opted_in).toBe(true);
  // A new tab of the same browser: the same Momo where the player put it.
  expect((await game.query('save_now')).err).toBe(0);
  const context = game.page.context();
  await game.page.close();
  const page = await context.newPage();
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
  const again = await page.evaluate(() => window.momonium.state());
  expect(again.momo.momos.length).toBe(1);
  expect(again.momo.momos[0].assigned, 'its place kept').toBe(farm.id);
  await page.close();
});
