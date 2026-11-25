// A long session in a phone-sized browser with real touch events and the game's own metrics.
//   node session.mjs <low|spam> <seconds> <outdir>
//   low  : one tap on the pad every 4 seconds (spots change), upgrades only when affordable
//   spam : quick taps on the pad as fast as the automation can send them (about 10 per second),
//          upgrades checked once a second
// This is automation, not a person: it says nothing about fun, comfort or fatigue.
import { chromium, open, state, rectCenter, tap, px, sleep } from './lib.mjs';
import fs from 'node:fs';
import os from 'node:os';
const policy = process.argv[2] || 'low';
const secs = Number(process.argv[3] || 180);
const out = process.argv[4] || `/tmp/claude-1000/bub-session-${policy}`;
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
const T = { firstPop: null, firstBuy: null, wave10: null, wave30: null, wave70: null };
const rows = [];
const perf = { fps: [], heapMB: [await heap()] };
let mi = 0, nextTap = 0, k = 0, fpsAt = [20, 300].filter((x) => x < secs), fi = 0;

async function buyAffordable(s) {
  for (const i of [0, 1, 2, 3, 4]) {
    if (s.costs[i] > 0 && s.pop >= s.costs[i]) {
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
  if (T.firstPop === null && s.pops > 0) T.firstPop = e;
  if (T.firstBuy === null && s.lv.some((x) => x > 0)) T.firstBuy = e;
  if (T.wave10 === null && s.lastWave >= 10) T.wave10 = e;
  if (T.wave30 === null && s.lastWave >= 30) T.wave30 = e;
  if (T.wave70 === null && s.lastWave >= 70) T.wave70 = e;
  if (mi < marks.length && e >= marks[mi]) {
    rows.push({ at: marks[mi], pop: s.pop, earned: s.earned, lastWave: s.lastWave, lastWaveSecs: s.lastWaveSecs, pops: s.pops, triggers: s.triggers, full: s.full, refill: s.refill, lv: s.lv, m: s.m });
    if ([60, 180, 600].includes(marks[mi])) await page.screenshot({ path: `${out}/t${marks[mi]}.png` });
    mi++;
  }
  if (fi < fpsAt.length && e >= fpsAt[fi]) { perf.fps.push({ at: fpsAt[fi], fps: Number((await fps()).toFixed(1)) }); fi++; }
  return s;
}

while (el() < secs) {
  const s = await sample();
  if (policy === 'low') {
    if (el() >= nextTap) {
      const r = s.rects.pad;
      const p = await px(page, r[0] + r[2] * (0.2 + 0.6 * ((k * 0.37) % 1)), r[1] + r[3] * (0.2 + 0.6 * ((k * 0.61) % 1)));
      await tap(cdp, p, 70); k++;
      nextTap = el() + 4;
    }
    if (s.pop > 0) await buyAffordable(await state(page));
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
    if (s.pop > 0) await buyAffordable(await state(page));
  }
}
const fin = await sample();
perf.heapMB.push(await heap());
await page.screenshot({ path: `${out}/final.png` });
const res = { game: 'bubble-wrap-empire', policy, secs, env, T, rows, perf, final: { t: fin.t, lv: fin.lv, lastWave: fin.lastWave, pops: fin.pops, triggers: fin.triggers, earned: fin.earned, full: fin.full, m: fin.m }, summary: fin.summary, errors };
env.loadAvgEnd = os.loadavg()[0];
fs.writeFileSync(`${out}/result.json`, JSON.stringify(res, null, 1));
console.log(JSON.stringify({ policy, T, final: res.final, perf, errors }));
await browser.close();
