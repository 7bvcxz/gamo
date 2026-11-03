// Side-by-side numbers for blind sessions grouped by variant (Step 11). Only
// after the sessions: reads each session's action log, the game's own events
// and summary. Everything is measured over the first 180 s of game time so
// sessions of different lengths compare equally.
//   node windup/tools/blind/compare.mjs <out.json> <variant>=<session dir>[,<dir>...] ...
// Also copies the screenshot nearest to game 0/30/60/180 s of each session to
// <out dir>/frames/<session>_<t>.jpg.
import fs from 'node:fs';
import path from 'node:path';

const [out, ...groups] = process.argv.slice(2);
// World changes a player can see. In A every tap also logs a `release` of 1;
// only a held spring let go (3+ turns stored) is the visible whoosh.
const CHANGE = new Set(['doll_awake', 'doll_ready', 'stage', 'help', 'kick', 'release']);
const seen = (e) => CHANGE.has(e.ev) && (e.ev !== 'release' || (e.energy_added || 0) >= 3);
const jl = (f) => fs.existsSync(f) ? fs.readFileSync(f, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)) : [];
const framesDir = path.join(path.dirname(out), 'frames');
fs.mkdirSync(framesDir, { recursive: true });

function session(dir) {
  const A = jl(path.join(dir, 'actions.jsonl'));
  const E = jl(path.join(dir, 'game_events.jsonl'));
  const S = JSON.parse(fs.readFileSync(path.join(dir, 'summary.json'), 'utf8'));
  const inside = E.filter((e) => e.t <= 180);
  const wakes = inside.filter((e) => e.ev === 'doll_awake').map((e) => e.t);
  const bins = new Set(inside.filter(seen).map((e) => Math.floor(e.t / 10)));
  const inputs = A.filter((a) => ['click', 'hold', 'double_click', 'drag', 'key', 'hold_key'].includes(a.cmd) && a.game <= 180);
  const firstChange = inside.find(seen);
  const lastBeforeEnd = A.filter((a) => a.cmd !== 'end').pop();
  // Screens nearest to game 0/30/60/180 (a screenshot is taken after its command).
  const shots = A.filter((a) => a.screen && a.game != null).map((a) => ({ t: a.game + (a.wall_after - a.wall), screen: a.screen.replace('.png', '.jpg') }));
  const frames = {};
  for (const t of [0, 30, 60, 180]) {
    const best = shots.reduce((b, s) => (Math.abs(s.t - t) < Math.abs(b.t - t) ? s : b), shots[0]);
    const name = `${path.basename(dir)}_${t}.jpg`;
    fs.copyFileSync(path.join(dir, 'screens', best.screen), path.join(framesDir, name));
    frames[t] = { file: `frames/${name}`, game_t: +best.t.toFixed(1) };
  }
  return {
    session: path.basename(dir), build: S.build,
    first_input_wall_s: S.first_key_input_wall_s, first_wind_s: S.first_wind_game_s,
    first_doll_s: wakes[0] ?? null, first_change_s: firstChange ? firstChange.t : null,
    awakenings_180: wakes.length, dolls_at: { 10: wakes.filter((t) => t <= 10).length, 30: wakes.filter((t) => t <= 30).length, 60: wakes.filter((t) => t <= 60).length, 180: wakes.length },
    change_bins_pct_0_180: Math.round(bins.size / 18 * 100),
    inputs_180: inputs.length, holds: A.filter((a) => a.cmd === 'hold' || a.cmd === 'hold_key').length,
    spring_releases_180: inside.filter((e) => e.ev === 'release' && (e.energy_added || 0) >= 3).length, kicks_180: inside.filter((e) => e.ev === 'kick').length,
    off_key_clicks: S.off_key_inputs.length, idle20_hints: E.filter((e) => e.ev === 'hint' && e.reason === 'idle20').length,
    played_until_wall_s: lastBeforeEnd ? +(lastBeforeEnd.wall_after ?? lastBeforeEnd.wall).toFixed(1) : null,
    milestones: { input_by_10: S.first_key_input_wall_s != null && S.first_key_input_wall_s <= 10, doll_by_30: (wakes[0] ?? 999) <= 30, change_by_60: (firstChange ? firstChange.t : 999) <= 60, past_180: (lastBeforeEnd?.wall_after ?? 0) >= 180 },
    narration_mentions: S.narration_mentions, frames,
  };
}

const result = {};
for (const g of groups) {
  const [variant, list] = g.split('=');
  result[variant] = list.split(',').map(session);
}
fs.writeFileSync(out, JSON.stringify(result, null, 1) + '\n');
for (const [v, ss] of Object.entries(result)) {
  const col = (k) => ss.map((s) => s[k]).join(' / ');
  console.log(`${v}: first doll ${col('first_doll_s')} | awakenings@180 ${col('awakenings_180')} | change bins ${col('change_bins_pct_0_180')}% | inputs ${col('inputs_180')} | holds ${col('holds')} | spring releases ${col('spring_releases_180')} | kicks ${col('kicks_180')}`);
}
