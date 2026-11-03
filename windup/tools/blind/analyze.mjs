// Post-session analysis of one blind play (Step 09). Run only after the session:
// it correlates the recorder's action log with the game's own events, which the
// player never saw.
//   node windup/tools/blind/analyze.mjs <session dir>   -> summary.json + summary.md in that dir
import fs from 'node:fs';
import path from 'node:path';

const dir = process.argv[2];
const jl = (f) => fs.existsSync(path.join(dir, f)) ? fs.readFileSync(path.join(dir, f), 'utf8').split('\n').filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean) : [];
const actions = jl('actions.jsonl');
const events = jl('game_events.jsonl');
const transcript = jl(fs.existsSync(path.join(dir, 'transcript.jsonl')) ? 'transcript.jsonl' : 'transcript.sanitized.jsonl');
// The key on a 1280x720 window: centre (640, 380), clickable within 120 px.
const onKey = (a) => a.args && Math.hypot(Number(a.args[0]) - 640, Number(a.args[1]) - 380) <= 120;
const inputs = actions.filter((a) => ['click', 'double_click', 'hold', 'drag'].includes(a.cmd));
const firstInput = inputs[0];
const firstKey = inputs.find(onKey) || actions.find((a) => a.cmd === 'key' || a.cmd === 'hold_key');
const offKey = inputs.filter((a) => !onKey(a));
const gaps = [];
for (let i = 1; i < actions.length; i++) gaps.push({ at: actions[i - 1].wall_after ?? actions[i - 1].wall, gap: actions[i].wall - (actions[i - 1].wall_after ?? actions[i - 1].wall) });
const ev = (n) => events.filter((e) => e.ev === n);
const wakes = ev('doll_awake').map((e) => e.t);
const init = transcript.find((m) => m.type === 'system' && m.subtype === 'init') || {};
const texts = [];
for (const m of transcript) {
  if (m.type === 'assistant' && m.message && Array.isArray(m.message.content)) {
    for (const c of m.message.content) if (c.type === 'text' && c.text.trim()) texts.push(c.text.trim());
  }
}
const result = transcript.find((m) => m.type === 'result') || {};
const said = texts.join('\n').toLowerCase();
const mentions = (words) => words.some((w) => said.includes(w));
const end = actions.find((a) => a.cmd === 'end');
const summary = {
  session: path.basename(dir),
  model: init.model || null,
  build: (jl('game_events.jsonl')[0] || {}).build_id || null,
  wall_seconds: end ? end.wall : (actions.length ? actions[actions.length - 1].wall_after : null),
  actions: actions.length, inputs: inputs.length,
  first_input_wall_s: firstInput ? firstInput.wall : null,
  first_key_input_wall_s: firstKey ? firstKey.wall : null,
  first_wind_game_s: ev('wind')[0]?.t ?? null,
  first_doll_game_s: wakes[0] ?? null,
  second_doll_game_s: wakes[1] ?? null,
  first_help_game_s: ev('help')[0]?.t ?? null,
  dolls_at: Object.fromEntries([30, 60, 180].map((m) => [m, wakes.filter((t) => t <= m).length])),
  dolls_end: wakes.length,
  off_key_inputs: offKey.map((a) => ({ wall: a.wall, cmd: a.cmd, args: a.args })),
  holds: actions.filter((a) => a.cmd === 'hold' || a.cmd === 'hold_key').length,
  hints_shown: ev('hint').map((e) => ({ t: e.t, reason: e.reason })),
  longest_gaps_s: gaps.sort((a, b) => b.gap - a.gap).slice(0, 3).map((g) => ({ after_wall: +g.at.toFixed(1), seconds: +g.gap.toFixed(1) })),
  played_past_180_s: actions.some((a) => a.wall >= 180 && a.cmd !== 'end'),
  narration_mentions: {
    key_or_winding: mentions(['key', 'wind', 'crank']),
    dolls_or_figures: mentions(['doll', 'figure', 'toy', 'soldier', 'puppet', 'automaton']),
    automatic_work: mentions(['on its own', 'on their own', 'automatic', 'by itself', 'by themselves', 'passive', 'without me']),
    helping_each_other: mentions(['help', 'wind the next', 'winding the next', 'winding another', 'wakes the next', 'wake the next', 'each other', 'another doll']),
  },
  final_words: (result.result || texts[texts.length - 1] || '').slice(0, 2500),
  turns: result.num_turns ?? null, cost_usd: result.total_cost_usd ?? null,
};
fs.writeFileSync(path.join(dir, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
const md = [`# ${summary.session}`, '', `model ${summary.model} · build ${summary.build} · ${Math.round(summary.wall_seconds || 0)} s · ${summary.actions} actions`, '',
  '## Narration (verbatim, in order)', '', ...texts.map((t) => '> ' + t.replace(/\n/g, '\n> ') + '\n')].join('\n');
fs.writeFileSync(path.join(dir, 'narration.md'), md + '\n');
console.log(JSON.stringify({ ...summary, final_words: summary.final_words.slice(0, 300) + '…' }, null, 1));
