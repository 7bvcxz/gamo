// Step 18: drag a Momo onto a farm (finger on phones, mouse on desktop) to
// assign it; drop in the sea and it refuses; hire a second Momo from the shop.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';
import { touchDrag } from '../lib/touch.mjs';

const toCss = async (game, p, win) => {
  const box = await game.canvas.boundingBox();
  return { x: p[0] * (box.width / win[0]), y: p[1] * (box.height / win[1]) };
};

async function drag(game, from, to, touch) {
  if (touch) return touchDrag(game.page, from, to, 12);
  const box = await game.canvas.boundingBox();
  await game.page.mouse.move(box.x + from.x, box.y + from.y);
  await game.page.mouse.down();
  await game.page.mouse.move(box.x + to.x, box.y + to.y, { steps: 12 });
  await game.page.mouse.up();
}

test('drag Momo onto the farm', async ({ game }, info) => {
  await game.setTimeScale(0);
  const { id: farm } = await game.query('dev_place_building', ['farm', 1, 0]);
  await game.page.waitForTimeout(200);
  let m = await game.query('momos');
  const from = await toCss(game, m.momos['1'].body, m.window);
  const to = await cellToCanvas(game, [1, 0]);
  await drag(game, from, to, info.project.use.hasTouch);
  await game.page.waitForTimeout(200);
  const s = await game.state();
  expect(s.momo.momos[0].assigned).toBe(farm);
});

test('the sea refuses a Momo', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.page.waitForTimeout(200);
  const before = (await game.state()).momo.momos[0];
  const m = await game.query('momos');
  const from = await toCss(game, m.momos['1'].body, m.window);
  const box = await game.canvas.boundingBox();
  await drag(game, from, { x: box.width * 0.06, y: box.height * 0.62 }, info.project.use.hasTouch);
  await game.page.waitForTimeout(200);
  expect((await game.query('momos')).drag.reason).toBe('err.not_owned');
  const after = (await game.state()).momo.momos[0];
  expect(after.to).toEqual(before.to);
});

test('hire a second Momo in the shop', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_add_money', 40);
  const price = (await game.query('rules')).hire_price;
  const hud = await game.query('hud');
  const shop = await toCss(game, [hud.buttons.shop[0] + hud.buttons.shop[2] / 2, hud.buttons.shop[1] + hud.buttons.shop[3] / 2], hud.window);
  await game.tap(shop.x, shop.y);
  await game.page.waitForTimeout(200);
  const ui = await game.query('build_ui');
  const c = ui.cards.momo;
  const card = await toCss(game, [c[0] + c[2] / 2, c[1] + c[3] / 2], ui.window);
  await game.tap(card.x, card.y);
  await game.page.waitForTimeout(200);
  const s = await game.state();
  expect(s.momo.momos.length).toBe(2);
  expect(s.economy.money).toBe(50 - price);
  expect((await game.query('momos')).selected).toBe('momo');
});
