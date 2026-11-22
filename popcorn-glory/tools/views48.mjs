#!/usr/bin/env node
// Step 48: the release candidate's views at the exported size, for the art/UX/sound pass. Each view
// is opened in a fresh browser on the published (or a local) build: a new factory (0 m), a simulated
// career's own saves at 3, 10 and 30 minutes (tools/sim/career39.gd, average hand, balanced policy --
// a simulation, not a player), and the prepared 44-machine factory. On a phone (390x844 @2, touch),
// a 720x1280 portrait (touch) and a desktop (1280x800, mouse). For each: a still after it settles, and
// a still 0.45 s after a real hold released in the gold (the Perfect's feedback as a player sees it).
//   node tools/views48.mjs --url https://7bvcxz.github.io/gamo/popcorn-glory/ --out evidence/step48/views/shots \
//        --save m3=FILE --save m10=FILE ... [--only m30]
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(here, '../tests/e2e/package.json'));
const { chromium } = require('playwright');

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(`--${n}`); return i >= 0 ? argv[i + 1] : d; };
const base = opt('url', 'https://7bvcxz.github.io/gamo/popcorn-glory/');
const out = path.resolve(opt('out', 'views'));
const only = opt('only', '');
const videoDir = opt('video', '') ? path.resolve(opt('video')) : '';   // genuine footage for the teaser (each view, each size)
const views = [['m0', null]];
for (let i = 0; i < argv.length; i++) if (argv[i] === '--save') { const [k, f] = argv[i + 1].split('='); views.push([k, path.resolve(f)]); }
const SIZES = {
  phone: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
  p720: { viewport: { width: 720, height: 1280 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true },
  desktop: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 },
};
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ headless: true });
const report = [];
for (const [name, file] of views) {
  if (only && !only.split(',').includes(name)) continue;
  for (const [size, opts] of Object.entries(SIZES)) {
    const context = await browser.newContext(videoDir ? { ...opts, recordVideo: { dir: path.join(videoDir, `${name}_${size}`), size: opts.viewport } } : opts);
    const text = file ? fs.readFileSync(file, 'utf8') : null;
    await context.addInitScript((t) => {
      window.POPCORN_E2E = true;   // read the ring's window for the gold hold (the views only; no dev calls)
      try { if (t && !localStorage.getItem('popcorn-glory.factory.v1')) localStorage.setItem('popcorn-glory.factory.v1', t); } catch (e) {}
    }, text);
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(new URL('#factory', base).href, { waitUntil: 'domcontentloaded', timeout: 120_000 });
    await page.waitForFunction(() => window.popcorn && window.popcorn.ready && typeof window.popcorn.state === 'function', null, { timeout: 150_000 });
    await page.waitForTimeout(6000);
    const shot = (tag) => page.screenshot({ path: path.join(out, `${name}_${size}_${tag}.png`) });
    await shot('settled');
    // A real hold released a third of the way into the gold, once the kettle is free.
    let s = await page.evaluate(() => window.popcorn.state());
    for (let i = 0; i < 30 && (s.run.heating || Object.keys(s.run.glass).length || s.run.cooldown_left > 0); i++) { await page.waitForTimeout(300); s = await page.evaluate(() => window.popcorn.state()); }
    const r = s.rects.play;
    const box = await page.locator('canvas').boundingBox();
    const k = box.width / s.window[0];
    const x = box.x + (r[0] + r[2] / 2) * k; const y = box.y + (r[1] + r[3] / 2) * k;
    const w = s.run.window;
    const ms = Math.round(w[0] + (w[1] - w[0]) * 0.3);
    if (opts.hasTouch) {
      const cdp = await context.newCDPSession(page);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
      await page.waitForTimeout(ms);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    } else {
      await page.mouse.move(x, y); await page.mouse.down(); await page.waitForTimeout(ms); await page.mouse.up();
    }
    await page.waitForTimeout(450);
    await shot('after_hold');
    if (videoDir) await page.waitForTimeout(4000);   // let the footage run on after the pop
    s = await page.evaluate(() => window.popcorn.state());
    report.push({ view: name, size, version: s.version, machines: s.run.machines.length, level: s.run.level, sign: s.run.sign_tier, money: s.run.money,
      last_outcome: (s.run.outcomes ? Object.entries(s.run.outcomes).filter(([, v]) => v > 0).map(([k2, v]) => `${k2}:${v}`).join(' ') : ''), errors });
    await context.close();
  }
}
await browser.close();
fs.writeFileSync(path.join(out, 'views.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report.map((x) => [x.view, x.size, x.version, x.machines, x.level, x.sign, x.money, x.errors.length])));
