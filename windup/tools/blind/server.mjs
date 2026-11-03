// Blind-play recorder (Step 09). Owns the browser; the blind player never sees
// this file, the game's code, its state or its telemetry. The player's only
// interface is act.mjs, which sends one command and gets back the path of a
// new screenshot and the seconds since the game started. Everything the player
// does is logged here with wall time and (read here, never returned) game time.
// After the session the game's own event log is saved for correlation.
//
//   node server.mjs --url <game url> --screens <dir the player can read> --out <evidence dir> --port <n>
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from '@playwright/test';
import { AUDIO_TAP } from '../../tests/e2e/lib/audio_tap.mjs';
import { recordingContext, takeAudio, finishFootage } from '../../tests/e2e/lib/footage.mjs';

const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i > 0 ? process.argv[i + 1] : d; };
const URL = arg('url');
const SCREENS = arg('screens');
const OUT = arg('out');
const PORT = Number(arg('port', '18600'));
const LIMIT_S = Number(arg('limit', '480'));
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(SCREENS, { recursive: true });
const VIEW = { width: 1280, height: 720 };

const browser = await chromium.launch();
const rec = await recordingContext(browser, VIEW, path.join(OUT, 'video_tmp'));
const page = rec.page;
await page.addInitScript(AUDIO_TAP);
await page.goto(URL);
await page.waitForFunction(() => window.windup && window.windup.ready === true, null, { timeout: 120_000 });
await page.waitForTimeout(1500);
const t0 = Date.now();
let n = 0;
let ended = false;
const log = fs.createWriteStream(path.join(OUT, 'actions.jsonl'));
const gameT = async () => { try { return (await page.evaluate(() => window.windup.state().t)); } catch { return null; } };

async function shoot() {
  n += 1;
  const name = `${String(n).padStart(4, '0')}.png`;
  await page.screenshot({ path: path.join(SCREENS, name) });
  return name;
}

const num = (v, lo, hi) => Math.max(lo, Math.min(hi, Number(v)));
async function perform(cmd, a) {
  const x = () => num(a[0], 0, VIEW.width - 1), y = () => num(a[1], 0, VIEW.height - 1);
  switch (cmd) {
    case 'look': return;
    case 'click': await page.mouse.click(x(), y()); return;
    case 'double_click': await page.mouse.dblclick(x(), y()); return;
    case 'hold': await page.mouse.move(x(), y()); await page.mouse.down(); await page.waitForTimeout(num(a[2], 0.1, 10) * 1000); await page.mouse.up(); return;
    case 'drag': {
      await page.mouse.move(num(a[0], 0, 1279), num(a[1], 0, 719)); await page.mouse.down();
      const steps = 12; const secs = num(a[4] ?? 0.6, 0.1, 5);
      for (let i = 1; i <= steps; i++) { await page.mouse.move(num(a[0], 0, 1279) + (num(a[2], 0, 1279) - num(a[0], 0, 1279)) * i / steps, num(a[1], 0, 719) + (num(a[3], 0, 719) - num(a[1], 0, 719)) * i / steps); await page.waitForTimeout(secs * 1000 / steps); }
      await page.mouse.up(); return;
    }
    case 'key': await page.keyboard.press(String(a[0] || 'Space')); return;
    case 'hold_key': await page.keyboard.down(String(a[0] || 'Space')); await page.waitForTimeout(num(a[1], 0.1, 10) * 1000); await page.keyboard.up(String(a[0] || 'Space')); return;
    case 'wait': await page.waitForTimeout(num(a[0], 0, 10) * 1000); return;
    default: throw new Error(`unknown command "${cmd}". Commands: look, click X Y, double_click X Y, hold X Y SECONDS, drag X1 Y1 X2 Y2 [SECONDS], key NAME, hold_key NAME SECONDS, wait SECONDS, end`);
  }
}

async function finish() {
  ended = true;
  // The bridge hands the event log out as JSON lines (one event per line).
  const raw = await page.evaluate(() => window.windup.events()).catch(() => '');
  const events = String(raw || '').split('\n').filter(Boolean).map((l) => JSON.parse(l));
  const state = await page.evaluate(() => window.windup.state()).catch(() => ({}));
  fs.writeFileSync(path.join(OUT, 'game_events.jsonl'), events.map((e) => JSON.stringify(e)).join('\n') + '\n');
  fs.writeFileSync(path.join(OUT, 'game_state_end.json'), JSON.stringify(state, null, 2) + '\n');
  const audio = await takeAudio(page);
  const f = await finishFootage(rec, audio, path.join(OUT, `session_${state.build_id || 'unknown'}.mp4`));
  fs.writeFileSync(path.join(OUT, 'footage.json'), JSON.stringify({ file: path.basename(f.out), audio_bytes: f.audio_bytes, audio_offset_s: f.audio_offset_s }) + '\n');
  await browser.close();
}

const server = http.createServer(async (req, res) => {
  let body = '';
  for await (const chunk of req) body += chunk;
  const { cmd, args = [] } = JSON.parse(body || '{}');
  const wall = (Date.now() - t0) / 1000;
  if (ended) { res.end(JSON.stringify({ error: 'the session has ended' })); return; }
  if (cmd === 'end' || wall > LIMIT_S) {
    log.write(JSON.stringify({ wall, game: await gameT(), cmd: 'end', auto: cmd !== 'end' }) + '\n');
    res.end(JSON.stringify({ ended: true, seconds: Math.round(wall) }));
    await finish(); server.close(); log.end(); return;
  }
  try {
    const before = await gameT();
    await perform(cmd, args);
    const screen = await shoot();
    const after = (Date.now() - t0) / 1000;
    log.write(JSON.stringify({ wall, wall_after: after, game: before, cmd, args, screen }) + '\n');
    res.end(JSON.stringify({ screenshot: `./screens/${screen}`, seconds_since_start: Math.round(after) }));
  } catch (e) {
    log.write(JSON.stringify({ wall, cmd, args, error: String(e.message || e) }) + '\n');
    res.end(JSON.stringify({ error: String(e.message || e) }));
  }
});
server.listen(PORT, '127.0.0.1', () => console.log(`ready ${PORT}`));
