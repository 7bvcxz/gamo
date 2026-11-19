// Step 43 on the real S23: the public 0.43.0 in the phone's own Chrome, the page's real output
// measured on the phone's audio thread (the same AUDIO_TAP as the specs), the kettle held with a
// real touch from `adb shell input swipe` (a finger, not CDP).
// usage: node s23_sound.mjs <outdir>
import { chromium } from '/home/merti/Workspace/gamo-popcorn/popcorn-glory/tests/e2e/node_modules/playwright/index.mjs';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { AUDIO_TAP, listen, listenStereo, counts, states } from '/home/merti/Workspace/gamo-popcorn/popcorn-glory/tests/e2e/lib/audio_tap.mjs';

const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });
const adb = (...a) => execFileSync('adb', ['-s', 'R3CW900QYZD', ...a]).toString();
const log = [];
const note = (k, v) => { log.push({ k, v }); console.log(k, JSON.stringify(v)); };

const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const ctx = browser.contexts()[0];
const page = await ctx.newPage();
const errs = [];
page.on('pageerror', (e) => errs.push(String(e)));
await page.addInitScript(AUDIO_TAP);
await page.goto('https://7bvcxz.github.io/gamo/popcorn-glory/?dev=1#factory');
await page.waitForFunction(() => window.popcorn && window.popcorn.ready, null, { timeout: 120_000 });
await page.waitForTimeout(3000);
const st = () => page.evaluate(() => window.popcorn.state());
let s = await st();
note('version', s.version ?? null);
note('screen', s.screen);
note('contexts_before_touch', await states(page));
// Where the kettle's ring is on the phone's screen: CSS px to device px, under Chrome's top bar.
const geo = await page.evaluate(() => ({ dpr: devicePixelRatio, ih: innerHeight, iw: innerWidth, sh: screen.height, sw: screen.width }));
const box = await page.locator('canvas').boundingBox();
const r = s.rects.ring;
const k = box.width / s.window[0];
const cx = box.x + (r[0] + r[2] / 2) * k;
const cy = box.y + (r[1] + r[3] / 2) * k;
// Calibrate: one real tap at a known device pixel, read where the page saw it (clientX/Y), so
// device px = offset + css px * dpr whatever the orientation and bars.
await page.evaluate(() => { window.__t = null; addEventListener('touchstart', (e) => { window.__t = [e.touches[0].clientX, e.touches[0].clientY]; }, { once: true, capture: true }); });
adb('shell', 'input', 'tap', '600', '700');
await page.waitForTimeout(800);
const seen = await page.evaluate(() => window.__t);
const offx = 600 - seen[0] * geo.dpr, offy = 700 - seen[1] * geo.dpr;
const dx = Math.round(offx + cx * geo.dpr), dy = Math.round(offy + cy * geo.dpr);
await page.waitForTimeout(2500);
note('geometry', { geo, seen, offx, offy, cx, cy, dx, dy });
const w = s.run.window;
const holdMs = Math.round(w[0] + (w[1] - w[0]) * 0.25);
const tries = [];
for (let i = 0; i < 4; i++) {
  s = await st();
  if (s.run.heating || Object.keys(s.run.glass).length > 0 || s.run.cooldown_left > 0) { await page.waitForTimeout(1500); continue; }
  const h = await listen(page);
  const hs = await listenStereo(page);
  adb('shell', 'input', 'swipe', String(dx), String(dy), String(dx), String(dy), String(holdMs));
  await page.waitForTimeout(1200);
  const m = await h(0);
  const e = await hs(0);
  const after = (await st()).sound;
  tries.push({ i, holdMs, rms: m.rms, peak: m.peak, mean_rms: e.mean_rms, played: after.played, outcomes: (await st()).run.outcomes });
  note('try', tries[tries.length - 1]);
  await page.waitForTimeout(2500);
}
note('contexts_after_touch', await states(page));
// The floor with forty-four machines, as in sound43 (dev_build works on the public build).
const b = await page.evaluate(() => window.popcorn.call('dev_build', { plan: [['cooker', 'kitchen'], ['bagger', 'packing'], ['S03', 'shop'], ['M01', 'kitchen'], ['cooker', 'kitchen'], ['S05', 'shop'], ['cooker', 'kitchen'], ['P07', 'packing'], ['M13', 'kitchen'], ['cooker', 'kitchen'], ['bagger', 'packing'], ['S08', 'shop']], sign: 4, packer: 2 }));
note('built', b);
for (let i = 0; i < 10; i++) { await page.evaluate(() => window.popcorn.call('dev_advance', 400)); await page.waitForTimeout(200); }
const fl = await listenStereo(page);
const fm = await listen(page);
const floorPeak = await fm(4000);
const floor = await fl(0);
note('floor_12', { rms: floorPeak.rms, peak: floorPeak.peak, mean_rms: floor.mean_rms, beds: (await st()).sound.beds_playing, voices_peak: (await st()).sound.voices_peak });
note('counts', await counts(page));
await page.screenshot({ path: path.join(OUT, 's23_factory12.png') });
note('errors', errs);
fs.writeFileSync(path.join(OUT, 's23_sound.json'), JSON.stringify(log, null, 1));
await page.close();
await browser.close();
