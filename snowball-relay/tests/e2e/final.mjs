// Final check on a deployed URL (BASE=...): the game boots, starts fresh, accepts a touch,
// buys an upgrade, resets only on the second tap, and shows no error.
import { chromium, open, state, padSwipe, rectCenter, tap, sleep } from './lib.mjs';
let fails = 0;
const ok = (c, m) => { console.log((c ? 'ok   ' : 'FAIL ') + m); if (!c) fails++; };
const browser = await chromium.launch();
const { page, cdp, errors } = await open(browser, { w: 390, h: 844 });
await sleep(800);
const notice = await page.evaluate(() => { const n = document.getElementById('status-notice'); return n ? getComputedStyle(n).display : 'none'; });
const canvas = await page.evaluate(() => { const c = document.querySelector('canvas'); const r = c.getBoundingClientRect(); return { w: Math.round(r.width), h: Math.round(r.height) }; });
let s = await state(page);
ok(notice === 'none' && canvas.w >= 380 && canvas.h >= 800, `canvas initialised (${canvas.w}x${canvas.h}), no error notice (${notice})`);
ok(s.snow === 0 && s.speed === 0 && s.lv.every((x) => x === 0) && s.m.raw === 0 && s.t < 5, `fresh start: nothing earned, nothing owned (t=${s.t})`);
ok(/version=0\.5\.0/.test(s.summary), 'summary carries the version (0.5.0)');
await padSwipe(page, cdp, 0.5); await sleep(1500);
s = await state(page);
ok(s.snow > 0 && s.dist > 0, `a real touch pushes and earns (snow ${s.snow}, distance ${s.dist})`);
for (let i = 0; i < 6 && s.lv.every((x) => x === 0); i++) { await padSwipe(page, cdp, 0.5); await sleep(1800); s = await state(page); if (s.costs[0] > 0 && s.snow >= s.costs[0]) await tap(cdp, await rectCenter(page, 'up0'), 40); await sleep(200); s = await state(page); }
ok(s.lv[0] === 1, `an upgrade can be bought by touch (Mass level ${s.lv[0]})`);
const owned = s.lv[0];
await tap(cdp, await rectCenter(page, 'reset'), 40); await sleep(300);
s = await state(page);
ok(s.lv[0] === owned && s.pushes > 0, 'the first reset tap only arms it (nothing is lost)');
await tap(cdp, await rectCenter(page, 'reset'), 40); await sleep(500);
s = await state(page);
ok(s.snow === 0 && s.lv.every((x) => x === 0) && s.pushes === 0 && s.m.raw === 0, 'the second tap resets the game and its metrics');
await tap(cdp, await rectCenter(page, 'mute'), 40); await sleep(300);
ok((await state(page)).muted === true, 'mute toggles');
ok(errors.length === 0, 'no browser errors ' + JSON.stringify(errors.slice(0, 2)));
console.log('FAILS', fails);
await browser.close();
process.exit(fails ? 1 : 0);
