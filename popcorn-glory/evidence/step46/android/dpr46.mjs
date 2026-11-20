// Step 46: is the S23's 44-machine frame bound by the pixels it fills? The same factory at the
// phone's own device pixel ratio and at DPR 1 (CDP Emulation; the canvas then has ~1/7 the
// pixels): frames a second, window size, draw calls.
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const BASE = process.env.BASE;
const PLAN = JSON.parse(process.env.PLAN);
const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const rows = [];
for (const dpr of [0, 1]) {
  const page = await browser.contexts()[0].newPage();
  const cdp = await page.context().newCDPSession(page);
  if (dpr) {
    const vw = await page.evaluate(() => [window.innerWidth, window.innerHeight]);
    await cdp.send('Emulation.setDeviceMetricsOverride', { width: vw[0], height: vw[1], deviceScaleFactor: dpr, mobile: true });
  }
  const fps = (ms) => page.evaluate((d) => new Promise((done) => { let n = 0; const t = performance.now(); const tick = () => { n++; if (performance.now() - t < d) requestAnimationFrame(tick); else done(n * 1000 / (performance.now() - t)); }; requestAnimationFrame(tick); }), ms);
  const call = (n, a) => page.evaluate(([x, y]) => window.popcorn.call(x, y), [n, a]);
  await page.goto(BASE + 'about.html', { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
  await page.goto(BASE + '?dev=1#factory', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => window.popcorn && window.popcorn.ready, null, { timeout: 120_000 });
  await call('dev_money', 1e9);
  await call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
  for (let i = 0; i < 6; i++) await call('dev_advance', 5000);
  await page.waitForTimeout(3000);
  const f = await fps(8000);
  const info = await call('dev_render_info');
  const st = await page.evaluate(() => window.popcorn.state());
  const canvas = await page.evaluate(() => { const c = document.querySelector('canvas'); return [c.width, c.height, window.devicePixelRatio]; });
  rows.push({ dpr: dpr || 'device', canvas, window: st.window, fps: Math.round(f * 10) / 10, draw: info.draw_calls });
  console.log(JSON.stringify(rows[rows.length - 1]));
  await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
  if (dpr) await cdp.send('Emulation.clearDeviceMetricsOverride');
  await page.close();
}
await browser.close();
fs.writeFileSync(process.argv[2], JSON.stringify({ base: BASE, when: new Date().toISOString(), rows }, null, 2));
