// The harness against a real build (the local docs/ export): a short session
// opens the game, the player looks, taps, drags, waits and notes through
// play.mjs only, the controller logs and snapshots, and the session ends by
// itself when its time is up. Slow (a real browser): ~1 minute.
//   node --test momonium/tools/blind_playtest/test/session.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const tool = path.resolve(here, '..');
const docs = path.resolve(here, '../../../../docs');

test('a short blind session runs end to end', { timeout: 240_000 }, async () => {
  const port = 18000 + Math.floor(Math.random() * 900);
  const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1', '--directory', docs], { stdio: 'ignore' });
  const run = fs.mkdtempSync(path.join(os.tmpdir(), 'blind-'));
  try {
    const session = spawn('node', [path.join(tool, 'session.mjs'), '--run', run, '--url', `http://127.0.0.1:${port}/momonium/`, '--minutes', '0.5'], { stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    session.stdout.on('data', (d) => { out += d; });
    const ended = new Promise((resolve) => session.on('exit', resolve));
    for (let i = 0; i < 300 && !fs.existsSync(path.join(run, 'port')); i++) await new Promise((r) => setTimeout(r, 500));
    assert.ok(fs.existsSync(path.join(run, 'port')), 'the game opened');
    const play = (...args) => execFileSync('node', [path.join(tool, 'play.mjs'), run, ...args], { encoding: 'utf8' });
    assert.match(play('status'), /time 00:00, 00:30 left/);
    assert.match(play('look'), /screen: .*player\/shots\/001\.png/);
    assert.match(play('tap', '300', '700'), /screen: .*002\.png/);
    assert.match(play('drag', '300', '700', '200', '600'), /screen: /);
    assert.match(play('note', 'I see an island'), /time /);
    assert.match(play('wait', '2'), /screen: /);
    assert.throws(() => play('eval', 'window.momonium'), 'nothing but the six commands');
    const code = await ended;
    assert.equal(code, 0, `the session ended by itself (${out})`);
    assert.match(play('look'), /Time is up/, 'and refuses play after');
    const summary = JSON.parse(fs.readFileSync(path.join(run, 'controller', 'summary.json'), 'utf8'));
    assert.equal(summary.reason, 'time');
    assert.deepEqual([summary.counts.tap, summary.counts.drag, summary.counts.note, summary.counts.wait], [1, 1, 1, 1]);
    const log = fs.readFileSync(path.join(run, 'controller', 'actions.jsonl'), 'utf8').trim().split('\n').map((l) => JSON.parse(l));
    assert.deepEqual(log.map((e) => e.cmd), ['look', 'tap', 'drag', 'note', 'wait']);
    assert.ok(log.every((e, i) => i === 0 || e.t >= log[i - 1].t), 'timestamps in order');
    const start = JSON.parse(fs.readFileSync(path.join(run, 'controller', 'start.json'), 'utf8'));
    assert.match(start.version, /^\d+\.\d+\.\d+$/, 'the build version is recorded');
    assert.deepEqual(fs.readdirSync(path.join(run, 'player')), ['shots'], 'the player folder holds only its screenshots');
  } finally {
    server.kill();
    fs.rmSync(run, { recursive: true, force: true });
  }
});
