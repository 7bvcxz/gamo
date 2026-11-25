// A long session in a phone-sized browser with real touch events and the game's own metrics.
//   node session.mjs <low|spam> <seconds> <outdir>
//   low  : one gentle swipe each time the ball has stopped, upgrades only when affordable
//   spam : quick touches on the pad as fast as the automation can send them (about 10 per second),
//          upgrades checked once a second
// This is automation, not a person: it says nothing about fun, comfort or fatigue.
import { chromium, open, state, padSwipe, rectCenter, tap, px, sleep } from './lib.mjs';
import fs from 'node:fs';
import os from 'node:os';
const policy = process.argv[2] || 'low';
const secs = Number(process.argv[3] || 180);
const out = process.argv[4] || `/tmp/claude-1000/snow-session-${policy}`;
fs.mkdirSync(out, { recursive: true });
const marks = [10, 30, 60, 180, 300, 600].filter((m) => m <= secs);
const browser = await chromium.launch();
const { page, cdp, errors } = await open(browser, { w: 390, h: 844 });
const env = await page.evaluate(() => ({ ua: navigator.userAgent, dpr: window.devicePixelRatio, w: innerWidth, h: innerHeight, cores: navigator.hardwareConcurrency, mem: navigator.deviceMemory ?? null }));
env.loadAvgStart = os.loadavg()[0];
const fps = () => page.evaluate(() => new Promise((res) => { let n = 0; const t0 = performance.now(); (function f() { n++; const d = performance.now() - t0; if (d > 2000) res(n / (d / 1000)); else requestAnimationFrame(f); })(); }));
const heap = () => page.evaluate(() => (performance.memory ? performance.memory.usedJSHeapSize / 1e6 : null));
const t0 = Date.now();
const el = () => (Date.now() - t0) / 1000;
const T = { firstSnow: null, firstBuy: null, radius2: null, rollGe10: null };
const rows = [];
const perf = { fps: [], heapMB: [await heap()] };
let mi = 0, lastSample = 0, lastBuyCheck = 0, k = 0, fpsAt = [20, 300].filter((x) => x < secs), fi = 0;

async function buyAffordable(s) {
  for (const i of [0, 1, 2, 3, 4]) {
    if (s.costs[i] > 0 && s.snow >= s.costs[i]) {
      await tap(cdp, await rectCenter(page, `up${i}`), 40);
      await sleep(80);
      s = await state(page);
    }
  }
  return s;
}
async function sample() {
  let s = await state(page);
  const e = el();
  if (T.firstSnow === null && s.earned > 0) T.firstSnow = e;
  if (T.firstBuy === null && s.lv.some((x) => x > 0)) T.firstBuy = e;
  if (T.radius2 === null && s.radius >= 2) T.radius2 = e;
  if (T.rollGe10 === null && s.rollT >= 10) T.rollGe10 = e;
  if (mi < marks.length && e >= marks[mi]) {
    rows.push({ at: marks[mi], snow: s.snow, earned: s.earned, radius: s.radius, rollT: s.rollT, lastRoll: s.lastRoll, dist: s.dist, lv: s.lv, m: s.m });
    if ([60, 180, 600].includes(marks[mi])) await page.screenshot({ path: `${out}/t${marks[mi]}.png` });
    mi++;
  }
  if (fi < fpsAt.length && e >= fpsAt[fi]) { perf.fps.push({ at: fpsAt[fi], fps: Number((await fps()).toFixed(1)) }); fi++; }
  return s;
}

while (el() < secs) {
  const s = await sample();
  if (policy === 'low') {
    if (s.speed === 0) await padSwipe(page, cdp, 0.45);
    if (s.snow > 0) await buyAffordable(await state(page));
    await sleep(200);
  } else {
    const r = s.rects.pad;
    const until = Date.now() + 1000;
    while (Date.now() < until && el() < secs) {
      const p = await px(page, r[0] + r[2] * (0.25 + 0.5 * ((k * 0.37) % 1)), r[1] + r[3] * (0.3 + 0.5 * ((k * 0.61) % 1)));
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: p.x, y: p.y, id: 1 }] });
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      k++;
    }
    if (s.snow > 0) await buyAffordable(await state(page));
  }
}
const fin = await sample();
perf.heapMB.push(await heap());
await page.screenshot({ path: `${out}/final.png` });
const res = { game: 'snowball-relay', policy, secs, env, T, rows, perf, final: { t: fin.t, lv: fin.lv, radius: fin.radius, rollT: fin.rollT, lastRoll: fin.lastRoll, dist: fin.dist, earned: fin.earned, pushes: fin.pushes, breaks: fin.breaks, m: fin.m }, summary: fin.summary, errors };
env.loadAvgEnd = os.loadavg()[0];
fs.writeFileSync(`${out}/result.json`, JSON.stringify(res, null, 1));
console.log(JSON.stringify({ policy, T, final: res.final, perf, errors }));
await browser.close();
