// Step 04: comfort and robustness, with real touch events.
//   node feel.mjs [outdir]
import { chromium, open, state, padSwipe, rectCenter, tap, swipe, px, sleep } from './lib.mjs';
import { AUDIO_TAP, listen, states } from './audio_tap.mjs';
import fs from 'node:fs';
const out = process.argv[2] || '/tmp/claude-1000/snow-feel';
fs.mkdirSync(out, { recursive: true });
let fails = 0;
const ok = (c, m) => { console.log((c ? 'ok   ' : 'FAIL ') + m); if (!c) fails++; };
const browser = await chromium.launch();
const ts = (cdp, type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
const inter = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];

// A. layout at the phone sizes and desktop
for (const [w, h, touch] of [[360, 800, true], [390, 844, true], [412, 915, true], [1280, 720, false]]) {
  const { ctx, page, errors } = await open(browser, { w, h, touch, dpr: touch ? 2 : 1 });
  await sleep(600);
  const s = await state(page);
  const R = s.rects;
  const names = ['up0', 'up1', 'up2', 'up3', 'up4', 'pad', 'reset', 'info', 'mirror', 'mute'];
  const inside = names.every((n) => R[n][0] >= 0 && R[n][1] >= 0 && R[n][0] + R[n][2] <= 1.001 && R[n][1] + R[n][3] <= 1.001);
  let overlap = '';
  for (let i = 0; i < names.length; i++) for (let j = i + 1; j < names.length; j++) if (inter(R[names[i]], R[names[j]])) overlap += ` ${names[i]}x${names[j]}`;
  const ball = [0.5 - 0.02, 0.4 - 0.02, 0.04, 0.04];
  const covered = names.filter((n) => inter(R[n], ball));
  ok(inside && !overlap && covered.length === 0, `${w}x${h}: controls inside the screen, none overlap${overlap}, ball unobstructed${covered}`);
  ok(errors.length === 0, `${w}x${h}: no browser errors`);
  await ctx.close();
}

