// Step 75: the Premium Shop (the bag at the bottom-left) shows two distinct
// products -- the Accelerator, bought up to five times, and Remove Ads, a
// one-time product -- and sells neither. Remove Ads reads 'Not available
// yet' and says the game has no ads; a tap on it charges nothing and changes
// nothing. On a first run, after a reload, on a small phone, at the largest
// UI size and in every language; and no ad network is ever asked for
// anything.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, r, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (r[0] + r[2] / 2) * (box.width / win[0]), y: (r[1] + r[3] / 2) * (box.height / win[1]) };
};
const inside = (a, b) => a[0] >= b[0] - 1 && a[1] >= b[1] - 1 && a[0] + a[2] <= b[0] + b[2] + 1 && a[1] + a[3] <= b[1] + b[3] + 1;

async function openShop(game) {
  const h = await game.query('hud');
  const p = await centre(game, h.buttons.shop, h.window);
  await game.tap(p.x, p.y);
  await expect.poll(async () => (await game.query('premium_shop')).open, { timeout: 3_000 }).toBe(true);
  return game.query('premium_shop');
}

// Both cards as shown, each scrolled into sight: inside the window and the
// panel, the Buy button inside its card.
async function checkCards(game) {
  const out = {};
  for (const id of ['accelerator', 'remove_ads']) {
    expect((await game.query('dev_reveal', ['ShopFrame', `Product_${id}`])).ok).toBe(true);
    await game.page.waitForTimeout(150);
    const s = await game.query('premium_shop');
    const p = s.products[id];
    expect(p.card.length, `${id} shown`).toBe(4);
    expect(p.card[0], `${id}: inside the window`).toBeGreaterThanOrEqual(0);
    expect(p.card[0] + p.card[2], `${id}: no sideways overflow`).toBeLessThanOrEqual(s.window[0] + 1);
    expect(inside(p.buy, p.card), `${id}: its button inside its card`).toBe(true);
    expect(inside(p.buy, p.scroll), `${id}: and in sight in the panel`).toBe(true);
    out[id] = p;
  }
  return out;
}

async function checkUnchanged(game, before, s) {
  const after = await game.state();
  expect(after.economy.money, "the game's money untouched").toBe(before.economy.money);
  expect(after.momo.momos.length, 'no Momo hired').toBe(before.momo.momos.length);
  expect(JSON.stringify(after.buildings), 'the island as it was').toBe(JSON.stringify(before.buildings));
  expect(s.last, 'no purchase was even attempted').toEqual({});
}

for (const shape of ['default', 'small']) {
  test.describe(shape, () => {
    if (shape === 'small') test.use({ viewport: { width: 320, height: 568 } });

    test('Remove Ads beside the Accelerator: not available yet, and a tap does nothing', async ({ game }, info) => {
      test.skip(shape === 'small' && !info.project.use.hasTouch, 'the small screen is a phone');
      await game.setTimeScale(0);
      await game.query('set_language', 'en');
      const before = await game.state();
      const s = await openShop(game);
      expect(Object.keys(s.products), 'two distinct products').toEqual(['accelerator', 'remove_ads']);
      expect(s.storefront).toBe(false);
      const a = s.products.accelerator;
      expect([a.name, a.buy_text, a.buy_disabled, a.icon, a.steps_shown]).toEqual(['Accelerator', 'Coming soon', true, 'ui_boost', true]);
      const r = s.products.remove_ads;
      expect(r.name).toBe('Remove Ads');
      expect(r.icon, 'its own icon').toBe('ui_no_ads');
      expect(r.desc, 'says there are no ads now').toMatch(/^There are no ads in the game\./);
      expect(r.desc, 'and that it is only planned').toContain('planned');
      expect(r.buy_text).toBe('Not available yet');
      expect(r.buy_disabled).toBe(true);
      expect(r.price, 'no price, no ₩0').toBe('');
      expect(r.owned, 'one-time').toBe('One-time purchase');
      expect(r.steps_shown, 'no steps to climb').toBe(false);
      expect(r.state.reason).toBe('store.not_yet');
      await game.page.screenshot({ path: info.outputPath(`shop-${shape}.png`) });
      const cards = await checkCards(game);
      // Remove Ads's button, tapped anyway (it is in sight now).
      const shown = await game.query('premium_shop');
      const p = await centre(game, cards.remove_ads.buy, shown.window);
      await game.tap(p.x, p.y);
      await game.page.waitForTimeout(300);
      const after = await game.query('premium_shop');
      expect(after.open, 'the shop stays open').toBe(true);
      await checkUnchanged(game, before, after);
      await game.page.screenshot({ path: info.outputPath(`shop-${shape}-remove-ads.png`) });
    });
  });
}

