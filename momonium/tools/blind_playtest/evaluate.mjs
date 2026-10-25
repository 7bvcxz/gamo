#!/usr/bin/env node
// Controller-side summary of blind playtest sessions (Step 45): what each
// player did and when, from the session's own logs and the game's own save
// snapshots -- never from the player's account alone.
//
//   node evaluate.mjs RUN1 RUN2 RUN3 > metrics.json
import fs from 'node:fs';
import path from 'node:path';
import { clock, idleIntervals, firstWhen } from './lib.mjs';

const SPECIALS = ['clock_tower', 'school', 'momo_monument'];

function readLines(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l));
}

export function evaluate(run) {
  const ctl = path.join(run, 'controller');
  const start = JSON.parse(fs.readFileSync(path.join(ctl, 'start.json'), 'utf8'));
  const summary = fs.existsSync(path.join(ctl, 'summary.json')) ? JSON.parse(fs.readFileSync(path.join(ctl, 'summary.json'), 'utf8')) : {};
  const acts = readLines(path.join(ctl, 'actions.jsonl'));
  const snaps = readLines(path.join(ctl, 'state.jsonl'));
  const errors = readLines(path.join(ctl, 'errors.jsonl'));
  const first = (cmd) => (acts.find((a) => a.cmd === cmd) || {}).t ?? null;
  const last = snaps.filter((s) => s.state).at(-1)?.state || null;
  const at = (t) => (t === null ? '—' : clock(t));
  const m = {
    run: path.basename(run),
    version: start.version,
    load_ms: start.load_ms,
    ended: summary.reason || 'unfinished',
    elapsed: at(summary.elapsed_s ?? null),
    actions: { taps: acts.filter((a) => a.cmd === 'tap').length, drags: acts.filter((a) => a.cmd === 'drag').length, waits: acts.filter((a) => a.cmd === 'wait').length, looks: acts.filter((a) => a.cmd === 'look').length, notes: acts.filter((a) => a.cmd === 'note').length },
    first_tap: at(first('tap')),
    first_build: at(firstWhen(snaps, (s) => s.buildings.length > 0)),
    first_crop: at(firstWhen(snaps, (s) => s.crops > 0)),
    first_land: at(firstWhen(snaps, (s) => s.land_bought > 0)),
    first_assigned: at(firstWhen(snaps, (s) => s.assigned > 0)),
    first_hire: at(firstWhen(snaps, (s) => s.momos > 1)),
    first_research: at(firstWhen(snaps, (s) => s.research.length > 0)),
    first_special: at(firstWhen(snaps, (s) => s.buildings.some((b) => SPECIALS.includes(b)))),
    level_ups: snaps.filter((s, i) => i > 0 && s.state && snaps[i - 1].state && s.state.level > snaps[i - 1].state.level).map((s) => `${clock(s.t)}→Lv${s.state.level}`),
    end_state: last && { money: last.money, level: last.level, land: last.land, buildings: last.buildings, momos: last.momos, assigned: last.assigned, research: last.research.length, tier: last.tier, crops: last.crops },
    idle: idleIntervals(acts, 30).map((g) => `${clock(g.from)}–${clock(g.to)} (${g.gap}s)`),
    errors: errors.length,
    notes: acts.filter((a) => a.cmd === 'note').map((a) => `${a.at} ${a.text}`),
  };
  return m;
}

if (process.argv[1] && import.meta.url === new URL(`file://${path.resolve(process.argv[1])}`).href) {
  const runs = process.argv.slice(2).map((r) => evaluate(path.resolve(r)));
  console.log(JSON.stringify(runs, null, 2));
}
