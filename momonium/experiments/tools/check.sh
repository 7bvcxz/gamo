#!/usr/bin/env bash
# Everything CI checks for the Fun Lab, runnable locally:
#   momonium/experiments/tools/check.sh
# import (twice: a fresh checkout's first pass builds the class cache), the
# editor load (every script parses), unit + integration tests.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
fail() { echo "── check.sh (Fun Lab): FAILED — $1"; exit 1; }
problems() { grep -E 'SCRIPT ERROR|Parse Error|Failed to load|Failed loading resource|ERROR: ' "$1" | grep -v 'leaked at exit' || true; }
echo "── Fun Lab: import"
timeout 300 "$GODOT" --headless --path "$HERE" --import >/dev/null 2>&1 || true
timeout 300 "$GODOT" --headless --path "$HERE" --import >"$LOG" 2>&1
[[ -z "$(problems "$LOG")" ]] || { problems "$LOG" | head; fail "import"; }
echo "── Fun Lab: editor load"
timeout 300 "$GODOT" --headless --path "$HERE" --editor --quit >"$LOG" 2>&1
[[ -z "$(problems "$LOG")" ]] || { problems "$LOG" | head; fail "editor load"; }
echo "── Fun Lab: unit + integration"
"$HERE/tools/test.sh" all || fail "tests"
echo "── check.sh (Fun Lab): OK"
