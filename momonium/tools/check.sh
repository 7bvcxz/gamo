#!/usr/bin/env bash
# Everything CI checks for Momonium, runnable locally.
#
#   momonium/tools/check.sh              # import, load check, unit + integration
#   momonium/tools/check.sh --export     # ...then a Web export and a browser smoke
#   momonium/tools/check.sh --export --skip-tests
#
# Not the E2E suite: that runs only at Steps 10/20/30/40 (tests/e2e/README.md).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
EXPORT=0; SKIP_TESTS=0
for arg in "$@"; do
  case "$arg" in
    --export) EXPORT=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    *) echo "unknown option $arg"; exit 2 ;;
  esac
done
LOG="$(mktemp)"; WORK="$(mktemp -d)"
cleanup() { rm -f "$LOG"; [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT
fail() { echo "── check.sh: FAILED — $1"; exit 1; }
engine_problems() { grep -E 'SCRIPT ERROR|Parse Error|Failed to load|Failed loading resource|ERROR: ' "$1" | grep -v 'leaked at exit' || true; }

echo "── import"
# Twice: on a fresh checkout the first pass generates what the project loads at
# startup (translation tables from data/i18n/*.csv, the class cache), and the
# engine complains about their absence while it does so. The second pass is the
# one that must be clean.
timeout 300 "$GODOT" --headless --path "$HERE" --import >/dev/null 2>&1 || true
timeout 300 "$GODOT" --headless --path "$HERE" --import >"$LOG" 2>&1
[[ -z "$(engine_problems "$LOG")" ]] || { engine_problems "$LOG" | head; fail "import"; }

echo "── editor load (every script parses)"
timeout 300 "$GODOT" --headless --path "$HERE" --editor --quit >"$LOG" 2>&1
[[ -z "$(engine_problems "$LOG")" ]] || { engine_problems "$LOG" | head; fail "editor load"; }

if [[ $SKIP_TESTS -eq 0 ]]; then
  echo "── unit + integration"
  "$HERE/tools/test.sh" all || fail "tests"
fi

if [[ $EXPORT -eq 1 ]]; then
  echo "── web export"
  mkdir -p "$WORK/site/momonium"
  timeout 600 "$GODOT" --headless --path "$HERE" --export-release Web "$WORK/site/momonium/index.html" >"$LOG" 2>&1
  [[ -f "$WORK/site/momonium/index.pck" ]] || { tail -20 "$LOG"; fail "export produced no pack"; }
  pck=$(stat -c%s "$WORK/site/momonium/index.pck")
  budget=$(( ${MOMONIUM_PCK_BUDGET_MB:-20} * 1024 * 1024 ))
  echo "   pack $pck bytes (budget $budget)"
  (( pck <= budget )) || fail "pack over budget"
  if grep -qa 'res://tests/' "$WORK/site/momonium/index.pck"; then fail "tests leaked into the pack"; fi
  echo "── what the pack ships"
  python3 "$HERE/tools/check_release.py" "$WORK/site/momonium/index.pck" --budget-mb "${MOMONIUM_PCK_BUDGET_MB:-20}" || fail "release check"
  # Reproducible: this source exports the very pack that is published for it
  # (pack names are the first 12 hex of their SHA-256). Only a warning: a
  # change pushed before its web export is allowed, just not yet published.
  published="$HERE/../docs/momonium/version.json"
  if [[ -f "$published" ]]; then
    ours="game-$(sha256sum "$WORK/site/momonium/index.pck" | cut -c1-12).pck"
    theirs="$(sed -E 's/.*"pack":"([^"]+)".*/\1/' "$published")"
    if [[ "$ours" == "$theirs" ]]; then
      echo "   reproducible: this export is the published $theirs"
    else
      echo "::warning::this source exports $ours; the published build is $theirs (export not yet published, or not reproducible here)"
    fi
  fi

  echo "── browser smoke"
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$WORK/site" >/dev/null 2>&1 &
  SERVER_PID=$!
  for _ in $(seq 1 50); do curl -sf "http://127.0.0.1:$port/momonium/index.html" >/dev/null && break; sleep 0.2; done
  version=$(sed -nE 's/^config\/version="([^"]+)"/\1/p' "$HERE/project.godot")
  (cd "$HERE/tests/e2e" && node smoke.mjs --url "http://127.0.0.1:$port/momonium/" --version "$version") || fail "smoke"
fi
echo "── check.sh: OK"
