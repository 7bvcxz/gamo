// A fresh 3-minute run in a phone-sized browser with real touch: a relaxed
// player taps the pad every few seconds (a different spot each time) and buys
// whatever the POP can afford. Records milestones and screenshots.
import { chromium, open, state, px, tap, rectCenter, sleep } from './lib.mjs';
import fs from 'node:fs';
const out = process.argv[2] || '/tmp/claude-1000/bub-3min';
const secs = Number(process.argv[3] || 180);
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const { page, cdp, errors } = await open(browser, { w: 390, h: 844 });
const t0 = Date.now();
let firstPop = null, firstBuy = null, taps = 0, buys = 0, biggest = 0;
const rows = [];
const marks = [10, 30, 60, 120, 180].filter((m) => m <= secs);
let mi = 0, nextTap = 0, k = 0;
while ((Date.now() - t0) / 1000 < secs) {
  const el = (Date.now() - t0) / 1000;
  if (el >= nextTap) {
    const s = await state(page);
    const r = s.rects.pad;
    const fx = 0.2 + 0.6 * ((k * 0.37) % 1), fy = 0.2 + 0.6 * ((k * 0.61) % 1);
    const p = await px(page, r[0] + r[2] * fx, r[1] + r[3] * fy);
    await tap(cdp, p, 70);
    taps++; k++;
    nextTap = el + 3;
    await sleep(200);
    const a = await state(page);
    if (firstPop === null && a.pops > 0) firstPop = (Date.now() - t0) / 1000;
  }
  for (const i of [0, 1, 2, 3, 4]) {
    const s = await state(page);
    if (s.pop <= 0) break;
    const before = s.lv[i];
    await tap(cdp, await rectCenter(page, `up${i}`), 40);
    await sleep(100);
    const after = (await state(page)).lv[i];
    if (after > before) { buys++; if (firstBuy === null) firstBuy = (Date.now() - t0) / 1000; }
  }
  const m = await state(page);
  biggest = Math.max(biggest, m.lastWave);
  if (mi < marks.length && (Date.now() - t0) / 1000 >= marks[mi]) {
    rows.push({ at: marks[mi], pop: m.pop, lv: m.lv, lastWave: m.lastWave, lastWaveSecs: m.lastWaveSecs, biggest, pops: m.pops, triggers: m.triggers, full: m.full });
    await page.screenshot({ path: `${out}/t${marks[mi]}.png` });
    mi++;
  }
  await sleep(150);
}
const fin = await state(page);
const res = { firstPop, firstBuy, taps, buys, rows, final: { t: fin.t, lv: fin.lv, lastWave: fin.lastWave, biggest, pops: fin.pops, triggers: fin.triggers }, errors };
fs.writeFileSync(`${out}/result.json`, JSON.stringify(res, null, 1));
console.log(JSON.stringify(res));
await browser.close();
