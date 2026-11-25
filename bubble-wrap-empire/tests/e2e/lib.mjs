// Small Playwright helpers. Playwright itself is not vendored: point
// PLAYWRIGHT_DIR at a folder holding node_modules/playwright (default: the
// popcorn-glory worktree's install on this machine).
import { createRequire } from 'node:module';
import path from 'node:path';
const dir = process.env.PLAYWRIGHT_DIR || '/home/merti/Workspace/gamo-popcorn/popcorn-glory/tests/e2e';
const require = createRequire(path.join(dir, 'x.js'));
export const { chromium } = require('playwright');

export const BASE = process.env.BASE || 'http://localhost:8851/bubble-wrap-empire/';
export const STATE = '__bubble';

export async function open(browser, { w = 390, h = 844, touch = true, dpr = 2 } = {}) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr, hasTouch: touch, isMobile: touch });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await page.goto(BASE);
  await page.waitForFunction((k) => !!window[k], STATE, { timeout: 90000 });
  const cdp = await ctx.newCDPSession(page);
  return { ctx, page, cdp, errors };
}

export async function state(page) {
  return JSON.parse(await page.evaluate((k) => window[k], STATE));
}

export async function canvasBox(page) {
  return page.evaluate(() => { const r = document.querySelector('canvas').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
}

// normalized (0..1 of the game viewport) -> CSS pixels
export async function px(page, nx, ny) {
  const b = await canvasBox(page);
  return { x: b.x + nx * b.w, y: b.y + ny * b.h };
}

export async function rectCenter(page, name) {
  const s = await state(page);
  const r = s.rects[name];
  return px(page, r[0] + r[2] / 2, r[1] + r[3] / 2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export { sleep };

// one finger: down, a few moves, up. Real CDP touch events.
export async function swipe(cdp, from, to, ms = 160, steps = 6) {
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: from.x, y: from.y, id: 1 }] });
  for (let i = 1; i <= steps; i++) {
    await sleep(ms / steps);
    const t = i / steps;
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t, id: 1 }] });
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

export async function tap(cdp, p, hold = 60) {
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: p.x, y: p.y, id: 1 }] });
  await sleep(hold);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

export async function padSwipe(page, cdp, len = 0.5) {
  const s = await state(page);
  const r = s.rects.pad;
  const from = await px(page, r[0] + r[2] * 0.55, r[1] + r[3] * 0.8);
  const to = await px(page, r[0] + r[2] * 0.55, r[1] + r[3] * (0.8 - 0.6 * len));
  await swipe(cdp, from, to);
}