// B-G on a phone
{
  const { ctx, page, cdp, errors } = await open(browser, { w: 390, h: 844, init: AUDIO_TAP });
  await sleep(700);
  let s = await state(page);
  // H. audio is a real signal, and muted is silence
  const meter = await listen(page);
  await padSwipe(page, cdp, 0.6);
  const loud = await meter(500);
  ok(loud.peak > 0.01, `a push makes sound at the output (peak ${loud.peak.toFixed(3)}, rms ${loud.rms.toFixed(4)})`);
  ok((await states(page)).every((x) => x === 'running'), `audio context unlocked by the first touch (${(await states(page)).join(',')})`);
  await sleep(2500);
  await tap(cdp, await rectCenter(page, 'mute'), 40); await sleep(300);
  const meter2 = await listen(page);
  await padSwipe(page, cdp, 0.6);
  const quiet = await meter2(500);
  ok(quiet.peak < 0.001, `muted: silent at the output (peak ${quiet.peak.toFixed(4)})`);
  await tap(cdp, await rectCenter(page, 'mute'), 40); await sleep(2500);

  // B. mirror
  s = await state(page);
  const padBefore = s.rects.pad[0];
  await tap(cdp, await rectCenter(page, 'mirror'), 40); await sleep(400);
  s = await state(page);
  ok(s.mirror === true && s.rects.pad[0] < 0.2 && s.rects.up0[0] > 0.7, `mirror puts the pad on the left (x ${padBefore.toFixed(2)} -> ${s.rects.pad[0].toFixed(2)}) and upgrades on the right (${s.rects.up0[0].toFixed(2)})`);
  const pushed = s.pushes;
  await padSwipe(page, cdp, 0.5); await sleep(400);
  s = await state(page);
  ok(s.pushes === pushed + 1, 'a swipe in the mirrored pad pushes');
  await page.screenshot({ path: `${out}/mirrored.png` });
  await tap(cdp, await rectCenter(page, 'mirror'), 40); await sleep(300);
  await sleep(3500);

  // C. touchcancel
  const c0 = (await state(page)).m;
  const pad = await rectCenter(page, 'pad');
  await ts(cdp, 'touchStart', [{ x: pad.x, y: pad.y, id: 1 }]); await sleep(60); await ts(cdp, 'touchCancel', []); await sleep(400);
  let m = (await state(page)).m;
  ok(m.cancelled === c0.cancelled + 1 && m.accepted === c0.accepted, `touchcancel: counted as cancelled, no action (cancelled ${c0.cancelled} -> ${m.cancelled}, accepted ${m.accepted})`);
  // D. window blur during a gesture
  await ts(cdp, 'touchStart', [{ x: pad.x, y: pad.y, id: 1 }]); await sleep(60);
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await ts(cdp, 'touchEnd', []); await sleep(400);
  m = (await state(page)).m;
  ok(m.cancelled === c0.cancelled + 2 && m.accepted === c0.accepted, `blur during a gesture cancels it (cancelled ${m.cancelled})`);
  // E. tab hidden (simulated: Playwright's Chromium cannot really hide a page)
  await ts(cdp, 'touchStart', [{ x: pad.x, y: pad.y, id: 1 }]); await sleep(60);
  await page.evaluate(() => { Object.defineProperty(document, 'hidden', { configurable: true, get: () => true }); document.dispatchEvent(new Event('visibilitychange')); Object.defineProperty(document, 'hidden', { configurable: true, get: () => false }); });
  await ts(cdp, 'touchEnd', []); await sleep(400);
  m = (await state(page)).m;
  ok(m.cancelled === c0.cancelled + 3 && m.accepted === c0.accepted, `tab hidden during a gesture cancels it (cancelled ${m.cancelled}) [simulated visibility]`);
  // F. a gesture that never ended (its release was lost) must not block later touches: a second
  //    finger arriving after the first has been down for a long time replaces it
  let before = (await state(page)).m;
  await ts(cdp, 'touchStart', [{ x: pad.x, y: pad.y, id: 1 }]); await sleep(1500);
  await ts(cdp, 'touchStart', [{ x: pad.x, y: pad.y, id: 1 }, { x: pad.x - 30, y: pad.y - 20, id: 2 }]); await sleep(60);
  await ts(cdp, 'touchEnd', []); await sleep(400);
  m = (await state(page)).m;
  ok(m.accepted === before.accepted + 1 && m.cancelled === before.cancelled + 1, `stale first touch is dropped, the new finger acts (accepted +${m.accepted - before.accepted}, cancelled +${m.cancelled - before.cancelled})`);
  // F2. a finger held for ages is cancelled by itself
  before = (await state(page)).m;
  await ts(cdp, 'touchStart', [{ x: pad.x, y: pad.y, id: 1 }]); await sleep(9000);
  s = await state(page);
  ok(s.gid === -99 && s.m.cancelled === before.cancelled + 1, `a 9 s hold is cancelled by the game (cancelled +${s.m.cancelled - before.cancelled})`);
  await ts(cdp, 'touchEnd', []); await sleep(300);
  ok((await state(page)).m.accepted === before.accepted, 'the late release does nothing');

  // G. runaway input: 80 quick swipes in a couple of seconds
  await sleep(3000);
  const g0 = (await state(page)).m;
  const t0 = Date.now();
  for (let i = 0; i < 80; i++) { await ts(cdp, 'touchStart', [{ x: pad.x, y: pad.y, id: 1 }]); await ts(cdp, 'touchEnd', []); }
  const secs = (Date.now() - t0) / 1000;
  await sleep(500);
  s = await state(page);
  ok(s.m.raw - g0.raw === 80 && s.speed <= 8.01 + 0.28 * 0 + 0.001, `80 quick touches in ${secs.toFixed(1)} s: all counted, speed stays capped (${s.speed}, cap 8)`);
  ok((s.pushes) < 100 && s.snow >= 0, 'state stays sane after the burst');
  ok(errors.length === 0, 'no browser errors ' + JSON.stringify(errors.slice(0, 2)));
  await ctx.close();
}
// I. numbers hidden: pictures for the human review
{
  const { ctx, page, cdp } = await open(browser, { w: 390, h: 844 });
  await sleep(600);
  await tap(cdp, await rectCenter(page, 'info'), 40); await sleep(300);
  await tap(cdp, await rectCenter(page, 'num'), 40); await sleep(300);
  await tap(cdp, await rectCenter(page, 'info'), 40); await sleep(300);
  await padSwipe(page, cdp, 0.6); await sleep(1100);
  await page.screenshot({ path: `${out}/numbers_hidden.png` });
  ok((await state(page)).hidden === true, 'numbers-hidden mode is on for the screenshot');
  await ctx.close();
}
console.log('FAILS', fails);
await browser.close();
process.exit(fails ? 1 : 0);
