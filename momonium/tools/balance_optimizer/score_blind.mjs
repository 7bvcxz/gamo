#!/usr/bin/env node
// Scores blind playtest runs (tools/blind_playtest/) against the frozen
// pacing targets (targets.json, Step 50): each metric per run, the median of
// the runs, its relative error or pass/fail, and the weighted aggregate of the
// primary exact targets -- the same definitions optimize.gd scores the
// simulator by. A run that never reaches a milestone counts as never: the
// median is "never" when most runs miss it, and that is a failure.
//
//   node score_blind.mjs RUN1 RUN2 RUN3 [--json out.json] [--md]
//
// Times are seconds of the session clock (from the player's first look). The
// game's own save carries its journey -- each first with its game time to the
// millisecond -- and the moment it was written; the session's snapshots carry
// the moment the clock started. Together they place each first exactly.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

function readLines(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l));
}

const median = (xs) => {
  const v = xs.map((x) => (x === null ? Infinity : x)).sort((a, b) => a - b);
  if (v.length === 0) return null;
  const m = v.length % 2 ? v[(v.length - 1) / 2] : (v[v.length / 2 - 1] + v[v.length / 2]) / 2;
  return Number.isFinite(m) ? m : null;
};

// Everything a run measured, on the session clock.
export function measure(run, startBuildings = 1, startMomos = 1) {
  const ctl = path.join(run, 'controller');
  const snaps = readLines(path.join(ctl, 'state.jsonl')).filter((s) => s.state);
  const acts = readLines(path.join(ctl, 'actions.jsonl'));
  const errors = readLines(path.join(ctl, 'errors.jsonl'));
  // Each save placed on the session clock: (saved_unix - first look) seconds.
  const saves = [];
  const seen = new Set();
  for (const s of snaps) {
    const st = s.state;
    if (st.saved_unix === null || st.saved_unix === undefined || !s.started_at) continue;
    const key = `${st.saved_unix}:${st.sim_ms}`;
    if (seen.has(key)) continue;
    seen.add(key);
    saves.push({ t: st.saved_unix - s.started_at / 1000, st });
  }
  saves.sort((a, b) => a.t - b.t);
  // Game clock -> session clock (the game runs in real time while open).
  const offsets = saves.map((s) => s.t - s.st.sim_ms / 1000).sort((a, b) => a - b);
  const offset = offsets.length ? offsets[Math.floor(offsets.length / 2)] : 0;
  const last = saves.at(-1)?.st || {};
  const journey = {};
  for (const m of last.marks || []) if (m.key) journey[m.key] = (m.at_ms ?? 0) / 1000 + offset;
  // Production income at session time t, between the saves around it.
  // (Nothing is earned before the first look: no tap has been made.)
  const points = [{ t: 0, st: { income: 0 } }, ...saves.filter((s) => s.t > 0)];
  const incomeAt = (t) => {
    for (let i = 1; i < points.length; i++) if (points[i].t >= t) return interpolate(points[i - 1], points[i], t);
    return saves.length && t - points.at(-1).t <= 20 ? points.at(-1).st.income : null;
  };
  const stateAt = (t) => {
    let best = null;
    for (const s of saves) if (s.t <= t + 15) best = s.st;
    return best;
  };
  const at600 = stateAt(600) || {};
  const meaningful = (st) => Math.max((st.level || 1) - 1, 0) + Math.max((st.buildings || []).length - startBuildings, 0) +
    (st.land_bought || 0) + Math.max((st.momos || 1) - startMomos, 0) + (st.research_levels || 0) + (st.letters || 0);
  // The longest stretch with no new income after the first Momo income (the
  // saves come every ~15 s: this is a bound at that resolution).
  let gap = null;
  const from = journey.momo_income ?? null;
  if (from !== null) {
    let lastChange = from;
    let prevIncome = null;
    gap = 0;
    for (const s of saves) {
      if (s.t < from || s.t > 600) continue;
      if (prevIncome !== null && s.st.income > prevIncome) {
        gap = Math.max(gap, s.t - lastChange);
        lastChange = s.t;
      }
      prevIncome = s.st.income;
    }
    gap = Math.round(gap);
  }
  // When the first tap began: logged since Step 50 (`issued`); before, the
  // end of the command before it -- the earliest it can have begun, so the
  // delay below is an upper bound.
  const tapIndex = acts.findIndex((a) => a.cmd === 'tap');
  const firstTap = tapIndex < 0 ? null : (acts[tapIndex].issued ?? (tapIndex > 0 ? acts[tapIndex - 1].t : 0));
  const rewards = Object.values(journey).filter((t) => firstTap !== null && t >= firstTap).sort((a, b) => a - b);
  const metrics = {
    first_reward_after_tap: firstTap !== null && rewards.length ? Math.max(rewards[0] - firstTap, 0) : null,
    income_gap: gap,
    'meaningful_at:600': saves.length ? meaningful(at600) : null,
    'momo_share_at:600': at600.jobs ? at600.momo_jobs / at600.jobs : null,
  };
  for (const s of [10, 30, 60, 120, 180, 240, 300, 360, 420, 480, 540, 600]) metrics[`income_at:${s}`] = incomeAt(s);
  return { run: path.basename(run), offset, journey, metrics, errors: errors.length, saves: saves.length,
    end: { level: last.level, money: last.money, income: last.income, buildings: (last.buildings || []).length, land: last.land_bought, momos: last.momos, research_levels: last.research_levels } };
}

