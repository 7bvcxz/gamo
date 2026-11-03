#!/usr/bin/env bash
# One blind AI play session (Step 09).
#
#   windup/tools/blind/run_session.sh <evidence-dir> [game-url] [model]
#
# A new, empty sandbox holds only act.mjs (the controls) and screens/. The
# player is a separate `claude -p` session started IN the sandbox with:
#   --restricted      file tools confined to the sandbox, user/project settings ignored
#   --safe-mode       no CLAUDE.md, skills, plugins, hooks or MCP servers
#   --tools Bash,Read and --allowedTools "Bash(node ./act.mjs:*)"  -- the controls and the screenshots, nothing else
#   --no-session-persistence, a fresh process: no memory of other sessions
# It is given PROMPT.txt verbatim. It never sees the game's code, data, state,
# telemetry or this repository. The recorder (server.mjs) keeps the evidence.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mkdir -p "${1:?evidence dir}" && cd "$1" && pwd)"
URL="${2:-https://7bvcxz.github.io/gamo/windup/?fresh=1}"
MODEL="${3:-}"
SCRATCH="${WINDUP_BLIND_ROOT:-$(mktemp -d)}"
BOX="$(mktemp -d "$SCRATCH/play.XXXXXX")"
PORT=$((18600 + RANDOM % 300))
[[ -e "$HERE/node_modules" ]] || ln -s ../../tests/e2e/node_modules "$HERE/node_modules"
cp "$HERE/act.mjs" "$BOX/act.mjs"
echo "$PORT" > "$BOX/.port"
mkdir -p "$BOX/screens"
node "$HERE/server.mjs" --url "$URL" --screens "$BOX/screens" --out "$OUT" --port "$PORT" > "$OUT/server.log" 2>&1 &
SPID=$!
until grep -q '^ready' "$OUT/server.log" 2>/dev/null; do
  kill -0 $SPID 2>/dev/null || { echo "recorder died"; cat "$OUT/server.log"; exit 1; }
  sleep 1
done
cp "$HERE/PROMPT.txt" "$OUT/prompt.txt"
{
  echo "sandbox: $BOX (contents: act.mjs, .port, screens/)"
  echo "started: $(date -Iseconds)"
  echo "game: $URL"
  echo "repo commit: $(git -C "$HERE" rev-parse HEAD)"
  echo "claude: $(claude --version)"
  echo "flags: -p --restricted --safe-mode --strict-mcp-config --no-session-persistence --tools Bash,Read --allowedTools 'Bash(node ./act.mjs:*)' --output-format stream-json --verbose --max-turns 200 ${MODEL:+--model $MODEL}"
} > "$OUT/setup.txt"
( cd "$BOX" && timeout 1500 claude -p --restricted --safe-mode --strict-mcp-config --no-session-persistence \
    --tools "Bash,Read" --allowedTools "Bash(node ./act.mjs:*)" --output-format stream-json --verbose --max-turns 200 \
    ${MODEL:+--model "$MODEL"} "$(cat "$HERE/PROMPT.txt")" < /dev/null > "$OUT/transcript.jsonl" 2> "$OUT/claude.stderr" ) || true
( cd "$BOX" && node ./act.mjs end > /dev/null ) || true
for i in $(seq 1 60); do kill -0 $SPID 2>/dev/null || break; sleep 1; done
kill $SPID 2>/dev/null || true
cp -r "$BOX/screens" "$OUT/screens"
echo "finished: $(date -Iseconds)" >> "$OUT/setup.txt"
node "$HERE/extract.mjs" "$OUT" && node "$HERE/analyze.mjs" "$OUT" > /dev/null
echo "session done: $(ls "$OUT/screens" | wc -l) screens, $(wc -l < "$OUT/actions.jsonl") actions"