test('after a reload: the same two products, nothing owned', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await openShop(game);
  await game.query('save_now');
  const page2 = await game.page.context().newPage();
  await page2.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page2.goto('./');
  await page2.waitForFunction(() => window.momonium && window.momonium.ready, null, { timeout: 90_000 });
  await page2.waitForTimeout(500);
  await page2.evaluate(() => window.momonium.call('set_language', 'en'));
  const h = await page2.evaluate(() => window.momonium.call('hud'));
  const box = await page2.locator('canvas').boundingBox();
  const b = h.buttons.shop;
  const x = box.x + (b[0] + b[2] / 2) * (box.width / h.window[0]);
  const y = box.y + (b[1] + b[3] / 2) * (box.height / h.window[1]);
  if (test.info().project.use.hasTouch) await page2.touchscreen.tap(x, y); else await page2.mouse.click(x, y);
  await page2.waitForTimeout(400);
  const s = await page2.evaluate(() => window.momonium.call('premium_shop'));
  expect(s.open).toBe(true);
  expect(Object.keys(s.products)).toEqual(['accelerator', 'remove_ads']);
  expect(s.products.remove_ads.buy_text).toBe('Not available yet');
  expect(s.products.remove_ads.state.owned).toBe(0);
  expect(s.products.accelerator.state.owned).toBe(0);
  await page2.close();
});

test('the largest UI size: both cards still fit', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  expect((await game.query('dev_set_option', ['ui_scale', 1.25])).value).toBe(1.25);
  await game.page.waitForTimeout(300);
  await openShop(game);
  await checkCards(game);
  await game.page.screenshot({ path: info.outputPath('shop-ui125.png') });
  await game.query('dev_set_option', ['ui_scale', 1.0]);
});

test('in every language', async ({ game }, info) => {
  await game.setTimeScale(0);
  const want = {
    en: ['Remove Ads', 'Not available yet', 'One-time purchase', 'There are no ads'],
    ko: ['광고 제거', '아직 이용할 수 없어요', '한 번만 구매', '지금 게임에는 광고가 없어요'],
    ja: ['広告削除', 'まだ利用できません', '買い切り', '今のゲームに広告はありません'],
    zh_CN: ['移除广告', '暂不可用', '一次性购买', '目前游戏中没有广告'],
  };
  await openShop(game);
  for (const [lang, [name, buy, owned, desc]] of Object.entries(want)) {
    await game.query('set_language', lang);
    await game.page.waitForTimeout(200);
    const r = (await game.query('premium_shop')).products.remove_ads;
    expect([r.name, r.buy_text, r.owned], lang).toEqual([name, buy, owned]);
    expect(r.desc.startsWith(desc), `${lang}: ${r.desc}`).toBe(true);
    await checkCards(game);
    if (lang === 'ko') await game.page.screenshot({ path: info.outputPath('shop-ko.png') });
  }
  await game.query('set_language', 'en');
});

test('no ad network is asked for anything', async ({ page }) => {
  const urls = [];
  page.on('request', (r) => urls.push(r.url()));
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready, null, { timeout: 90_000 });
  await page.evaluate(() => window.momonium.call('set_language', 'en'));
  const h = await page.evaluate(() => window.momonium.call('hud'));
  const box = await page.locator('canvas').boundingBox();
  const b = h.buttons.shop;
  const x = box.x + (b[0] + b[2] / 2) * (box.width / h.window[0]);
  const y = box.y + (b[1] + b[3] / 2) * (box.height / h.window[1]);
  if (test.info().project.use.hasTouch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
  await page.waitForTimeout(1500);
  expect((await page.evaluate(() => window.momonium.call('premium_shop'))).open).toBe(true);
  const home = new URL(page.url()).host;
  const hosts = [...new Set(urls.filter((u) => /^https?:/.test(u)).map((u) => new URL(u).host))];
  console.log('HOSTS', hosts.join(' '), urls.length);
  for (const host of hosts) expect([home, 'raw.githubusercontent.com'], `only the game's own files (${host})`).toContain(host);
  for (const u of urls) expect(u, 'no ad URL').not.toMatch(/admob|doubleclick|googlesyndication|adservice|googletag|adsbygoogle|\/ads?\//i);
  const globals = await page.evaluate(() => ['adsbygoogle', 'googletag', 'admob'].filter((k) => k in window));
  expect(globals, 'no ad script on the page').toEqual([]);
});
