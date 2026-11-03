#!/usr/bin/env node
// One blind playtest session (Popcorn Step 08). Opens the game in a fresh
// browser profile, waits until it has drawn, then serves ONE blind player
// through play.mjs: screenshots to look at, a finger to tap / hold / drag, a
// wait, a note to think aloud. Three real minutes from the player's first
// command, then it closes. No test hooks (window.POPCORN_E2E is never set),
// no dev mode, no time acceleration. The player never sees the URL.
//
//   node session.mjs --run /abs/run1 --url 'https://7bvcxz.github.io/gamo/popcorn-glory/#click' [--seconds 180]
//
// <run>/player/shots/  what the player may see: its screenshots
// <run>/controller/    what only the evaluator reads: timed actions, the game's
//                      state every 5 s, its own log at the end, page errors,
//                      a screen recording, summary
// <run>/profile/       the browser profile (fresh; nothing shared between runs)
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(here, '../../tests/e2e/package.json'));
const { chromium } = require('playwright');

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(`--${n}`); return i >= 0 ? argv[i + 1] : d; };
if (!opt('run') || !opt('url')) { console.error('usage: node session.mjs --run DIR --url URL [--seconds 180]'); process.exit(2); }
const run = path.resolve(opt('run'));
const url = opt('url');
const SECONDS = Number(opt('seconds', 180));
// A phone held upright: touch, portrait; screenshots are 600 x 1290 px.
const VIEWPORT = { width: 400, height: 860 };
const DPR = 1.5;

const shotDir = path.join(run, 'player', 'shots');
const ctl = path.join(run, 'controller');
for (const d of [shotDir, path.join(ctl, 'video')]) fs.mkdirSync(d, { recursive: true });
const profile = path.join(run, 'profile');
if (fs.existsSync(profile) && fs.readdirSync(profile).length) { console.error('session: profile not empty -- every run needs a fresh one'); process.exit(2); }
const actions = path.join(ctl, 'actions.jsonl');
const states = path.join(ctl, 'state.jsonl');
const errors = path.join(ctl, 'errors.jsonl');

let startedAt = 0;
const elapsed = () => (startedAt ? (Date.now() - startedAt) / 1000 : 0);
const over = () => startedAt && elapsed() >= SECONDS;
const clock = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
let shots = 0;
let busy = Promise.resolve();
let finished = false;
const counts = {};

const context = await chromium.launchPersistentContext(profile, {
  headless: true, viewport: VIEWPORT, deviceScaleFactor: DPR, isMobile: true, hasTouch: true,
  recordVideo: { dir: path.join(ctl, 'video'), size: VIEWPORT },
});
const page = context.pages()[0] || (await context.newPage());
page.on('pageerror', (e) => fs.appendFileSync(errors, JSON.stringify({ t: elapsed(), kind: 'pageerror', text: e.message }) + '\n'));
page.on('console', (m) => { if (m.type() === 'error') fs.appendFileSync(errors, JSON.stringify({ t: elapsed(), kind: 'console', text: m.text() }) + '\n'); });

const loadStarted = Date.now();
await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120_000 });
await page.waitForFunction(() => window.popcorn && window.popcorn.ready, null, { timeout: 150_000 });
await page.waitForTimeout(1500);
const version = await page.evaluate(() => window.popcorn.version);
fs.writeFileSync(path.join(ctl, 'start.json'), JSON.stringify({ url, version, load_ms: Date.now() - loadStarted, viewport: VIEWPORT, dpr: DPR, seconds: SECONDS }, null, 2));

