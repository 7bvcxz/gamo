#!/usr/bin/env node
// One blind playtest session (Step 45): opens the published game in a fresh
// browser profile, waits until it has drawn, and then serves a blind player
// through play.mjs only -- screenshots to look at, taps and drags to act, a
// wait, a note to think aloud. Ten real minutes from the player's first look,
// then it closes. No test bridge, no dev menu, no time acceleration.
//
//   node session.mjs --run /abs/run1 --url https://7bvcxz.github.io/gamo/momonium/ [--minutes 10]
//
// <run>/player/      what the player may see: its screenshots
// <run>/controller/  what only the controller reads: the timed action log,
//                    snapshots of the game's own save, page errors, summary
// <run>/profile/     the browser profile (fresh; nothing shared between runs)
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { SessionClock, toCss, logLine, snapshotFromSave, clock, SESSION_MINUTES } from './lib.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const e2e = path.join(here, '../../tests/e2e');
const require = createRequire(path.join(e2e, 'package.json'));
const { chromium } = require('playwright');
const { decodePng, colorCount } = await import(pathToFileURL(path.join(e2e, 'lib/png.mjs')).href);

const argv = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 ? argv[i + 1] : fallback;
};
const run = path.resolve(opt('run', ''));
const url = opt('url', 'https://7bvcxz.github.io/gamo/momonium/');
const minutes = Number(opt('minutes', SESSION_MINUTES));
if (!opt('run')) {
  console.error('usage: node session.mjs --run DIR --url URL [--minutes 10]');
  process.exit(2);
}
// A phone held upright: touch input, portrait, readable screenshots.
const VIEWPORT = { width: 400, height: 860 };
const DPR = 1.5;

const playerDir = path.join(run, 'player');
const shotDir = path.join(playerDir, 'shots');
const ctlDir = path.join(run, 'controller');
for (const d of [shotDir, ctlDir]) fs.mkdirSync(d, { recursive: true });
const profile = path.join(run, 'profile');
if (fs.existsSync(profile) && fs.readdirSync(profile).length > 0) {
  console.error(`session: ${profile} is not empty -- every run needs a fresh profile`);
  process.exit(2);
}
const actions = path.join(ctlDir, 'actions.jsonl');
const states = path.join(ctlDir, 'state.jsonl');
const errorsFile = path.join(ctlDir, 'errors.jsonl');

const sessionClock = new SessionClock(minutes);
let shots = 0;
let busy = Promise.resolve();
let finished = false;
const counts = { look: 0, tap: 0, drag: 0, wait: 0, note: 0 };

const context = await chromium.launchPersistentContext(profile, {
  headless: true, viewport: VIEWPORT, deviceScaleFactor: DPR, isMobile: true, hasTouch: true,
});
const page = context.pages()[0] || (await context.newPage());
page.on('pageerror', (e) => fs.appendFileSync(errorsFile, JSON.stringify({ t: sessionClock.elapsed(), kind: 'pageerror', text: e.message }) + '\n'));
page.on('console', (m) => {
  if (m.type() === 'error') fs.appendFileSync(errorsFile, JSON.stringify({ t: sessionClock.elapsed(), kind: 'console', text: m.text() }) + '\n');
});

// Loaded and drawn: a canvas with real colours, not just created.
const loadStarted = Date.now();
await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120_000 });
let colours = 0;
while (Date.now() - loadStarted < 150_000) {
  const canvas = await page.$('canvas');
  if (canvas) {
    colours = colorCount(decodePng(await canvas.screenshot()));
    if (colours >= 12) break;
  }
  await page.waitForTimeout(500);
}
const version = await page.evaluate(async () => {
  try {
    return (await (await fetch('version.json', { cache: 'no-store' })).json()).version;
  } catch {
    return '';
  }
});
fs.writeFileSync(path.join(ctlDir, 'start.json'), JSON.stringify({ url, version, load_ms: Date.now() - loadStarted, colours, viewport: VIEWPORT, dpr: DPR, minutes }, null, 2));

