// Step 48: the release candidate on a real Android phone (S23, Chrome) over DevTools (adb forward).
// The published build: load to the bridge's ready; three real touch holds on a fresh factory (CDP
// touch on the phone's own page) and what the game judged; a reload keeps the factory (the save);
// network off after loading and a hold still pops and sells (offline play); then the 44-machine
// factory through the dev bridge (?dev=1) and its frames a second. Leaves the phone as found: this
// game's keys removed with its writes stubbed first (the unload save), the tab closed by id.
// Run (from tests/e2e, for @playwright/test): PLAN='<json>' node android48.mjs <out.json>
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const URL = 'https://7bvcxz.github.io/gamo/popcorn-glory/?dev=1#factory';
const PLAN = JSON.parse(process.env.PLAN);
const out = process.argv[2];
const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const ctx = browser.contexts()[0];
const page = await ctx.newPage();
const cdp = await ctx.newCDPSession(page);
const rec = { url: URL, device: 'Samsung S23 (SM-S911N), Chrome on Android, over DevTools', when: new Date().toISOString() };
const state = () => page.evaluate(() => window.popcorn.state());
const call = (n, a) => page.evaluate(([x, y]) => window.popcorn.call(x, y), [n, a]);
const fps = (ms) => page.evaluate((d) => new Promise((done) => { let n = 0; const t = performance.now(); const tick = () => { n++; if (performance.now() - t < d) requestAnimationFrame(tick); else done(n * 1000 / (performance.now() - t)); }; requestAnimationFrame(tick); }), ms);
async function hold() {
  let s = await state();
  for (let i = 0; i < 40 && (s.run.heating || Object.keys(s.run.glass).length || s.run.cooldown_left > 0); i++) { await page.waitForTimeout(250); s = await state(); }
  const r = s.rects.play;
  const vw = await page.evaluate(() => [innerWidth, innerHeight]);
  const k = vw[0] / s.window[0];
  const x = (r[0] + r[2] / 2) * k; const y = (r[1] + r[3] / 2) * k;
  const w = s.run.window;
  const ms = Math.round(w[0] + (w[1] - w[0]) * 0.3);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
  await page.waitForTimeout(ms);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await page.waitForTimeout(600);
  return { held_ms: ms, outcomes: (await state()).run.outcomes };
}
const t0 = Date.now();
await page.goto(URL);
await page.waitForFunction(() => window.popcorn && window.popcorn.ready && typeof window.popcorn.state === 'function', null, { timeout: 120_000 });
rec.load_to_ready_ms = Date.now() - t0;
await page.waitForTimeout(3000);
await call('dev_restart');
await page.waitForTimeout(1500);
let s = await state();
rec.version = s.version;
rec.window = s.window;
rec.fresh_fps = Math.round((await fps(3000)) * 10) / 10;
rec.holds = [];
for (let i = 0; i < 3; i++) rec.holds.push(await hold());
await page.waitForTimeout(6000);   // the save runs every 5 s
s = await state();
rec.before_reload = { money: s.run.money, sold: s.run.stats.sold, level: s.run.level };
await page.reload();
await page.waitForFunction(() => window.popcorn && window.popcorn.ready && typeof window.popcorn.state === 'function', null, { timeout: 120_000 });
await page.waitForTimeout(3000);
s = await state();
rec.after_reload = { money: s.run.money, sold: s.run.stats.sold, level: s.run.level };
// Offline after loading: the network goes away, the shop goes on.
await cdp.send('Network.enable');
await cdp.send('Network.emulateNetworkConditions', { offline: true, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
const sold0 = (await state()).run.stats.sold;
rec.offline_hold = await hold();
await page.waitForTimeout(12000);
rec.offline = { sold_before: sold0, sold_after: (await state()).run.stats.sold };
await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
// The 44-machine factory.
await call('dev_money', 1e9);
rec.build = await call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
for (let i = 0; i < 6; i++) await call('dev_advance', 5000);
await page.waitForTimeout(3000);
const f = [];
for (let i = 0; i < 10; i++) f.push(await fps(1000));
f.sort((a, b) => a - b);
const info = await call('dev_render_info');
rec.factory44 = { machines: (await state()).run.machines.length, fps: { min: f[0], p10: f[1], median: f[5], p90: f[8] }, draw_calls: info.draw_calls };
// Leave the phone as found.
await page.evaluate(() => {
  const real = Storage.prototype.setItem;
  Storage.prototype.setItem = function (k, v) { if (String(k).startsWith('popcorn-glory.')) return; return real.call(this, k, v); };
  for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k);
});
const targetId = (await cdp.send('Target.getTargetInfo')).targetInfo.targetId;
rec.target = targetId;
await browser.close();
fs.writeFileSync(out, JSON.stringify(rec, null, 2));
console.log(JSON.stringify(rec));
