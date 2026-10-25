// Unit tests of the blind playtest harness's pure helpers:
//   node --test momonium/tools/blind_playtest/test/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { clock, SessionClock, toCss, parseCommand, logLine, snapshotFromSave, idleIntervals, firstWhen, MAX_WAIT_SECONDS } from '../lib.mjs';

test('clock formats seconds as mm:ss', () => {
  assert.equal(clock(0), '00:00');
  assert.equal(clock(61.9), '01:01');
  assert.equal(clock(600), '10:00');
  assert.equal(clock(-3), '00:00');
});

test('the session clock starts at the first look and runs ten minutes', () => {
  let now = 1000;
  const c = new SessionClock(10, () => now);
  assert.equal(c.started, false);
  assert.equal(c.elapsed(), 0);
  assert.equal(c.remaining(), 600);
  now = 5000;
  c.start();
  now = 5000 + 125_000;
  assert.equal(c.elapsed(), 125);
  assert.equal(c.remaining(), 475);
  c.start();
  assert.equal(c.elapsed(), 125, 'a second start does not restart it');
  now = 5000 + 600_000;
  assert.equal(c.over(), true);
});

test('screenshot pixels become CSS pixels, inside the screen', () => {
  assert.deepEqual(toCss(300, 645, 1.5, { width: 400, height: 860 }), { x: 200, y: 430 });
  assert.deepEqual(toCss(-10, 5000, 1.5, { width: 400, height: 860 }), { x: 0, y: 859 });
});

test('commands are checked before they reach the game', () => {
  assert.deepEqual(parseCommand(['tap', '10', '20']), { cmd: 'tap', args: { x: 10, y: 20 } });
  assert.ok(parseCommand(['tap', '10']).error);
  assert.ok(parseCommand(['tap', 'a', 'b']).error);
  assert.deepEqual(parseCommand(['drag', '1', '2', '3', '4']).args, { x1: 1, y1: 2, x2: 3, y2: 4 });
  assert.equal(parseCommand(['wait', '90']).args.s, MAX_WAIT_SECONDS, 'a wait is at most 30 s');
  assert.ok(parseCommand(['wait', '0']).error);
  assert.equal(parseCommand(['note', 'I', 'see', 'a', 'bunny']).args.text, 'I see a bunny');
  assert.ok(parseCommand(['cheat']).error, 'nothing else exists');
  assert.ok(parseCommand(['eval', 'window.momonium']).error, 'no page scripting');
});

test('log lines carry the session time', () => {
  const line = JSON.parse(logLine(75.26, 'tap', { x: 1, y: 2 }, { shot: '004.png' }));
  assert.deepEqual(line, { t: 75.3, at: '01:15', cmd: 'tap', x: 1, y: 2, shot: '004.png' });
});

test('the controller reads the game save, the player never does', () => {
  const state = { clock: { now_ms: 61000 }, systems: {
    economy: { money: 42 }, progression: { level: 3, exp: 7 }, world: { land: [[0, 0], [1, 0], [0, 1], [1, 1], [2, 0]] },
    land: { purchases: [{}] }, buildings: { buildings: [{ type: 'farm' }, { type: 'mine' }] },
    momo: { momos: [{ assigned: 1 }, { assigned: 0 }] }, research: { completed: { a: 0 } }, tiers: { tier: 1 },
    inventory: { produced: { crop: 9 } }, journey: { marks: [{ id: 'first_build', play_ms: 9000 }] },
  } };
  const s = snapshotFromSave(JSON.stringify({ format: 2, state: JSON.stringify(state) }));
  assert.equal(s.money, 42);
  assert.equal(s.level, 3);
  assert.equal(s.land, 5);
  assert.equal(s.land_bought, 1);
  assert.deepEqual(s.buildings, ['farm', 'mine']);
  assert.equal(s.momos, 2);
  assert.equal(s.assigned, 1);
  assert.deepEqual(s.research, ['a']);
  assert.equal(s.tier, 1);
  assert.equal(s.crops, 9);
  assert.equal(s.marks[0].id, 'first_build');
  assert.equal(snapshotFromSave(''), null);
  assert.equal(snapshotFromSave('not json'), null);
});

test('idle intervals count gaps between actions, not looks', () => {
  const log = [{ t: 2, cmd: 'tap' }, { t: 20, cmd: 'look' }, { t: 50, cmd: 'tap' }, { t: 60, cmd: 'drag' }, { t: 130, cmd: 'tap' }];
  assert.deepEqual(idleIntervals(log, 30), [{ from: 2, to: 50, gap: 48 }, { from: 60, to: 130, gap: 70 }]);
});

test('first moment a snapshot shows something', () => {
  const snaps = [{ t: 10, state: { buildings: [] } }, { t: 20, state: null }, { t: 30, state: { buildings: ['farm'] } }];
  assert.equal(firstWhen(snaps, (s) => s.buildings.length > 0), 30);
  assert.equal(firstWhen(snaps, (s) => s.buildings.includes('mine')), null);
});
