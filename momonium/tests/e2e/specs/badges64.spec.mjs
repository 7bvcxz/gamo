// Step 64: numbers on the HUD's buttons. Three unread letters and two
// research topics not yet shown read 3 and 2, each on its own button; reading
// a letter takes the mailbox to 2 and leaves Research; opening Research
// clears its own and leaves the mailbox; a reload keeps them; a hundred or
// more reads 99+; the Premium Shop never has one. On the phone (also at the
// 720x1280 baseline) and the desktop, with real taps.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, r, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (r[0] + r[2] / 2) * (box.width / win[0]), y: (r[1] + r[3] / 2) * (box.height / win[1]) };
};
const overlap = (a, b) => Math.max(0, Math.min(a[0] + a[2], b[0] + b[2]) - Math.max(a[0], b[0])) * Math.max(0, Math.min(a[1] + a[3], b[1] + b[3]) - Math.max(a[1], b[1]));

for (const shape of ['default', '720x1280']) {
  test.describe(shape, () => {
    test.use({ starterMomo: true });
    if (shape === '720x1280') test.use({ viewport: { width: 360, height: 640 } });

    test('3 letters and 2 topics: their own numbers, taken off as they are seen', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await game.setTimeScale(0);
      await game.query('set_language', 'en');
      const news = await game.query('dev_news', [3, 2]);
      expect(news).toEqual({ unread: 3, topics: 2 });
      let h = await game.query('hud');
      expect(h.counts.mailbox).toBe(3);
      expect(h.counts.research).toBe(2);
      expect(h.badge_texts.mailbox).toBe('3');
      expect(h.badge_texts.research).toBe('2');
      expect(h.counts.shop, 'never on the Premium Shop').toBe(0);
      expect(h.names.mailbox).toBe('Mailbox, 3 unread');
      expect(h.names.research).toBe('Research, 2 new topics');
      // The capsules: on screen, off the icons, off each other.
      for (const name of ['mailbox', 'research']) {
        const r = h.badge_rects[name];
        expect(r[0]).toBeGreaterThanOrEqual(0);
        expect(r[0] + r[2]).toBeLessThanOrEqual(h.window[0]);
        const icon = h.icon_rects[name];
        expect(overlap(r, icon), `${name}: the icon stays seen`).toBeLessThanOrEqual(icon[2] * icon[3] * 0.12);
      }
      expect(overlap(h.badge_rects.mailbox, h.badge_rects.research)).toBe(0);
      await game.page.screenshot({ path: info.outputPath('3-and-2.png') });
      // Read one letter (real taps): the mailbox only.
      let p = await centre(game, h.buttons.mailbox, h.window);
      await game.tap(p.x, p.y);
      await game.page.waitForTimeout(350);
      const m = await game.query('mail');
      p = await centre(game, m.rows[0].rect, m.window);
      await game.tap(p.x, p.y);
      await game.page.waitForTimeout(350);
      h = await game.query('hud');
      expect(h.counts.mailbox, 'a letter read: 2').toBe(2);
      expect(h.counts.research, 'Research untouched').toBe(2);
      // Open Research: its own number goes, the mailbox's stays.
      p = await centre(game, h.buttons.research, h.window);
      await game.tap(p.x, p.y);
      await game.page.waitForTimeout(350);
      h = await game.query('hud');
      expect(h.counts.research, 'shown: gone').toBe(0);
      expect(h.counts.mailbox, 'the letters still unread').toBe(2);
      expect(h.badge_rects.research, 'nothing drawn at 0').toEqual([]);
    });
  });
}

test.describe('more', () => {
  test.use({ starterMomo: true });

  test('a reload keeps the numbers; 100 or more reads 99+', async ({ game }, info) => {
    await game.setTimeScale(0);
    await game.query('set_language', 'en');
    await game.query('dev_news', [4, 1]);
    await game.query('save_now');
    const page = await game.page.context().newPage();
    await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
    await page.goto('./');
    await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.call === 'function', null, { timeout: 90_000 });
    await page.waitForTimeout(500);
    const h = await page.evaluate(() => window.momonium.call('hud'));
    expect(h.counts.mailbox, 'after a reload: 4').toBe(4);
    expect(h.counts.research, 'and 1').toBe(1);
    for (const [n, text] of [[9, '9'], [10, '10'], [99, '99'], [100, '99+'], [123, '99+']]) {
      await page.evaluate((v) => window.momonium.call('dev_badge', ['mailbox', v]), n);
      const b = await page.evaluate(() => window.momonium.call('hud'));
      expect(b.badge_texts.mailbox).toBe(text);
    }
    await page.waitForTimeout(300);
    await page.screenshot({ path: info.outputPath('99plus.png') });
    await page.evaluate(() => window.momonium.call('dev_badge', ['mailbox', -1]));
    expect((await page.evaluate(() => window.momonium.call('hud'))).counts.mailbox, 'the real count back').toBe(4);
  });
});
