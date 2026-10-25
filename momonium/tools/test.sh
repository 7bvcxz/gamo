#!/usr/bin/env bash
# Momonium headless tests.
#
#   momonium/tools/test.sh                 # unit + integration
#   momonium/tools/test.sh unit            # one suite
#   momonium/tools/test.sh unit land       # cases whose id contains "land"
#
# Godot can exit 0 with a broken script, so this reads the output as well as the
# exit code: any SCRIPT ERROR, parse error or leaked-object warning fails the run.
# The browser E2E suite is separate (tests/e2e/README.md) and is not run here.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
SUITE="${1:-all}"
FILTER="${2:-}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# A fresh checkout has no .godot/ yet; class_name lookups need the import.
if [[ ! -d "$HERE/.godot" ]]; then
  "$GODOT" --headless --path "$HERE" --import >/dev/null 2>&1 || true
fi

args=(--headless --path "$HERE" --script res://tests/framework/runner.gd -- --suite "$SUITE")
[[ -n "$FILTER" ]] && args+=(--filter "$FILTER")
timeout -s KILL "${MOMONIUM_TEST_TIMEOUT:-600}" "$GODOT" "${args[@]}" >"$LOG" 2>&1
code=$?

grep -E '^(ok|FAIL|  )|passed,|^FAIL' "$LOG" | grep -v '^ok' || true
tail -n 1 "$LOG" | grep -q 'passed,' || grep -E 'passed,' "$LOG" | tail -n 1

problems=$(grep -cE 'SCRIPT ERROR|Parse Error|Failed to load script|leaked at exit|ObjectDB instances leaked' "$LOG")
if [[ $code -ne 0 || $problems -ne 0 ]]; then
  echo "── test.sh: FAILED (exit $code, engine problems $problems)"
  grep -E 'SCRIPT ERROR|Parse Error|Failed to load script|leaked' -A2 "$LOG" | head -40
  exit 1
fi
echo "── test.sh: OK"
