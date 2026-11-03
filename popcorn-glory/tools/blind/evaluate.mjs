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
  const firstInputGame = lines.find((l) => l.type === 'input')?.t;
  const ms = log.summary?.milestones ?? {};
  const offset = firstInputGame !== undefined && firstAct ? firstInputGame / 1000 - firstAct.issued : null;
  const toPlayer = (gameMs) => (gameMs === undefined || offset === null ? null : Math.round((gameMs / 1000 - offset) * 10) / 10);
  const m = {
    run: path.basename(path.resolve(run)), url_variant: (start.url ?? '').split('#')[1] ?? '', version: start.version,
    seconds: summary.elapsed_s, commands: actions.length, taps: by('tap').length, holds: by('hold').length, drags: by('drag').length,
    waits: by('wait').length, notes: by('note').length, looks: by('look').length,
    first_action_s: firstAct?.issued ?? null,
    game_inputs: log.summary?.inputs ?? null,
    first_earn_s: toPlayer(ms.first_earn), first_upgrade_s: toPlayer(ms.first_upgrade),
    upgrades: (log.summary?.upgrades ?? []).length, level: log.summary?.level ?? null, earned: log.summary?.earned ?? null,
    longest_gap_between_commands_s: gaps.length ? Math.round(Math.max(...gaps) * 10) / 10 : null,
    page_errors: errors.length,
    outcomes: lines.filter((l) => l.type === 'outcome').reduce((o, l) => ((o[l.data.kind] = (o[l.data.kind] ?? 0) + 1), o), {}),
    refused: lines.filter((l) => l.type === 'refused').length,
  };
  fs.writeFileSync(path.join(ctl, 'metrics.json'), JSON.stringify(m, null, 2));
  rows.push(m);
}
const cols = ['run', 'url_variant', 'version', 'seconds', 'commands', 'taps', 'holds', 'waits', 'notes', 'first_action_s', 'game_inputs', 'first_earn_s', 'first_upgrade_s', 'upgrades', 'level', 'longest_gap_between_commands_s', 'refused', 'page_errors'];
console.log(`| ${cols.join(' | ')} | outcomes |\n|${cols.map(() => '---').join('|')}|---|`);
for (const r of rows) console.log(`| ${cols.map((c) => r[c] ?? '–').join(' | ')} | ${JSON.stringify(r.outcomes)} |`);
