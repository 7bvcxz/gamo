#!/usr/bin/env bash
# An independent rater for blind sessions (Step 10). A separate claude -p with
# no tools, in an empty folder (--restricted --safe-mode), gets only the
# session records -- each session's decision log (what the player looked at,
# said and did, with times) and the objective facts from its summary -- under
# shuffled neutral labels, plus the 4x5 rubric. It is not told which build a
# session played or that a change was made. The label -> session map is kept
# beside its answer, not given to it.
#   windup/tools/blind/rate_sessions.sh <out dir> <session dir>...
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mkdir -p "${1:?out dir}" && cd "$1" && pwd)"; shift
BOX="$(mktemp -d "${WINDUP_BLIND_ROOT:-/tmp}/rate.XXXXXX")"
node - "$OUT" "$@" <<'JS' > "$BOX/prompt.txt"
const fs = require('fs'), path = require('path');
const [out, ...dirs] = process.argv.slice(2);
// Deterministic shuffle (fixed seed) so the run can be repeated.
let seed = 20261103;
const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
const order = dirs.map((d) => [rnd(), d]).sort((a, b) => a[0] - b[0]).map((x) => x[1]);
const map = {};
const parts = order.map((d, i) => {
  const label = `P${i + 1}`;
  map[label] = path.basename(d);
  const s = JSON.parse(fs.readFileSync(path.join(d, 'summary.json'), 'utf8'));
  const facts = {
    session_length_s: Math.round(s.wall_seconds), inputs: s.inputs,
    first_input_s: s.first_key_input_wall_s, first_wind_s: s.first_wind_game_s,
    first_doll_awake_s: s.first_doll_game_s, second_doll_awake_s: s.second_doll_game_s,
    dolls_awake_at_30_60_180_s: s.dolls_at, dolls_awake_at_end: s.dolls_end,
    press_and_hold_commands: s.holds, clicks_not_on_the_key: s.off_key_inputs.length,
    longest_pauses_between_commands_s: s.longest_gaps_s.map((g) => g.seconds),
  };
  const log = fs.readFileSync(path.join(d, 'decisions.md'), 'utf8').replace(/^# Decisions.*\n/, '').replace(/seen\/\d+\.png/g, 'screenshot');
  return `=== SESSION ${label} ===\nObjective facts (from the game's own log, read after the session; times in seconds since start):\n${JSON.stringify(facts, null, 1)}\n\nDecision log (what the player looked at, said and did, in order):\n${log}`;
});
fs.writeFileSync(path.join(out, 'label_map.json'), JSON.stringify(map, null, 1) + '\n');
process.stdout.write(`You are rating usability-research sessions of a small browser game. In each session an AI player who had never seen the game played it for about three minutes, seeing only screenshots and using mouse and keyboard, and narrated what it thought. You get each session's objective facts and its decision log. Rate each session separately on four categories, 1 to 5:

(i) controls discovered naturally
(ii) emotional growth / payoff
(iii) anticipation of the next change
(iv) desire to keep playing after 180 seconds

Anchors for every category: 1 = fails to function or to be understood; 3 = partly understandable or appealing, with visible friction; 5 = compelling and self-explanatory. 2 and 4 are in between.

Rules: base every score only on what the record shows (times, failed clicks, pauses, what the player said). For every score give a one- or two-sentence explanation citing specific observed events (with times where possible). Keep observations (facts) and the player's opinions (e.g. "charming", "would keep playing") apart in your explanation. Do not compare sessions with each other when scoring; score each on its own record. These are AI players, so do not claim anything about human enjoyment.

Answer with JSON only, no prose before or after, in exactly this shape:
{"P1": {"i": {"score": 3, "why": "..."}, "ii": {...}, "iii": {...}, "iv": {...}}, "P2": {...}, ...}

${parts.join('\n\n')}
`);
JS
cp "$BOX/prompt.txt" "$OUT/rater_prompt.txt"
( cd "$BOX" && timeout 900 claude -p --restricted --safe-mode --strict-mcp-config --no-session-persistence --tools "" \
    --output-format json --max-turns 2 "$(cat "$BOX/prompt.txt")" < /dev/null > "$OUT/rater_raw.json" 2> "$OUT/rater.stderr" ) || true
node -e '
const fs=require("fs"); const out=process.argv[1];
const raw=JSON.parse(fs.readFileSync(out+"/rater_raw.json","utf8")); const text=raw.result||"";
const j=JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}")+1));
const map=JSON.parse(fs.readFileSync(out+"/label_map.json","utf8"));
const byS={}; for (const [l,v] of Object.entries(j)) byS[map[l]]={label:l,...v};
fs.writeFileSync(out+"/rater_scores.json", JSON.stringify({model: raw.modelUsage?Object.keys(raw.modelUsage):null, cost_usd: raw.total_cost_usd, scores: byS}, null, 1)+"\n");
for (const [s,v] of Object.entries(byS)) console.log(s, v.label, ["i","ii","iii","iv"].map(k=>v[k].score).join(" "));
' "$OUT"
