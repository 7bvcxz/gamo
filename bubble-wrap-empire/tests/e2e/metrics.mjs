// The metrics must count what a real finger did: presses, accepted triggers,
// time down, distance, and the panel/copy button must work with real touches.
import { chromium, open, state, rectCenter, tap, swipe, px, sleep } from './lib.mjs';
const browser = await chromium.launch();
let fails = 0;
const ok = (c, m) => { console.log((c ? 'ok   ' : 'FAIL ') + m); if (!c) fails++; };
const { ctx, page, cdp, errors } = await open(browser, { w: 390, h: 844 });
await ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: new URL(page.url()).origin });
await sleep(800);
let s = await state(page);
ok(s.m.raw === 0 && s.m.inputFrac === 0, 'fresh: no presses, zero input');
let nodeDown = 0;
for (let i = 0; i < 3; i++) {
  const r = (await state(page)).rects.pad;
  const from = await px(page, r[0] + r[2] * (0.3 + 0.2 * i), r[1] + r[3] * 0.4);
  const to = await px(page, r[0] + r[2] * (0.3 + 0.2 * i) + 0.02, r[1] + r[3] * 0.45);
  const a = Date.now(); await swipe(cdp, from, to, 100, 3); nodeDown += (Date.now() - a) / 1000;
  await sleep(1000);
}
s = await state(page);
ok(s.m.raw === 3 && s.m.field === 3 && s.m.accepted === 3, `3 short swipes = 3 field gestures, all accepted (raw=${s.m.raw}, field=${s.m.field}, accepted=${s.m.accepted})`);
ok(s.triggers === 3, `and exactly 3 triggers in the game (${s.triggers})`);
ok(Math.abs(s.m.downS - nodeDown) < Math.max(0.35, nodeDown * 0.3), `finger-down time matches an independent measurement (game ${s.m.downS} s, node ${nodeDown.toFixed(2)} s)`);
ok(s.m.travelNorm > 0 && s.m.travelNorm < 1.5, `distance recorded in normalized units (${s.m.travelNorm})`);
ok(Math.abs(s.m.inputFrac - s.m.downS / s.m.elapsed) < 0.01, `input fraction = down time / elapsed (${(s.m.inputFrac * 100).toFixed(1)}%)`);
const before = s.m.field;
await tap(cdp, await rectCenter(page, 'up1'), 40); await sleep(300);
s = await state(page);
ok(s.m.upTaps === 1 && s.m.field === before, `upgrade tap counted separately (upTaps=${s.m.upTaps}, field=${s.m.field})`);
await tap(cdp, await rectCenter(page, 'info'), 40); await sleep(400);
s = await state(page);
ok(!!s.rects.copy && !!s.rects.num, 'info button opens the panel');
await page.screenshot({ path: process.argv[2] ? `${process.argv[2]}/panel.png` : '/tmp/claude-1000/bub-panel.png' });
await tap(cdp, await rectCenter(page, 'copy'), 40); await sleep(500);
let clip = '';
try { clip = await page.evaluate(() => navigator.clipboard.readText()); } catch (e) { clip = 'ERR ' + e.message; }
ok(clip.includes('active_input_fraction') && clip.includes('raw_presses='), `copy puts the summary on the clipboard (${clip.slice(0, 40).replace(/\n/g, ' | ')}...)`);
await tap(cdp, await rectCenter(page, 'num'), 40); await sleep(300);
s = await state(page);
ok(s.hidden === true, 'num button hides the numbers');
const tb = s.triggers;
await sleep(1000);
const r2 = s.rects.pad;
await tap(cdp, await px(page, r2[0] + r2[2] / 2, r2[1] + r2[3] / 2), 50); await sleep(500);
s = await state(page);
ok(s.triggers === tb + 1, 'a tap still triggers with the panel open');
ok(errors.length === 0, 'no browser errors ' + JSON.stringify(errors.slice(0, 2)));
console.log('FAILS', fails);
await browser.close();
process.exit(fails ? 1 : 0);
