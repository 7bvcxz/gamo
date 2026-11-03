#!/usr/bin/env node
// The blind player's only hands and eyes (Popcorn Step 08).
//   node play.mjs RUN look | tap X Y | hold X Y S | drag X1 Y1 X2 Y2 | wait S | note "TEXT" | status
// Coordinates are pixels of the screenshot (600 x 1290). Prints the result and,
// for actions, the path of the new screenshot to open with the Read tool.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';

const [run, cmd, ...rest] = process.argv.slice(2);
const usage = 'usage: play.mjs RUN look | tap X Y | hold X Y S | drag X1 Y1 X2 Y2 | wait S | note "TEXT" | status';
if (!run || !cmd) { console.error(usage); process.exit(2); }
const n = (v) => Number(v);
const args = { look: {}, status: {}, tap: { x: n(rest[0]), y: n(rest[1]) }, hold: { x: n(rest[0]), y: n(rest[1]), s: n(rest[2]) },
  drag: { x1: n(rest[0]), y1: n(rest[1]), x2: n(rest[2]), y2: n(rest[3]) }, wait: { s: n(rest[0]) }, note: { text: rest.join(' ') } }[cmd];
if (!args) { console.error(usage); process.exit(2); }
const port = Number(fs.readFileSync(path.join(path.resolve(run), 'port'), 'utf8'));
const req = http.request({ host: '127.0.0.1', port, method: 'POST', path: '/' }, (res) => {
  let b = '';
  res.on('data', (c) => { b += c; });
  res.on('end', () => {
    const o = JSON.parse(b);
    if (o.over) { console.log(o.message); return; }
    if (o.error) { console.log(`error: ${o.error}`); return; }
    if (cmd === 'status') { console.log(`time ${o.time}, left ${o.left}`); return; }
    const held = o.held_screen ? `\nscreenshot while your finger was still down: ${o.held_screen}` : '';
    console.log(`time ${o.time}, left ${o.left}${held}${o.screen ? `\nscreenshot: ${o.screen}` : ''}`);
  });
});
req.on('error', () => console.log('Time is up: the session has closed.'));
req.end(JSON.stringify({ cmd, args }));
