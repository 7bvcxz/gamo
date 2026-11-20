// Step 46: where an S23 frame goes at 44 machines -- the dev render info's timers (Godot's
// process step; the app's model and flush; the factory view's sections) against the frame time.
// BASE: the build to open (a local export through adb reverse, or the public URL).
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const BASE = process.env.BASE;
const PLAN = JSON.parse(process.env.PLAN);
const N = (process.env.NS || '44').split(',').map(Number);
const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const page = await browser.contexts()[0].newPage();
const fps = (ms) => page.evaluate((d) => new Promise((done) => { let n = 0; const t = performance.now(); const tick = () => { n++; if (performance.now() - t < d) requestAnimationFrame(tick); else done(n * 1000 / (performance.now() - t)); }; requestAnimationFrame(tick); }), ms);
const call = (n, a) => page.evaluate(([x, y]) => window.popcorn.call(x, y), [n, a]);
const rows = [];
for (const n of N) {
  await page.goto(BASE + 'about.html', { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
  await page.goto(BASE + '?dev=1#factory', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => window.popcorn && window.popcorn.ready, null, { timeout: 120_000 });
  await call('dev_money', 1e9);
  await call('dev_build', { plan: PLAN.slice(0, n), sign: 8, packer: 3 });
  for (let i = 0; i < 6; i++) await call('dev_advance', 5000);
  await page.waitForTimeout(6000);   // the moving averages settle (0.95 a frame)
  const f = await fps(4000);
  const info = await call('dev_render_info');
  const row = { machines: n, fps: Math.round(f * 10) / 10, frame_ms: Math.round(1000 / f * 10) / 10, process_ms: info.process_ms,
    app: Object.fromEntries(Object.entries(info.app_prof || {}).map(([k, v]) => [k, Math.round(v * 100) / 100])),
    view: Object.fromEntries(Object.entries(info.view_prof || {}).map(([k, v]) => [k, Math.round(v * 100) / 100])),
    draw_calls: info.draw_calls, objects: info.objects, nodes: info.nodes };
  rows.push(row);
  console.log(JSON.stringify(row));
}
await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
await page.close();
await browser.close();
if (process.argv[2]) fs.writeFileSync(process.argv[2], JSON.stringify({ base: BASE, when: new Date().toISOString(), rows }, null, 2));
