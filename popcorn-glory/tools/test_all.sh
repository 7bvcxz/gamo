#!/usr/bin/env bash
# Every Popcorn check in one command, with one report:
#
#   popcorn-glory/tools/test_all.sh            # headless -> deploy -> browser (quick set) -> report
#   popcorn-glory/tools/test_all.sh --slow     # + three real minutes per experiment (play180)
#   popcorn-glory/tools/test_all.sh --public   # browser checks against the published URL (no deploy)
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
slow=0; public=0
for a in "$@"; do [[ "$a" == "--slow" ]] && slow=1; [[ "$a" == "--public" ]] && public=1; done

headless="FAILED"
"$GAME/tools/check.sh" > "$OUT/headless.log" 2>&1 && headless="PASSED"
echo "headless: $headless"

deploy="SKIPPED"; deploy_why="--public: testing the published build"
if [[ $public -eq 0 ]]; then
  if [[ "$headless" == "PASSED" ]]; then
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
    specs=(specs/stub03.spec.mjs specs/experiments04.spec.mjs specs/sound05.spec.mjs specs/responsive07.spec.mjs specs/input07.spec.mjs specs/progression07.spec.mjs specs/perf07.spec.mjs specs/scorecard09.spec.mjs specs/stall09.spec.mjs specs/stand10.spec.mjs)
    (( slow )) && specs+=(specs/play180.spec.mjs)
    # Always through env: an assignment after an empty array expansion is read as a command name.
    vars=(PLAYWRIGHT_JSON_OUTPUT_NAME="$OUT/e2e.json")
    (( public )) && vars+=(POPCORN_E2E_BASE=https://7bvcxz.github.io/gamo/popcorn-glory/)
    rm -f "$OUT/e2e.json"
    ( cd "$GAME/tests/e2e" && env "${vars[@]}" npx playwright test "${specs[@]}" --reporter=list,json ) > "$OUT/e2e.log" 2>&1 \
      && browser="PASSED" || browser="FAILED"
  fi
fi
echo "browser: $browser ${browser_why}"

(( public )) && export POPCORN_E2E_BASE=https://7bvcxz.github.io/gamo/popcorn-glory/
node "$GAME/tools/summarize.mjs" "$OUT" "$headless" "$deploy" "$deploy_why" "$browser" "$browser_why"
[[ "$headless" == "PASSED" && "$browser" != "FAILED" && "$deploy" != "FAILED" ]]
