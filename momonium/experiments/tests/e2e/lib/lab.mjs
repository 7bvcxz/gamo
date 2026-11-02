// The `lab` fixture: a page with the Lab's test hooks on (window.FUNLAB_E2E),
// a background tab it can fake the way a browser makes one (Playwright's
// Chromium never hides a page: document.visibilityState says hidden, a
// visibilitychange event, no animation frame until it is shown again -- the
// game's offline79 spec found and wrote this), and real input: a finger on
// touch projects, the mouse on desktop.
import { test as base, expect } from '@playwright/test';
import { decodePng, colorCount } from '../../../../tests/e2e/lib/png.mjs';

export const INIT = () => {
  window.FUNLAB_E2E = true;
  let hidden = false;
  const waiting = [];
  const raf = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = (cb) => {
    if (hidden) { waiting.push(cb); return 0; }
    return raf(cb);
  };
  Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => (hidden ? 'hidden' : 'visible') });
  Object.defineProperty(document, 'hidden', { configurable: true, get: () => hidden });
  window.__tab = (h) => {
    hidden = h;
    document.dispatchEvent(new Event('visibilitychange'));
    if (!h) for (const cb of waiting.splice(0)) raf(cb);
  };
};

export function wrap(page, testInfo) {
  const canvas = page.locator('canvas');
  const lab = {
    page,
    canvas,
    errors: [],
    open: async (url = './') => {
      await page.goto(url);
      await lab.ready();
    },
    ready: async () => {
      await page.waitForFunction(() => window.funlab && window.funlab.ready && typeof window.funlab.state === 'function', null, { timeout: 90_000 });
      await expect.poll(async () => colorCount(decodePng(await canvas.screenshot())), { timeout: 30_000 }).toBeGreaterThan(8);
    },
    state: () => page.evaluate(() => window.funlab.state()),
    call: (name, arg) => page.evaluate(([n, a]) => window.funlab.call(n, a), [name, arg]),
    hash: () => page.evaluate(() => location.hash),
    tab: (h) => page.evaluate((v) => window.__tab(v), h),
    blur: () => page.evaluate(() => window.dispatchEvent(new Event('blur'))),
    focus: () => page.evaluate(() => window.dispatchEvent(new Event('focus'))),
    // Real input at a canvas point (CSS pixels from the canvas' corner).
    tapCss: async (x, y) => {
      const box = await canvas.boundingBox();
      if (testInfo.project.use.hasTouch) await page.touchscreen.tap(box.x + x, box.y + y);
      else await page.mouse.click(box.x + x, box.y + y);
      await page.waitForTimeout(200);
    },
    // A rect [x, y, w, h] in the Lab's canvas pixels, tapped in its centre.
    tapRect: async (r) => {
      const s = await lab.state();
      const box = await canvas.boundingBox();
      const k = box.width / s.window[0];
      await lab.tapCss((r[0] + r[2] / 2) * k, (r[1] + r[3] / 2) * k);
    },
    shot: async (name) => {
      if (process.env.FUNLAB_SHOTS) await page.screenshot({ path: `${process.env.FUNLAB_SHOTS}/${name}_${testInfo.project.name}.png` });
    },
  };
  page.on('pageerror', (e) => lab.errors.push(e.message));
  return lab;
}

export const test = base.extend({
  lab: async ({ page }, use, testInfo) => {
    await page.addInitScript(INIT);
    const lab = wrap(page, testInfo);
    await use(lab);
    expect(lab.errors, 'no page errors during the test').toEqual([]);
  },
});

export { expect };
