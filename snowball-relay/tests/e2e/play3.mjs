// A fresh 3-minute run in a phone-sized browser with real touch: a relaxed
// player swipes whenever the ball has stopped and buys the first thing the
// snow can afford. Records milestones and screenshots.
import { chromium, open, state, padSwipe, rectCenter, tap, sleep } from './lib.mjs';
import fs from 'node:fs';
const out = process.argv[2] || '/tmp/claude-1000/snow-3min';
const secs = Number(process.argv[3] || 180);
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const { page, cdp, errors } = await open(browser, { w: 390, h: 844 });
const t0 = Date.now();
const rows = [];
let firstSnow = null, firstBuy = null, swipes = 0, buys = 0;
const marks = [10, 30, 60, 120, 180].filter((m) => m <= secs);
let mi = 0;
while ((Date.now() - t0) / 1000 < secs) {
  const s = await state(page);
  const el = (Date.now() - t0) / 1000;
  if (firstSnow === null && s.earned > 0) firstSnow = el;
  if (s.speed === 0) { await padSwipe(page, cdp, 0.45); swipes++; }
  // buy only what the snow can pay for (a real player does not tap a button they cannot afford)
  for (const i of [0, 1, 2, 3, 4]) {
    const cur = await state(page);
    if (cur.costs[i] > 0 && cur.snow >= cur.costs[i]) {
      const lvBefore = cur.lv[i];
      await tap(cdp, await rectCenter(page, `up${i}`), 40);
      await sleep(120);
      if ((await state(page)).lv[i] > lvBefore) { buys++; if (firstBuy === null) firstBuy = el; }
    }
  }
  if (mi < marks.length && el >= marks[mi]) {
    const m = await state(page);
    rows.push({ at: marks[mi], snow: m.snow, radius: m.radius, lv: m.lv, rollT: m.rollT, lastRoll: m.lastRoll, dist: m.dist, breaks: m.breaks });
    await page.screenshot({ path: `${out}/t${marks[mi]}.png` });
    mi++;
  }
  await sleep(250);
}
const fin = await state(page);
const res = { m: fin.m, summary: fin.summary, firstSnow, firstBuy, swipes, buys, rows, final: { t: fin.t, lv: fin.lv, radius: fin.radius, rollT: fin.rollT, lastRoll: fin.lastRoll }, errors };
fs.writeFileSync(`${out}/result.json`, JSON.stringify(res, null, 1));
console.log(JSON.stringify(res));
await browser.close();
