// The `game` fixture: a page with the E2E bridge switched on, opened and drawn.
import { test as base, expect } from '@playwright/test';
import { decodePng, colorCount } from './png.mjs';

export const test = base.extend({
  game: async ({ page }, use, testInfo) => {
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
    await page.goto('./');
    await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
    const canvas = page.locator('canvas');
    await expect.poll(async () => colorCount(decodePng(await canvas.screenshot())), { timeout: 30_000 }).toBeGreaterThan(8);
    const game = {
      page,
      canvas,
      errors,
      state: () => page.evaluate(() => window.momonium.state()),
      command: (c) => page.evaluate((cmd) => window.momonium.command(cmd), c),
      query: (name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]),
      setTimeScale: (x) => page.evaluate((v) => window.momonium.setTimeScale(v), x),
      version: () => page.evaluate(() => window.momonium.version),
      // Real input at a canvas-relative point (CSS pixels): touch on phones, mouse on desktop.
      tap: async (x, y) => {
        const box = await canvas.boundingBox();
        if (testInfo.project.use.hasTouch) await page.touchscreen.tap(box.x + x, box.y + y);
        else await page.mouse.click(box.x + x, box.y + y);
      },
    };
    await use(game);
    expect(errors, 'no page errors during the test').toEqual([]);
  },
});

export { expect };
