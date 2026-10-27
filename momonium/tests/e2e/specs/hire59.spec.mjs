// Step 59: Hire and the Premium Shop are two buttons. Hire stands at the
// right edge a little below the middle, carries the hiring dot, opens the
// hire card and pays in the game's money; the shopping bag at the
// bottom-left -- where Hire was -- opens the Premium Shop, which says
// 'Coming soon', sells nothing, never hires and never spends the game's
// money. On the phone at the 720x1280 portrait baseline and on the desktop.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, r, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (r[0] + r[2] / 2) * (box.width / win[0]), y: (r[1] + r[3] / 2) * (box.height / win[1]) };
};
const overlaps = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];

async function island(game) {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  let farm = 0;
  for (const c of [[1, 0], [0, 1], [1, 1]]) {
    farm = (await game.query('dev_place_building', ['farm', ...c])).id;
    if (farm) break;
  }
  await game.query('dev_add_money', 400);
  return farm;
}

for (const shape of ['default', '720x1280']) {
  test.describe(shape, () => {
    if (shape === '720x1280') test.use({ viewport: { width: 360, height: 640 } });

    test('Hire at the right: the dot, the card, the game\'s money', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await island(game);
      const h = await game.query('hud');
      const [w, ht] = h.window;
      if (shape === '720x1280') expect(h.window).toEqual([720, 1280]);
      const hire = h.buttons.hire;
      expect(hire[0] + hire[2], 'at the right edge').toBeGreaterThan(w - 0.12 * w);
      expect(hire[0] + hire[2]).toBeLessThanOrEqual(w);
      const cy = (hire[1] + hire[3] / 2) / ht;
      expect(cy, 'around the middle').toBeGreaterThan(0.4);
      expect(cy).toBeLessThan(0.62);
      expect(hire[1], 'below Research, Mailbox, Status').toBeGreaterThan(h.buttons.status[1] + h.buttons.status[3]);
      for (const [name, r] of Object.entries(h.buttons)) {
        if (name !== 'hire') expect(overlaps(hire, r), `clear of ${name}`).toBe(false);
      }
      for (const r of Object.values(h.pills)) expect(overlaps(hire, r)).toBe(false);
      await expect.poll(async () => (await game.query('hud')).badges, { timeout: 5_000 }).toContain('hire');
      expect((await game.query('hud')).badges, 'never a hiring dot on the Shop').not.toContain('shop');
      const before = await game.state();
      const price = (await game.query('rules')).hire_price;
      let p = await centre(game, hire, h.window);
      await game.tap(p.x, p.y);
      await game.page.waitForTimeout(300);
      const ui = await game.query('build_ui');
      expect(ui.menu_open, 'the hire card opens').toBe(true);
      expect(ui.cards.momo[0] + ui.cards.momo[2], 'beside Hire, to its left').toBeLessThanOrEqual(hire[0]);
      expect((await game.query('premium_shop')).open, 'not the Premium Shop').toBe(false);
      p = await centre(game, ui.cards.momo, ui.window);
      await game.tap(p.x, p.y);
      await game.page.waitForTimeout(300);
      const after = await game.state();
      expect(after.momo.momos.length, 'one Momo hired').toBe(before.momo.momos.length + 1);
      expect(after.economy.money, 'for the game\'s money').toBe(before.economy.money - price);
      expect(after.momo.momos.at(-1).assigned, 'idle until placed').toBe(0);
    });

    test('the old Hire corner opens the Premium Shop: Coming soon, nothing spent', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await island(game);
      const h = await game.query('hud');
      const [w, ht] = h.window;
      const shop = h.buttons.shop;
      expect(shop[0], 'bottom-left').toBeLessThan(0.3 * w);
      expect(shop[1] + shop[3]).toBeGreaterThan(0.85 * ht);
      expect(shop[0], 'beside Settings').toBeGreaterThan(h.buttons.settings[0]);
      const before = await game.state();
      let p = await centre(game, shop, h.window);
      await game.tap(p.x, p.y);
      await game.page.waitForTimeout(400);
      const s = await game.query('premium_shop');
      expect(s.open, 'the Premium Shop opens').toBe(true);
      expect(s.title).toBe('Shop');
      expect((await game.query('build_ui')).menu_open, 'not the hire card').toBe(false);
      const a = s.products.accelerator;
      expect(a.name).toBe('Accelerator');
      expect(a.steps).toEqual(['×2', '×4', '×8', '×16', '×32']);
      expect(a.buy_text).toBe('Coming soon');
      expect(a.buy_disabled).toBe(true);
      expect(a.price, 'no price without a storefront').toBe('');
      expect(s.storefront).toBe(false);
      expect(s.note.length, 'says purchases are not open').toBeGreaterThan(10);
      expect(s.restore_disabled).toBe(true);
      // Its Buy button, tapped anyway: nothing happens, nothing is spent.
      p = await centre(game, a.buy, s.window);
      await game.tap(p.x, p.y);
      await game.page.waitForTimeout(300);
      const after = await game.state();
      expect(after.economy.money, 'the game\'s money untouched').toBe(before.economy.money);
      expect(after.momo.momos.length, 'no Momo hired').toBe(before.momo.momos.length);
      expect((await game.query('premium_shop')).last, 'no purchase was even attempted').toEqual({});
      await game.page.screenshot({ path: info.outputPath('premium.png') });
      p = await centre(game, s.close, s.window);
      await game.tap(p.x, p.y);
      await expect.poll(async () => (await game.query('premium_shop')).open, { timeout: 3_000 }).toBe(false);
    });
  });
}
