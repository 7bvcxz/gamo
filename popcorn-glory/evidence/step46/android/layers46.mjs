// Step 46: each play-view layer's share of an S23 frame at 44 machines -- hidden one at a time
// (a hidden canvas item is neither drawn nor rendered): frames a second and draw calls.
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const BASE = process.env.BASE;
const PLAN = JSON.parse(process.env.PLAN);
const LAYERS = ['machine_layer', 'actor_layer', 'goods_layer', 'floor_layer', 'detail_layer', 'customer_node', 'belt_layer', 'light_layer', 'news_node', 'status_node', 'cue_node', 'spoon_layer', 'stats_node', 'under_layer', 'over_layer', 'machine_node'];
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
const measure = async () => { const f = await fps(3000); const i = await call('dev_render_info'); return { fps: Math.round(f * 10) / 10, draw: i.draw_calls, objects: i.objects }; };
const rows = [{ hidden: '(none)', ...(await measure()) }];
for (const l of LAYERS) {
  const r = await call('dev_hide', { name: l, hidden: true });
  if (!r.ok) { rows.push({ hidden: l, error: r.error }); continue; }
  await page.waitForTimeout(500);
  rows.push({ hidden: l, ...(await measure()) });
  await call('dev_hide', { name: l, hidden: false });
}
rows.push({ hidden: '(none, again)', ...(await measure()) });
for (const r of rows) console.log(JSON.stringify(r));
await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
await page.close();
await browser.close();
fs.writeFileSync(process.argv[2], JSON.stringify({ base: BASE, when: new Date().toISOString(), rows }, null, 2));
