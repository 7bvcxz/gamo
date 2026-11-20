// Step 46: the S23 curve -- frames a second and the main thread's busy share (CDP
// Performance.getMetrics TaskDuration over 5 s) at 1, 12, 20 and 44 working machines.
// A main thread near 100% busy means the frame is CPU-bound (script, layout of the canvas);
// a free main thread with few frames means the GPU.
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const URL = 'https://7bvcxz.github.io/gamo/popcorn-glory/?dev=1#factory';
const PLAN = JSON.parse(process.env.PLAN);
const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const page = await browser.contexts()[0].newPage();
const cdp = await page.context().newCDPSession(page);
await cdp.send('Performance.enable');
const metrics = async () => Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((m) => [m.name, m.value]));
const fps = (ms) => page.evaluate((d) => new Promise((done) => { let n = 0; const t = performance.now(); const tick = () => { n++; if (performance.now() - t < d) requestAnimationFrame(tick); else done(n * 1000 / (performance.now() - t)); }; requestAnimationFrame(tick); }), ms);
const call = (n, a) => page.evaluate(([x, y]) => window.popcorn.call(x, y), [n, a]);
const rows = [];
for (const n of [1, 12, 20, 44]) {
  // A fresh factory each time: this game's keys cleared from a same-origin page first (the
  // runner rewrites the address without ?dev=1, so the game page is never reloaded).
  await page.goto('https://7bvcxz.github.io/gamo/popcorn-glory/about.html', { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
  await page.goto(URL, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => window.popcorn && window.popcorn.ready, null, { timeout: 120_000 });
  await call('dev_money', 1e9);
  await call('dev_build', { plan: PLAN.slice(0, n), sign: 8, packer: 3 });
  for (let i = 0; i < 6; i++) await call('dev_advance', 5000);
  await page.waitForTimeout(3000);
  const m0 = await metrics();
  const f = await fps(5000);
  const m1 = await metrics();
  const info = await call('dev_render_info');
  const span = m1.Timestamp - m0.Timestamp;
  rows.push({ machines: n, fps: Math.round(f * 10) / 10, main_busy: Math.round((m1.TaskDuration - m0.TaskDuration) / span * 100) / 100,
    script_share: Math.round((m1.ScriptDuration - m0.ScriptDuration) / span * 100) / 100, draw_calls: info.draw_calls, objects: info.objects, godot_fps: info.fps });
  console.log(JSON.stringify(rows[rows.length - 1]));
}
await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
await page.close();
await browser.close();
fs.writeFileSync(process.argv[2], JSON.stringify({ device: 'S23 Chrome 157, landscape (2115x840 game window)', when: new Date().toISOString(), rows }, null, 2));