function interpolate(a, b, t) {
  if (b.t === a.t) return b.st.income;
  return Math.round(a.st.income + ((b.st.income - a.st.income) * (t - a.t)) / (b.t - a.t));
}

export function observe(m, metric) {
  const [kind, arg] = metric.split(/:(.*)/s);
  if (kind === 'journey') {
    const key = arg === 'income' ? 'sale' : arg;
    return m.journey[key] ?? null;
  }
  return m.metrics[metric] ?? null;
}

export function score(runs, targets, source = 'blind') {
  const tol = targets.tolerance ?? 0.1;
  const rows = [];
  let wsum = 0;
  let werr = 0;
  let failed = 0;
  for (const t of targets.targets) {
    if (!(t.sources || ['sim', 'blind']).includes(source)) continue;
    const per = runs.map((m) => observe(m, t.metric));
    const med = median(per);
    const row = { id: t.id, metric: t.metric, kind: t.kind, target: t.target, primary: !!t.primary, runs: per, median: med };
    if (t.kind === 'exact') {
      row.error = med === null ? null : Math.abs(med - t.target) / t.target;
      row.pass = row.error !== null && row.error <= tol;
      if (t.primary) {
        wsum += t.weight ?? 1;
        werr += (t.weight ?? 1) * (row.error === null ? 1 : row.error);
      }
    } else if (t.kind === 'max') row.pass = med !== null && med <= t.target;
    else if (t.kind === 'min') row.pass = med !== null && med >= t.target;
    if (!row.pass && t.primary) failed++;
    rows.push(row);
  }
  const aggregate = wsum ? werr / wsum : 0;
  return { rows, aggregate, primary_failed: failed, pass: failed === 0 && aggregate <= tol };
}

const fmt = (v, metric) => {
  if (v === null || v === undefined) return 'never';
  if (metric.startsWith('journey') || metric === 'first_reward_after_tap' || metric === 'income_gap') {
    const s = Math.round(v);
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  }
  if (metric.startsWith('income_at')) return `$${Math.round(v)}`;
  if (metric.startsWith('momo_share')) return `${Math.round(v * 100)}%`;
  return String(Math.round(v * 10) / 10);
};

export function markdown(result) {
  const lines = ['| id | 지표 | 목표 | 실행별 | 중앙값 | 오차 | 판정 |', '|---|---|---|---|---|---|---|'];
  for (const r of result.rows) {
    const target = r.kind === 'exact' ? fmt(r.target, r.metric) : `${r.kind === 'max' ? '≤' : '≥'} ${fmt(r.target, r.metric)}`;
    lines.push(`| ${r.primary ? '**' + r.id + '**' : r.id} | ${r.metric} | ${target} | ${r.runs.map((v) => fmt(v, r.metric)).join(' / ')} | ${fmt(r.median, r.metric)} | ${r.error === undefined ? '—' : r.error === null ? '—' : (r.error * 100).toFixed(1) + '%'} | ${r.pass ? '통과' : '**실패**'} |`);
  }
  lines.push('', `가중 집계 오차 ${(result.aggregate * 100).toFixed(1)}% · primary 실패 ${result.primary_failed} → ${result.pass ? '**통과**' : '**실패**'}`);
  return lines.join('\n');
}

if (process.argv[1] && import.meta.url === new URL(`file://${path.resolve(process.argv[1])}`).href) {
  const args = process.argv.slice(2);
  const out = args.includes('--json') ? args[args.indexOf('--json') + 1] : null;
  const dirs = args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--json');
  const targets = JSON.parse(fs.readFileSync(path.join(here, 'targets.json'), 'utf8'));
  const runs = dirs.map((d) => measure(path.resolve(d)));
  const result = { runs, ...score(runs, targets) };
  if (out) fs.writeFileSync(out, JSON.stringify(result, null, 2));
  if (args.includes('--md')) console.log(markdown(result));
  else console.log(JSON.stringify({ aggregate: result.aggregate, primary_failed: result.primary_failed, pass: result.pass }, null, 2));
}
