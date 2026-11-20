// Step 46: the customers' baked textures at 44 machines on the S23 -- how many are made in
// 10 s, how many SubViewports live, and the frames a second with baking on and off.
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const BASE = process.env.BASE;
const PLAN = JSON.parse(process.env.PLAN);
const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const page = await browser.contexts()[0].newPage();
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
const rows = [];
for (const [on, free] of [[true, false], [false, true], [true, false]]) {
  await call('dev_bake', { actors: on, free });
  await page.waitForTimeout(1500);
  const a = await call('dev_render_info');
  const f = await fps(10000);
  const b = await call('dev_render_info');
  rows.push({ actor_bakes: on, freed: free, fps: Math.round(f * 10) / 10, bakes_made_10s: b.actor_bakes_made - a.actor_bakes_made, bakes_live: b.actor_bakes_live, viewports: b.viewports, draw: b.draw_calls, objects: b.objects });
  console.log(JSON.stringify(rows[rows.length - 1]));
}
await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
await page.close();
await browser.close();
fs.writeFileSync(process.argv[2], JSON.stringify({ base: BASE, when: new Date().toISOString(), rows }, null, 2));