const toCss = (x, y) => ({ x: Math.max(0, Math.min(VIEWPORT.width - 1, x / DPR)), y: Math.max(0, Math.min(VIEWPORT.height - 1, y / DPR)) });
async function screenshot() {
  shots += 1;
  const file = path.join(shotDir, `${String(shots).padStart(3, '0')}.png`);
  await page.screenshot({ path: file });
  return file;
}
// One CDP session for the page: a touch that starts on one session and ends on
// another is refused ('Must send a TouchStart first' -- found by the smoke run).
let cdp = null;
async function touch(type, p) {
  if (!cdp) cdp = await context.newCDPSession(page);
  await cdp.send('Input.dispatchTouchEvent', { type, touchPoints: p ? [{ x: p.x, y: p.y, id: 0, radiusX: 2, radiusY: 2, force: 1 }] : [] });
}
async function snapshot() {
  const s = await page.evaluate(() => window.popcorn.state()).catch(() => null);
  if (s) fs.appendFileSync(states, JSON.stringify({ t: Math.round(elapsed() * 10) / 10, screen: s.screen, exp: s.exp, run: s.run, clock_ms: s.clock_ms, sound: s.sound }) + '\n');
}
async function finish(reason) {
  if (finished) return;
  finished = true;
  await busy.catch(() => {});
  const final = await screenshot().catch(() => '');
  await snapshot().catch(() => {});
  const log = await page.evaluate(() => window.popcorn.call('log_document')).catch(() => null);
  if (log) fs.writeFileSync(path.join(ctl, 'game_log.json'), JSON.stringify(log, null, 2));
  fs.writeFileSync(path.join(ctl, 'summary.json'), JSON.stringify({ reason, elapsed_s: Math.round(elapsed()), counts, shots, final_shot: final, version }, null, 2));
  server.close();
  await context.close();   // writes the video
  console.log(`session: finished (${reason}) after ${clock(elapsed())}`);
  process.exit(0);
}

async function handle(cmd, a) {
  if (finished || over()) { setTimeout(() => finish('time'), 0); return { over: true, message: 'Time is up: the three minutes are over.' }; }
  if (cmd === 'status') return { time: clock(elapsed()), left: clock(Math.max(0, SECONDS - elapsed())), started: startedAt > 0 };
  if (!startedAt) startedAt = Date.now();
  counts[cmd] = (counts[cmd] || 0) + 1;
  const issued = Math.round(elapsed() * 10) / 10;
  const out = {};
  if (cmd === 'tap') {
    const p = toCss(a.x, a.y);
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(500);
  } else if (cmd === 'hold') {
    // Step 09: a person sees the screen WHILE the finger is down (B's needle
    // running round the ring); Step 08's players saw only the screen after
    // lifting and guessed the needle's direction backwards. So the hold also
    // returns a picture taken about 0.3 s before the lift, and the hold time
    // is kept by the clock, not by adding the screenshot's own time.
    const p = toCss(a.x, a.y);
    const ms = Math.round(Math.min(5, Math.max(0.1, a.s)) * 1000);
    const t0 = Date.now();
    await touch('touchStart', p);
    if (ms >= 500) {
      await page.waitForTimeout(Math.max(0, ms - 300 - (Date.now() - t0)));
      out.held_screen = await screenshot();
    }
    await page.waitForTimeout(Math.max(0, ms - (Date.now() - t0)));
    await touch('touchEnd', null);
    out.held_ms = Date.now() - t0;
    await page.waitForTimeout(400);
  } else if (cmd === 'drag') {
    const p1 = toCss(a.x1, a.y1); const p2 = toCss(a.x2, a.y2);
    await touch('touchStart', p1);
    for (let i = 1; i <= 10; i++) { await touch('touchMove', { x: p1.x + (p2.x - p1.x) * i / 10, y: p1.y + (p2.y - p1.y) * i / 10 }); await page.waitForTimeout(20); }
    await touch('touchEnd', null);
    await page.waitForTimeout(400);
  } else if (cmd === 'wait') {
    await page.waitForTimeout(Math.round(Math.min(30, Math.max(0, a.s)) * 1000));
  }
  if (cmd !== 'note') out.screen = await screenshot();
  fs.appendFileSync(actions, JSON.stringify({ t: Math.round(elapsed() * 10) / 10, issued, cmd, args: a, shot: out.screen ? path.basename(out.screen) : undefined,
    held_shot: out.held_screen ? path.basename(out.held_screen) : undefined, held_ms: out.held_ms }) + '\n');
  return { ...out, time: clock(elapsed()), left: clock(Math.max(0, SECONDS - elapsed())) };
}

const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => {
    let msg;
    try { msg = JSON.parse(body || '{}'); } catch { res.writeHead(400).end('{"error":"bad json"}'); return; }
    busy = busy.then(() => handle(msg.cmd, msg.args || {})).then(
      (o) => res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(o)),
      (e) => res.writeHead(500).end(JSON.stringify({ error: String(e) })));
  });
});
server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(path.join(run, 'port'), String(server.address().port));
  console.log(`session: ready (v${version}, loaded in ${Date.now() - loadStarted} ms) on port ${server.address().port}`);
});
setInterval(() => { if (startedAt && over()) finish('time'); }, 1000);
setInterval(() => { if (startedAt && !finished) snapshot().catch(() => {}); }, 5000);
setTimeout(() => { if (!startedAt) finish('never started'); }, 15 * 60_000);
