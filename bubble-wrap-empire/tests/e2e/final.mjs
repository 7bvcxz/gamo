// Final check on a deployed URL (BASE=...): the game boots, starts fresh, accepts a touch,
// buys an upgrade, resets only on the second tap, and shows no error.
import { chromium, open, state, rectCenter, tap, sleep } from './lib.mjs';
let fails = 0;
const ok = (c, m) => { console.log((c ? 'ok   ' : 'FAIL ') + m); if (!c) fails++; };
const browser = await chromium.launch();
const { page, cdp, errors } = await open(browser, { w: 390, h: 844 });
await sleep(800);
const notice = await page.evaluate(() => { const n = document.getElementById('status-notice'); return n ? getComputedStyle(n).display : 'none'; });
const canvas = await page.evaluate(() => { const c = document.querySelector('canvas'); const r = c.getBoundingClientRect(); return { w: Math.round(r.width), h: Math.round(r.height) }; });
let s = await state(page);
ok(notice === 'none' && canvas.w >= 380 && canvas.h >= 800, `canvas initialised (${canvas.w}x${canvas.h}), no error notice (${notice})`);
ok(s.pop === 0 && s.pops === 0 && s.full === 70 && s.lv.every((x) => x === 0) && s.m.raw === 0 && s.t < 5, `fresh start: nothing earned, sheet full, nothing owned (t=${s.t})`);
ok(/version=0\.5\.0/.test(s.summary), 'summary carries the version (0.5.0)');
await tap(cdp, await rectCenter(page, 'pad'), 60); await sleep(600);
s = await state(page);
ok(s.pops === 1 && s.pop === 1, `a real touch pops a bubble and pays (pops ${s.pops}, POP ${s.pop})`);
for (let i = 0; i < 12 && s.lv[1] === 0; i++) { await sleep(500); await tap(cdp, await rectCenter(page, 'pad'), 60); await sleep(900); s = await state(page); if (s.costs[1] > 0 && s.pop >= s.costs[1]) { await tap(cdp, await rectCenter(page, 'up1'), 40); await sleep(250); s = await state(page); } }
ok(s.lv[1] === 1, `an upgrade can be bought by touch (Chain level ${s.lv[1]})`);
const owned = s.lv[1];
await tap(cdp, await rectCenter(page, 'reset'), 40); await sleep(300);
s = await state(page);
ok(s.lv[1] === owned && s.pops > 0, 'the first reset tap only arms it (nothing is lost)');
await tap(cdp, await rectCenter(page, 'reset'), 40); await sleep(500);
s = await state(page);
ok(s.pop === 0 && s.lv.every((x) => x === 0) && s.pops === 0 && s.m.raw === 0 && s.full === 70, 'the second tap resets the game and its metrics');
await tap(cdp, await rectCenter(page, 'mute'), 40); await sleep(300);
ok((await state(page)).muted === true, 'mute toggles');
ok(errors.length === 0, 'no browser errors ' + JSON.stringify(errors.slice(0, 2)));
console.log('FAILS', fails);
await browser.close();
process.exit(fails ? 1 : 0);
