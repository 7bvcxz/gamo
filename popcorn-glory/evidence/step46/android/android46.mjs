// Step 46: the public build on a real Android phone (S23, Chrome) over DevTools (adb forward).
// Load to the bridge's ready, then frames a second (rAF count) for 10 s at a fresh factory and
// at 44 working machines (built through the dev bridge, ?dev=1), render info, JS heap.
// Run: NODE_PATH=<tests/e2e/node_modules> node android46.mjs <out.json>
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const URL = 'https://7bvcxz.github.io/gamo/popcorn-glory/?dev=1#factory';
const PLAN = JSON.parse(process.env.PLAN);
const out = process.argv[2];
const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const ctx = browser.contexts()[0];
const page = await ctx.newPage();
const rec = { url: URL, device: 'Samsung S23 (SM-S911N), Chrome on Android, over DevTools', when: new Date().toISOString() };
const t0 = Date.now();
await page.goto(URL);
await page.waitForFunction(() => window.popcorn && window.popcorn.ready && typeof window.popcorn.state === 'function', null, { timeout: 120_000 });
rec.load_to_ready_ms = Date.now() - t0;
await page.waitForTimeout(3000);
const fps = (ms) => page.evaluate((d) => new Promise((done) => { let n = 0; const t = performance.now(); const tick = () => { n++; if (performance.now() - t < d) requestAnimationFrame(tick); else done(n * 1000 / (performance.now() - t)); }; requestAnimationFrame(tick); }), ms);
const call = (n, a) => page.evaluate(([x, y]) => window.popcorn.call(x, y), [n, a]);
const sample = async (label) => {
  const f = [];
  for (let i = 0; i < 10; i++) f.push(await fps(1000));
  f.sort((a, b) => a - b);
  const info = await call('dev_render_info');
  const st = await page.evaluate(() => window.popcorn.state());
  const heap = await page.evaluate(() => (performance.memory ? performance.memory.usedJSHeapSize : null));
  return { scene: label, machines: st.run.machines.length, window: st.window, fps: { min: f[0], p10: f[1], median: f[5], p90: f[8], all: f.map((v) => Math.round(v * 10) / 10) },
    draw_calls: info.draw_calls, objects: info.objects, nodes: info.nodes, heap_mb: heap ? Math.round(heap / 1e5) / 10 : null, version: st.version };
};
rec.rows = [await sample('fresh factory')];
await call('dev_money', 1e9);
const b = await call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
rec.build_ok = b.ok;
for (let i = 0; i < 6; i++) await call('dev_advance', 5000);
await page.waitForTimeout(3000);
rec.rows.push(await sample('44 machines'));
// Leave the phone as found: this game's save on the phone removed, the tab closed.
await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
await page.close();
await browser.close();
fs.writeFileSync(out, JSON.stringify(rec, null, 2));
console.log(JSON.stringify({ load: rec.load_to_ready_ms, rows: rec.rows.map((r) => [r.scene, r.machines, Math.round(r.fps.median), r.draw_calls, r.heap_mb]) }));
