#!/usr/bin/env node
// The blind player's only way into the game (Step 45):
//
//   node play.mjs RUN look              see the screen (prints a screenshot path)
//   node play.mjs RUN tap X Y           touch the screen at (X, Y) in screenshot pixels
//   node play.mjs RUN drag X1 Y1 X2 Y2  slide a finger from one point to another
//   node play.mjs RUN wait S            let S seconds pass (at most 30), then look
//   node play.mjs RUN note TEXT         think aloud: what you see, expect, feel
//   node play.mjs RUN status            how much of the ten minutes is left
//
// Every action is followed by a fresh screenshot of what happened.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { parseCommand } from './lib.mjs';

const [run, ...rest] = process.argv.slice(2);
if (!run) {
  console.error('usage: node play.mjs RUN look | tap X Y | drag X1 Y1 X2 Y2 | wait S | note TEXT | status');
  process.exit(2);
}
const parsed = parseCommand(rest);
if (parsed.error) {
  console.error(parsed.error);
  process.exit(2);
}
const portFile = path.join(path.resolve(run), 'port');
if (!fs.existsSync(portFile)) {
  console.error('the game is not open yet; try again in a moment');
  process.exit(1);
}
const port = Number(fs.readFileSync(portFile, 'utf8'));
const body = JSON.stringify({ cmd: parsed.cmd, args: parsed.args });
const req = http.request({ host: '127.0.0.1', port, method: 'POST', path: '/', headers: { 'content-type': 'application/json' }, timeout: 120_000 }, (res) => {
  let data = '';
  res.on('data', (c) => { data += c; });
  res.on('end', () => {
    const out = JSON.parse(data || '{}');
    if (out.over) {
      console.log(out.message);
      return;
    }
    if (out.error) {
      console.error(out.error);
      process.exitCode = 1;
      return;
    }
    const parts = [];
    if (out.screen) parts.push(`screen: ${out.screen}`);
    if (out.time) parts.push(`time ${out.time}, ${out.left} left`);
    console.log(parts.join('  ') || 'ok');
  });
});
req.on('error', () => {
  console.log('Time is up: the ten minutes are over.');
});
req.end(body);
