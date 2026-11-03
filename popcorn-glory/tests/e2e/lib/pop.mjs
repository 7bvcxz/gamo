// The `pop` fixture: a page with the game's test hooks on (window.POPCORN_E2E),
// a background tab faked the way a browser makes one (Playwright's Chromium
// never hides a page -- AGENTS.md 2026-11-01: visibilityState says hidden, a
// visibilitychange event, no animation frame until shown again), and real
// input: a finger on touch projects, the mouse on desktop.
import { test as base, expect } from '@playwright/test';
import { decodePng, colorCount } from './png.mjs';

export const INIT = () => {
  window.POPCORN_E2E = true;
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
  const pop = {
    page,
    canvas,
    errors: [],
    loadMs: 0,
    open: async (url = './') => {
      const t0 = Date.now();
      await page.goto(url);
      await pop.ready();
      pop.loadMs = Date.now() - t0;
    },
    // Ready = the bridge answers and the canvas shows more than one colour
    // (the canvas exists long before the game draws -- AGENTS.md 2026-08-08).
    ready: async () => {
      await page.waitForFunction(() => window.popcorn && window.popcorn.ready && typeof window.popcorn.state === 'function', null, { timeout: 90_000 });
      await expect.poll(async () => colorCount(decodePng(await canvas.screenshot())), { timeout: 30_000 }).toBeGreaterThan(8);
    },
    state: () => page.evaluate(() => window.popcorn.state()),
    call: (name, arg) => page.evaluate(([n, a]) => window.popcorn.call(n, a), [name, arg]),
    hash: () => page.evaluate(() => location.hash),
    tab: (h) => page.evaluate((v) => window.__tab(v), h),
    // Real input at a point in window pixels of the game.
    tapWin: async (x, y) => {
      const s = await pop.state();
      const box = await canvas.boundingBox();
      const k = box.width / s.window[0];
      const px = box.x + x * k;
      const py = box.y + y * k;
      if (testInfo.project.use.hasTouch) await page.touchscreen.tap(px, py);
      else await page.mouse.click(px, py);
    },
    // A rect [x, y, w, h] from state().rects, tapped in its centre.
    tap: async (name) => {
      const s = await pop.state();
      const r = s.rects[name];
      if (!r) throw new Error(`no rect ${name} on screen ${s.screen}`);
      await pop.tapWin(r[0] + r[2] / 2, r[1] + r[3] / 2);
    },
    // Press, keep holding `ms` real milliseconds, let go -- a finger through
    // CDP touch events on touch projects (touchscreen.tap() cannot hold;
    // AGENTS.md 2026-08-13), the mouse on desktop.
    hold: async (name, ms) => {
      const s = await pop.state();
      const r = s.rects[name];
      const box = await canvas.boundingBox();
      const k = box.width / s.window[0];
      const x = box.x + (r[0] + r[2] / 2) * k;
      const y = box.y + (r[1] + r[3] / 2) * k;
      if (testInfo.project.use.hasTouch) {
        const cdp = await pop.cdp();
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
        await page.waitForTimeout(ms);
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      } else {
        await page.mouse.move(x, y);
        await page.mouse.down();
        await page.waitForTimeout(ms);
        await page.mouse.up();
      }
    },
    // B: hold into the gold, a quarter of the way in. Real input latency only
    // ever adds to a hold (a loaded machine measured +100..+210 ms) and since
    // 0.9.1 the game counts it -- aiming at the middle landed past the gold.
    holdGold: async () => {
      const w = (await pop.state()).run.window;
      await pop.hold('play', Math.round(w[0] + (w[1] - w[0]) * 0.25));
    },
    _cdp: null,
    cdp: async () => {
      if (!pop._cdp) pop._cdp = await page.context().newCDPSession(page);
      return pop._cdp;
    },
    // Frames the page draws in `ms` real milliseconds, per second.
    fps: (ms = 2000) => page.evaluate((d) => new Promise((done) => {
      let n = 0;
      const t0 = performance.now();
      const tick = () => { n++; if (performance.now() - t0 < d) requestAnimationFrame(tick); else done((n * 1000) / (performance.now() - t0)); };
      requestAnimationFrame(tick);
    }), ms),
    shot: async (name) => {
      if (process.env.POPCORN_SHOTS) await page.screenshot({ path: `${process.env.POPCORN_SHOTS}/${name}_${testInfo.project.name}.png` });
    },
  };
  page.on('pageerror', (e) => pop.errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') pop.errors.push(m.text()); });
  return pop;
}

export const test = base.extend({
  pop: async ({ page }, use, testInfo) => {
    await page.addInitScript(INIT);
    const pop = wrap(page, testInfo);
    await use(pop);
    expect(pop.errors, 'no page errors during the test').toEqual([]);
  },
});

export { expect };
