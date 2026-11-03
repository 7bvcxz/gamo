#!/usr/bin/env bash
# Everything CI checks for Windup, runnable locally:
#   windup/tools/check.sh            # import, editor load, unit + integration, smoke
#   windup/tools/check.sh --export   # + a Web export to a temp folder (needs the 4.7 web templates)
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
OUT="$(mktemp -d)"
trap 'rm -f "$LOG"; rm -rf "$OUT"' EXIT
fail() { echo "── check.sh (windup): FAILED — $1"; exit 1; }
problems() { grep -E 'SCRIPT ERROR|Parse Error|Failed to load|Failed loading resource|ERROR: ' "$1" | grep -v 'leaked at exit' || true; }
echo "── windup: import"
timeout 300 "$GODOT" --headless --path "$HERE" --import >/dev/null 2>&1 || true
timeout 300 "$GODOT" --headless --path "$HERE" --import >"$LOG" 2>&1
[[ -z "$(problems "$LOG")" ]] || { problems "$LOG" | head; fail "import"; }
echo "── windup: editor load"
timeout 300 "$GODOT" --headless --path "$HERE" --editor --quit >"$LOG" 2>&1
[[ -z "$(problems "$LOG")" ]] || { problems "$LOG" | head; fail "editor load"; }
echo "── windup: unit + integration"
"$HERE/tools/test.sh" all || fail "tests"
echo "── windup: smoke"
"$HERE/tools/smoke.sh" || fail "smoke"
if [[ "${1:-}" == "--export" ]]; then
  echo "── windup: web export"
  timeout 300 "$GODOT" --headless --path "$HERE" --export-release Web "$OUT/index.html" >"$LOG" 2>&1 || true
  [[ -f "$OUT/index.pck" && -z "$(problems "$LOG")" ]] || { tail -n 20 "$LOG"; fail "web export"; }
  echo "   pack $(stat -c%s "$OUT/index.pck") bytes"
  # Nothing that is not the game may ride in the pack (AGENTS.md, 2026-09-29).
  for dir in tests tools design evidence; do
    n=$(grep -c -a "res://$dir/" "$OUT/index.pck" || true)
    [[ "$n" == "0" ]] || fail "res://$dir/ is in the pack ($n)"
  done
fi
echo "── check.sh (windup): OK"
