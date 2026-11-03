#!/usr/bin/env bash
# Headless smoke run of the real game scene:
#   windup/tools/smoke.sh
# Boots scenes/main.tscn with `--smoke` (eight scripted presses over four game
# seconds), expects one WINDUP_SMOKE line with "ok":true and no engine errors.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
"$GODOT" --headless --path "$HERE" --import >/dev/null 2>&1 || true
timeout -s KILL 120 "$GODOT" --headless --path "$HERE" --audio-driver Dummy -- --smoke --fresh >"$LOG" 2>&1
code=$?
line="$(grep -m1 '^WINDUP_SMOKE ' "$LOG" || true)"
echo "${line:-WINDUP_SMOKE (missing)}"
problems=$(grep -cE 'SCRIPT ERROR|Parse Error|Failed to load|ERROR: ' "$LOG")
if [[ $code -ne 0 || $problems -ne 0 || "$line" != *'"ok":true'* ]]; then
  echo "── smoke.sh: FAILED (exit $code, engine problems $problems)"
  grep -E 'SCRIPT ERROR|Parse Error|Failed to load|ERROR: ' -A2 "$LOG" | head -30
  exit 1
fi
echo "── smoke.sh: OK"
