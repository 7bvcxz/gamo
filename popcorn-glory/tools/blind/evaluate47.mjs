#!/usr/bin/env node
// Step 47: the evaluator's table for blind FACTORY runs -- observations, not opinions. From each
// run's controller/ folder (timed actions, the game's state every 5 s, the game's own log):
//   the player's commands and how the time went (acting vs waiting), first action;
//   the issue's milestones on the player's clock: first perfect, first sale, first machine built,
//   first upgrade of any kind, first recipe change, the paper opened, a contest entered;
//   purchases and the time between them; money, revenue and running costs over the session;
//   refused presses and repeated taps on the same spot; the bottleneck the model names; the
//   longest stretch with no sale and with no purchase.
//   node evaluate47.mjs RUN [RUN ...]  ->  Markdown on stdout, RUN/controller/metrics47.json
import fs from 'node:fs';
import path from 'node:path';

const round = (v, d = 1) => (v === null || v === undefined ? null : Math.round(v * 10 ** d) / 10 ** d);
const tables = [];
for (const run of process.argv.slice(2)) {
  const ctl = path.join(path.resolve(run), 'controller');
  const read = (f) => (fs.existsSync(path.join(ctl, f)) ? fs.readFileSync(path.join(ctl, f), 'utf8') : '');
  const jsonl = (f) => read(f).split('\n').filter(Boolean).map((l) => JSON.parse(l));
  const actions = jsonl('actions.jsonl');
  const states = jsonl('state.jsonl').filter((x) => x.exp === 'factory' && x.run);
  const start = JSON.parse(read('start.json') || '{}');
  const summary = JSON.parse(read('summary.json') || '{}');
  // The factory's own log: the newest of game_log_factory*.json (a restart keeps the old one).
  const logs = fs.readdirSync(ctl).filter((f) => /^game_log_factory(_\d+)?\.json$/.test(f));
  const lines = logs.flatMap((f) => JSON.parse(read(f)).lines ?? []);
  const seen = new Set();
  const uniq = lines.filter((l) => { const k = `${l.t}|${l.type}|${JSON.stringify(l.data)}`; if (seen.has(k)) return false; seen.add(k); return true; });
  uniq.sort((a, b) => a.t - b.t);
  // Game clock -> player clock through the 5-second samples (as evaluate.mjs does).
  const samples = states.filter((x) => typeof x.clock_ms === 'number').map((x) => [x.clock_ms / 1000, x.t]);
  const toPlayer = (gameMs) => {
    if (gameMs === undefined || gameMs === null || samples.length < 2) return null;
    const g = gameMs / 1000;
    let i = samples.findIndex((x) => x[0] >= g);
    if (i < 0) i = samples.length - 1;
    if (i === 0) i = 1;
    const [g0, w0] = samples[i - 1]; const [g1, w1] = samples[i];
    return round(g1 > g0 ? w0 + (g - g0) * (w1 - w0) / (g1 - g0) : w0);
  };
  const startMs = samples.length ? samples[0][0] * 1000 : 0;
  const during = uniq.filter((l) => l.t >= startMs - 1000);   // a prepared save's history is not this player's
  const first = (pred) => { const l = during.find(pred); return l ? toPlayer(l.t) : null; };
  const all = (pred) => during.filter(pred);
  const purchases = all((l) => ['upgrade', 'station_upgrade', 'machine_built', 'line_built', 'machine_upgraded'].includes(l.type));
  const ptimes = purchases.map((l) => toPlayer(l.t)).filter((v) => v !== null);
  const gapsBetween = ptimes.slice(1).map((t, i) => round(t - ptimes[i]));
  const sales = all((l) => l.type === 'sale').map((l) => toPlayer(l.t)).filter((v) => v !== null);
  const longest = (times, end) => { let best = 0; let prev = 0; for (const t of [...times, end]) { best = Math.max(best, t - prev); prev = t; } return round(best); };
  const end = summary.elapsed_s ?? (states.at(-1)?.t ?? 0);
  // Taps within 25 px of the previous tap, with nothing else between: a player trying again.
  const taps = actions.filter((a) => a.cmd === 'tap');
  let repeats = 0;
  for (let i = 1; i < actions.length; i++) {
    const a = actions[i]; const b = actions[i - 1];
    if (a.cmd === 'tap' && b.cmd === 'tap' && Math.hypot(a.args.x - b.args.x, a.args.y - b.args.y) < 25) repeats++;
  }
  const waitS = actions.filter((a) => a.cmd === 'wait').reduce((s, a) => s + Math.min(30, Number(a.args.s) || 0), 0);
  const s0 = states[0]?.run; const s1 = states.at(-1)?.run;
  const cost = (r) => (r ? (r.stats.upkeep_paid ?? 0) + (r.stats.kernels_paid ?? 0) + (r.stats.oil_paid ?? 0) : 0);
  const bottlenecks = states.reduce((o, x) => ((o[x.run.bottleneck ?? 'none'] = (o[x.run.bottleneck ?? 'none'] ?? 0) + 1), o), {});
  const newsOpen = states.find((x) => x.view && x.view.news_open);
  const outcomes = all((l) => l.type === 'outcome').reduce((o, l) => ((o[l.data.kind] = (o[l.data.kind] ?? 0) + 1), o), {});
  const m = {
    run: path.basename(path.resolve(run)), version: start.version, url_hash: (start.url ?? '').split('#')[1] ?? '', prepared_save: start.prepared_save ? path.basename(start.prepared_save.file) : null,
    seconds: summary.elapsed_s ?? null, commands: actions.length, taps: taps.length, holds: actions.filter((a) => a.cmd === 'hold').length,
    drags: actions.filter((a) => ['drag', 'path'].includes(a.cmd)).length, waits: actions.filter((a) => a.cmd === 'wait').length, wait_s: round(waitS),
    notes: actions.filter((a) => a.cmd === 'note').length, looks: actions.filter((a) => a.cmd === 'look').length,
    first_action_s: actions.find((a) => ['tap', 'hold', 'drag', 'path'].includes(a.cmd))?.issued ?? null,
    hand_presses: all((l) => l.type === 'input' && l.data.kind === 'press').length, outcomes,
    first_perfect_s: first((l) => l.type === 'outcome' && l.data.kind === 'perfect'),
    first_sale_s: first((l) => l.type === 'sale'), sales: sales.length,
    first_machine_s: first((l) => l.type === 'machine_built'), machines_built: all((l) => l.type === 'machine_built').length,
    first_purchase_s: ptimes[0] ?? null, purchases: purchases.length, purchase_kinds: purchases.reduce((o, l) => ((o[l.type] = (o[l.type] ?? 0) + 1), o), {}),
    seconds_between_purchases: gapsBetween, longest_without_purchase_s: longest(ptimes, end), longest_without_sale_s: longest(sales, end),
    first_recipe_change_s: first((l) => l.type === 'flavor_set'), recipe_changes: all((l) => l.type === 'flavor_set').length,
    paper_opened_s: newsOpen ? newsOpen.t : null, news_events: all((l) => l.type === 'news_start').length,
    first_contest_entry_s: first((l) => l.type === 'contest_start'), contests_entered: all((l) => l.type === 'contest_start').length,
    refused: all((l) => ['denied', 'refused'].includes(l.type) || (l.type === 'buy' && l.data && l.data.ok === false)).length,
    repeated_taps: repeats,
    money: [s0?.money ?? null, s1?.money ?? null], machines: [s0?.machines?.length ?? null, s1?.machines?.length ?? null],
    revenue_in_session: s0 && s1 ? (s1.stats.revenue ?? 0) - (s0.stats.revenue ?? 0) : null,
    running_costs_in_session: s0 && s1 ? cost(s1) - cost(s0) : null,
    sold_in_session: s0 && s1 ? (s1.stats.sold ?? 0) - (s0.stats.sold ?? 0) : null,
    bottleneck_samples: bottlenecks, sign_tier: [s0?.sign_tier ?? null, s1?.sign_tier ?? null], level: [s0?.level ?? null, s1?.level ?? null],
    page_errors: read('errors.jsonl').split('\n').filter(Boolean).length,
  };
  m.profit_in_session = m.revenue_in_session !== null ? m.revenue_in_session - m.running_costs_in_session : null;
  fs.writeFileSync(path.join(ctl, 'metrics47.json'), JSON.stringify(m, null, 2));
  tables.push(m);
}
const keys = Object.keys(tables[0] ?? {});
console.log(`| metric | ${tables.map((t) => t.run).join(' | ')} |`);
console.log(`|---|${tables.map(() => '---').join('|')}|`);
for (const k of keys.filter((x) => x !== 'run')) console.log(`| ${k} | ${tables.map((t) => (typeof t[k] === 'object' && t[k] !== null ? JSON.stringify(t[k]) : String(t[k]))).join(' | ')} |`);
