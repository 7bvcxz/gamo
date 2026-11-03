#!/usr/bin/env bash
# Checks the blind-play recorder without any AI (Step 09): serves the local
# docs/windup build, sends a few controls through act.mjs exactly as a player
# would, and asserts (1) every reply holds nothing but a screenshot path and the
# seconds since the start (no game state reaches the player), (2) the screenshot
# exists, (3) after `end` the recorder saved its action log, the game's own
# event log and a video with sound.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DOCS="$(git -C "$HERE" rev-parse --show-toplevel)/docs"
WORK="$(mktemp -d "${WINDUP_BLIND_ROOT:-/tmp}/selftest.XXXXXX")"
PORT=$((18900 + RANDOM % 90)); RPORT=$((PORT + 1000))
[[ -e "$HERE/node_modules" ]] || ln -s ../../tests/e2e/node_modules "$HERE/node_modules"
python3 -m http.server $PORT --bind 127.0.0.1 --directory "$DOCS" > "$WORK/http.log" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null || true' EXIT
for i in $(seq 1 20); do curl -sf -o /dev/null "http://127.0.0.1:$PORT/windup/index.html" && break; sleep 0.5; done
curl -sf -o /dev/null "http://127.0.0.1:$PORT/windup/index.html" || { echo "selftest: local server did not serve docs/windup"; exit 1; }
mkdir -p "$WORK/box/screens"; cp "$HERE/act.mjs" "$WORK/box/"; echo $RPORT > "$WORK/box/.port"
node "$HERE/server.mjs" --url "http://127.0.0.1:$PORT/windup/?fresh=1" --screens "$WORK/box/screens" --out "$WORK/out" --port $RPORT > "$WORK/server.log" 2>&1 & SPID=$!
until grep -q '^ready' "$WORK/server.log" 2>/dev/null; do kill -0 $SPID 2>/dev/null || { cat "$WORK/server.log"; exit 1; }; sleep 1; done
fail=0
check() { # reply, allowed keys
  node -e 'const r=JSON.parse(process.argv[1]); const ok=new Set(process.argv[2].split(",")); const bad=Object.keys(r).filter(k=>!ok.has(k)); if(bad.length||r.error){console.log("FAIL reply",process.argv[1]);process.exit(1)}' "$1" "$2" || fail=1
}
cd "$WORK/box"
for c in "look" "click 640 380" "hold 640 380 1.0" "key Space" "wait 1"; do
  r=$(node ./act.mjs $c); check "$r" screenshot,seconds_since_start
  f=$(node -e 'console.log(JSON.parse(process.argv[1]).screenshot)' "$r"); [[ -s "$f" ]] || { echo "FAIL no screenshot for $c"; fail=1; }
done
r=$(node ./act.mjs end); check "$r" ended,seconds
for i in $(seq 1 60); do kill -0 $SPID 2>/dev/null || break; sleep 1; done
O="$WORK/out"
[[ $(wc -l < "$O/actions.jsonl") -ge 6 ]] || { echo "FAIL action log"; fail=1; }
grep -q '"ev":"wind"' "$O/game_events.jsonl" || { echo "FAIL the game's events were not saved (or no wind landed)"; fail=1; }
node -e 'const f=require(process.argv[1]); if(!(f.audio_bytes>0)) process.exit(1)' "$O/footage.json" || { echo "FAIL no audio in the footage"; fail=1; }
ls "$O"/session_*.mp4 > /dev/null || { echo "FAIL no video"; fail=1; }
[[ $fail -eq 0 ]] && echo "blind selftest: OK ($(wc -l < "$O/actions.jsonl") actions, $(grep -c '"ev":"wind"' "$O/game_events.jsonl") winds, video $(stat -c %s "$O"/session_*.mp4) bytes)" || { echo "blind selftest: FAILED ($WORK)"; exit 1; }
rm -rf "$WORK"
