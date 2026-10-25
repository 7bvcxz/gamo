// evaluate.mjs on a made-up session folder: milestones come from the game's
// own save snapshots and the timed log, never from the player's own account.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { evaluate } from '../evaluate.mjs';

test('milestones, actions, idle gaps and notes from a session folder', () => {
  const run = fs.mkdtempSync(path.join(os.tmpdir(), 'blind-eval-'));
  const ctl = path.join(run, 'controller');
  fs.mkdirSync(ctl, { recursive: true });
  fs.writeFileSync(path.join(ctl, 'start.json'), JSON.stringify({ version: '9.9.9', load_ms: 5000 }));
  fs.writeFileSync(path.join(ctl, 'summary.json'), JSON.stringify({ reason: 'time', elapsed_s: 601 }));
  const acts = [
    { t: 0, at: '00:00', cmd: 'look' }, { t: 6, at: '00:06', cmd: 'tap' }, { t: 9, at: '00:09', cmd: 'note', text: 'a bunny!' },
    { t: 12, at: '00:12', cmd: 'tap' }, { t: 80, at: '01:20', cmd: 'drag' }, { t: 85, at: '01:25', cmd: 'wait', s: 10 },
  ];
  fs.writeFileSync(path.join(ctl, 'actions.jsonl'), acts.map((a) => JSON.stringify(a)).join('\n') + '\n');
  const base = { money: 10, level: 1, land: 4, land_bought: 0, buildings: [], momos: 1, assigned: 0, research: [], tier: 0, crops: 0 };
  const snaps = [
    { t: 10, state: base },
    { t: 20, state: { ...base, buildings: ['farm'] } },
    { t: 40, state: { ...base, buildings: ['farm'], crops: 1, level: 2 } },
    { t: 60, state: { ...base, buildings: ['farm', 'clock_tower'], land_bought: 1, crops: 1, level: 2 } },
  ];
  fs.writeFileSync(path.join(ctl, 'state.jsonl'), snaps.map((s) => JSON.stringify(s)).join('\n') + '\n');
  const m = evaluate(run);
  assert.equal(m.version, '9.9.9');
  assert.equal(m.ended, 'time');
  assert.equal(m.elapsed, '10:01');
  assert.deepEqual(m.actions, { taps: 2, drags: 1, waits: 1, looks: 1, notes: 1 });
  assert.equal(m.first_tap, '00:06');
  assert.equal(m.first_build, '00:20');
  assert.equal(m.first_crop, '00:40');
  assert.equal(m.first_land, '01:00');
  assert.equal(m.first_special, '01:00');
  assert.equal(m.first_research, '—');
  assert.deepEqual(m.level_ups, ['00:40→Lv2']);
  assert.deepEqual(m.idle, ['00:12–01:20 (68s)']);
  assert.deepEqual(m.notes, ['00:09 a bunny!']);
  assert.equal(m.errors, 0);
  fs.rmSync(run, { recursive: true, force: true });
});
