// Shared browser helpers for the Momonium web build.
import { decodePng, colorCount } from './png.mjs';

export const PAGES_URL = 'https://7bvcxz.github.io/gamo/momonium/';

export const PROFILES = {
  phone: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
  desktop: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1, isMobile: false, hasTouch: false },
};

// Opens the game and waits until the engine has actually drawn something.
// "Canvas exists" is not readiness: Godot creates its canvas long before the
// wasm arrives, so readiness is a canvas with more than a handful of colours.
export async function openGame(page, url, { timeoutMs = 120000, minColors = 12 } = {}) {
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push('console: ' + m.text());
  });
  const started = Date.now();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: timeoutMs });
  let colors = 0;
  while (Date.now() - started < timeoutMs) {
    const canvas = await page.$('canvas');
    if (canvas) {
      const status = await page.evaluate(() => {
        const el = document.querySelector('#status');
        return el ? getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden' : false;
      }).catch(() => true);
      if (!status) {
        colors = colorCount(decodePng(await canvas.screenshot()));
        if (colors >= minColors) break;
      }
    }
    await page.waitForTimeout(500);
  }
  return { readyMs: Date.now() - started, colors, errors };
}

export async function bridge(page) {
  return page.evaluate(() => (window.momonium ? { version: window.momonium.version, ready: window.momonium.ready } : null));
}