async function screenshot() {
  shots += 1;
  const file = path.join(shotDir, `${String(shots).padStart(3, '0')}.png`);
  await page.screenshot({ path: file });
  return file;
}

async function touchDrag(from, to, steps = 12) {
  const s = await context.newCDPSession(page);
  const pt = (p) => ({ x: p.x, y: p.y, id: 0, radiusX: 2, radiusY: 2, force: 1 });
  await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [pt(from)] });
  for (let i = 1; i <= steps; i++) {
    const p = { x: from.x + ((to.x - from.x) * i) / steps, y: from.y + ((to.y - from.y) * i) / steps };
    await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [pt(p)] });
    await page.waitForTimeout(20);
  }
  await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await s.detach();
}

// The controller's view of progress: the game's own save, every ten seconds.
async function snapshot() {
  const text = await page.evaluate(() => localStorage.getItem('momonium_save')).catch(() => null);
  fs.appendFileSync(states, JSON.stringify({ t: Math.round(sessionClock.elapsed()), state: snapshotFromSave(text) }) + '\n');
}

async function finish(reason) {
  if (finished) return;
  finished = true;
  await busy.catch(() => {});
  const final = await screenshot().catch(() => '');
  await snapshot().catch(() => {});
  fs.writeFileSync(path.join(ctlDir, 'summary.json'), JSON.stringify({
    reason, elapsed_s: Math.round(sessionClock.elapsed()), counts, shots, final_shot: final, version,
  }, null, 2));
  server.close();
  await context.close();
  console.log(`session: finished (${reason}) after ${clock(sessionClock.elapsed())}`);
  process.exit(0);
}

async function handle(cmd, args) {
  if (finished || sessionClock.over()) {
    setTimeout(() => finish('time'), 0);
    return { over: true, message: 'Time is up: the ten minutes are over.' };
  }
  if (cmd === 'status') {
    return { time: clock(sessionClock.elapsed()), left: clock(sessionClock.remaining()), started: sessionClock.started };
  }
  sessionClock.start();
  counts[cmd] = (counts[cmd] || 0) + 1;
  let result = {};
  if (cmd === 'tap') {
    const p = toCss(args.x, args.y, DPR, VIEWPORT);
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(700);
  } else if (cmd === 'drag') {
    await touchDrag(toCss(args.x1, args.y1, DPR, VIEWPORT), toCss(args.x2, args.y2, DPR, VIEWPORT));
    await page.waitForTimeout(500);
  } else if (cmd === 'wait') {
    await page.waitForTimeout(Math.round(args.s * 1000));
  }
  if (cmd !== 'note') result.screen = await screenshot();
  fs.appendFileSync(actions, logLine(sessionClock.elapsed(), cmd, args, result.screen ? { shot: path.basename(result.screen) } : {}));
  return { ...result, time: clock(sessionClock.elapsed()), left: clock(sessionClock.remaining()) };
}

const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => {
    let msg;
    try {
      msg = JSON.parse(body || '{}');
    } catch {
      res.writeHead(400).end('{"error":"bad json"}');
      return;
    }
    // One command at a time, in order.
    busy = busy.then(() => handle(msg.cmd, msg.args || {})).then(
      (out) => res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(out)),
      (err) => res.writeHead(500).end(JSON.stringify({ error: String(err) })),
    );
  });
});
server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(path.join(run, 'port'), String(server.address().port));
  console.log(`session: ready (v${version}, loaded in ${Date.now() - loadStarted} ms) on port ${server.address().port}`);
});

setInterval(() => {
  if (!sessionClock.started) return;
  if (sessionClock.over()) finish('time');
}, 1000);
setInterval(() => {
  if (sessionClock.started && !finished) snapshot().catch(() => {});
}, 10_000);
// A session nobody starts within ten minutes of loading ends too.
setTimeout(() => { if (!sessionClock.started) finish('never started'); }, 10 * 60_000);
