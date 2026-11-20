#!/usr/bin/env bash
# Every Popcorn check in one command, with one report:
#
#   popcorn-glory/tools/test_all.sh              # headless -> deploy -> browser (every spec) -> report
#   popcorn-glory/tools/test_all.sh --focused    # a quick set touching every area (tools/specs.mjs FOCUSED)
#   popcorn-glory/tools/test_all.sh --slow       # + the real-time sessions (play180, play_stand, sessions22)
#   popcorn-glory/tools/test_all.sh --perf       # + the benchmarks (perf46, render_probe)
#   popcorn-glory/tools/test_all.sh --only=save45,ui44   # just these specs
#   popcorn-glory/tools/test_all.sh --public     # browser checks against the published URL (no deploy)
#   popcorn-glory/tools/test_all.sh --no-headless   # skip the headless stage (it is reported SKIPPED)
#
# Step 46: the browser list is derived from tests/e2e/specs/ (tools/specs.mjs); a spec left out of
# the full run is named there with its reason and listed in the report (run_info.json).
#
# Writes tests/results/step07/report.json and report.md: each check PASSED, FAILED or SKIPPED (with
# its cause), the git SHA, the build, and the browser console errors of failed checks. A check that
# could not run is SKIPPED with a reason, never PASSED.
#
# The machine (K12) has run out of memory before: the browser stage waits while less than 5 GB is
# available and gives up (SKIPPED: memory) after 10 minutes.
set -uo pipefail
GAME="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$GAME/.." && pwd)"
OUT="${POPCORN_REPORT_DIR:-$GAME/tests/results/step07}"   # POPCORN_REPORT_DIR: another folder (e.g. a public run)
mkdir -p "$OUT"
slow=0; public=0; perf=0; focused=0; only=""; skip_headless=0
for a in "$@"; do
  case "$a" in
    --slow) slow=1 ;; --public) public=1 ;; --perf) perf=1 ;; --focused) focused=1 ;;
    --only=*) only="${a#--only=}" ;; --no-headless) skip_headless=1 ;;
    *) echo "test_all.sh: unknown option $a"; exit 2 ;;
  esac
done
mode=full; (( focused )) && mode=focused; [[ -n "$only" ]] && mode=only
load_start="$(cut -d' ' -f1-3 /proc/loadavg)"; mem_start="$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)"
started="$(date -u +%FT%TZ)"

headless="FAILED"
if (( skip_headless )); then
  headless="SKIPPED"
else
  "$GAME/tools/check.sh" > "$OUT/headless.log" 2>&1 && headless="PASSED"
fi
echo "headless: $headless"

deploy="SKIPPED"; deploy_why="--public: testing the published build"
if [[ $public -eq 0 ]]; then
  if [[ "$headless" != "FAILED" ]]; then
    "$GAME/tools/deploy.sh" > "$OUT/deploy.log" 2>&1 && deploy="PASSED" || deploy="FAILED"; deploy_why=""
  else
    deploy_why="headless failed"
  fi
fi
echo "deploy: $deploy"

browser="SKIPPED"; browser_why=""
if [[ $public -eq 0 && "$deploy" != "PASSED" ]]; then
  browser_why="no fresh deploy"
else
  waited=0
  while (( $(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo) < 5 )); do
    (( waited >= 600 )) && { browser_why="memory: under 5 GB available for 10 minutes"; break; }
    sleep 30; waited=$((waited + 30))
  done
  if [[ -z "$browser_why" ]]; then
    if [[ -n "$only" ]]; then
      specs=(); IFS=',' read -ra names <<< "$only"
      for n in "${names[@]}"; do specs+=("specs/${n%.spec.mjs}.spec.mjs"); done
    else
      mapfile -t specs < <(node "$GAME/tools/specs.mjs" "$([[ $focused -eq 1 ]] && echo focused || echo full)")
      (( slow )) && mapfile -t -O "${#specs[@]}" specs < <(node "$GAME/tools/specs.mjs" slow)
      (( perf )) && mapfile -t -O "${#specs[@]}" specs < <(node "$GAME/tools/specs.mjs" perf)
    fi
    printf '%s\n' "${specs[@]}" > "$OUT/specs.txt"
    # Always through env: an assignment after an empty array expansion is read as a command name.
    # OUT: specs that write evidence (sessions22, perf46) write it beside the report.
    shots="${POPCORN_SHOTS:-$OUT/shots}"; mkdir -p "$shots"
    vars=(PLAYWRIGHT_JSON_OUTPUT_NAME="$OUT/e2e.json" OUT="$OUT" POPCORN_SHOTS="$shots")
    (( public )) && vars+=(POPCORN_E2E_BASE=https://7bvcxz.github.io/gamo/popcorn-glory/)
    rm -f "$OUT/e2e.json"
    ( cd "$GAME/tests/e2e" && env "${vars[@]}" npx playwright test "${specs[@]}" --reporter=list,json ) > "$OUT/e2e.log" 2>&1 \
      && browser="PASSED" || browser="FAILED"
  fi
fi
echo "browser: $browser ${browser_why}"

(( public )) && export POPCORN_E2E_BASE=https://7bvcxz.github.io/gamo/popcorn-glory/
# What this run was: its mode, the specs it played and the ones it left out (with why), the load.
node "$GAME/tools/run_info.mjs" "$OUT" "$mode" "$started" "$load_start" "$mem_start"
node "$GAME/tools/summarize.mjs" "$OUT" "$headless" "$deploy" "$deploy_why" "$browser" "$browser_why"
[[ "$headless" != "FAILED" && "$browser" != "FAILED" && "$deploy" != "FAILED" ]]
