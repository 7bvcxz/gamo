#!/usr/bin/env node
// The evaluator's table for blind runs (Popcorn Step 08): from each run's
// controller/ folder -- the timed actions, the game's own log and state --
// what the player did and what the game recorded. Observations, not opinions.
//   node evaluate.mjs RUN [RUN ...]  ->  prints Markdown, writes RUN/controller/metrics.json
import fs from 'node:fs';
import path from 'node:path';

const rows = [];
for (const run of process.argv.slice(2)) {
  const ctl = path.join(path.resolve(run), 'controller');
  const read = (f) => (fs.existsSync(path.join(ctl, f)) ? fs.readFileSync(path.join(ctl, f), 'utf8') : '');
  const actions = read('actions.jsonl').split('\n').filter(Boolean).map((l) => JSON.parse(l));
  const start = JSON.parse(read('start.json') || '{}');
  const summary = JSON.parse(read('summary.json') || '{}');
  const log = JSON.parse(read('game_log.json') || '{}');
  const errors = read('errors.jsonl').split('\n').filter(Boolean);
  const by = (c) => actions.filter((a) => a.cmd === c);
  const firstAct = actions.find((a) => ['tap', 'hold', 'drag'].includes(a.cmd));
  const gaps = [];
  for (let i = 1; i < actions.length; i++) gaps.push(actions[i].issued - actions[i - 1].t);
  const lines = log.lines ?? [];
  // The game's clock started at page load; the player's at the first command.
  // The two do not run at the same rate on a starved machine: the game's
  // active clock caps a slow frame, so it can fall behind the wall clock
  // (Step 09 round 3: 130 game seconds in 179 wall seconds). Game times are
  // mapped through the controller's 5-second samples (wall t, game clock_ms),
  // interpolated, not by one offset -- one offset put a purchase made at 2:07
  // at 1:22.
  const firstInputGame = lines.find((l) => l.type === 'input')?.t;
  const ms = log.summary?.milestones ?? {};
  const samples = read('state.jsonl').split('\n').filter(Boolean).map((l) => JSON.parse(l))
    .filter((x) => typeof x.clock_ms === 'number').map((x) => [x.clock_ms / 1000, x.t]);
  const offset = firstInputGame !== undefined && firstAct ? firstInputGame / 1000 - firstAct.issued : null;
  const toPlayer = (gameMs) => {
    if (gameMs === undefined || gameMs === null) return null;
    const g = gameMs / 1000;
    if (samples.length >= 2) {
      let i = samples.findIndex((x) => x[0] >= g);
      if (i <= 0) i = i === 0 ? 1 : samples.length - 1;
      const [g0, w0] = samples[i - 1]; const [g1, w1] = samples[i];
      const w = g1 > g0 ? w0 + (g - g0) * (w1 - w0) / (g1 - g0) : w0;
      return Math.round(w * 10) / 10;
    }
    return offset === null ? null : Math.round((g - offset) * 10) / 10;
  };
  const clockRate = samples.length >= 2
    ? Math.round(((samples.at(-1)[0] - samples[0][0]) / Math.max(1e-6, samples.at(-1)[1] - samples[0][1])) * 100) / 100 : null;
  const m = {
    run: path.basename(path.resolve(run)), url_variant: (start.url ?? '').split('#')[1] ?? '', version: start.version,
    seconds: summary.elapsed_s, commands: actions.length, taps: by('tap').length, holds: by('hold').length, drags: by('drag').length,
    waits: by('wait').length, notes: by('note').length, looks: by('look').length,
    first_action_s: firstAct?.issued ?? null,
    game_inputs: log.summary?.inputs ?? null,
    first_earn_s: toPlayer(ms.first_earn), first_upgrade_s: toPlayer(ms.first_upgrade),
    upgrades: (log.summary?.upgrades ?? []).length, level: log.summary?.level ?? null, earned: log.summary?.earned ?? null,
    game_clock_rate: clockRate,
    longest_gap_between_commands_s: gaps.length ? Math.round(Math.max(...gaps) * 10) / 10 : null,
    page_errors: errors.length,
    outcomes: lines.filter((l) => l.type === 'outcome').reduce((o, l) => ((o[l.data.kind] = (o[l.data.kind] ?? 0) + 1), o), {}),
    refused: lines.filter((l) => l.type === 'refused').length,
  };
  fs.writeFileSync(path.join(ctl, 'metrics.json'), JSON.stringify(m, null, 2));
  rows.push(m);
}
const cols = ['run', 'url_variant', 'version', 'seconds', 'commands', 'taps', 'holds', 'waits', 'notes', 'first_action_s', 'game_inputs', 'first_earn_s', 'first_upgrade_s', 'upgrades', 'level', 'game_clock_rate', 'longest_gap_between_commands_s', 'refused', 'page_errors'];
console.log(`| ${cols.join(' | ')} | outcomes |\n|${cols.map(() => '---').join('|')}|---|`);
for (const r of rows) console.log(`| ${cols.map((c) => r[c] ?? '–').join(' | ')} | ${JSON.stringify(r.outcomes)} |`);
