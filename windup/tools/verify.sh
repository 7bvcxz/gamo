#!/usr/bin/env bash
# The whole verification matrix, one stage after another, with each stage's
# exit code in a table at the end (Step 07). Nothing stops at the first
# failure: a report should say everything that is broken.
#
#   windup/tools/verify.sh          # headless + export + desktop window + quick browser specs
#   windup/tools/verify.sh --long   # + the 3-minute plays, the profiles and the variant comparison
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
OUT="$(mktemp -d)"
declare -a NAMES CODES
run() { local name="$1"; shift; echo "── $name"; "$@"; local c=$?; NAMES+=("$name"); CODES+=("$c"); }
run "check (import, load, unit+integration, smoke, export)" "$HERE/tools/check.sh" --export
run "deploy to docs/windup" "$HERE/tools/deploy.sh"
run "desktop window 1920x1080 (OS input)" bash -c "'$HERE/tools/desktop_play.sh' '$OUT' 1920x1080 && test -s '$OUT/trace.jsonl' && ! grep -qE 'SCRIPT ERROR|ERROR:' '$OUT/game.log'"
run "browser: boot, art, feel, restart/save/pause, picker, correctness" "$HERE/tools/e2e.sh" specs/boot02.spec.mjs specs/art03.spec.mjs specs/feel05.spec.mjs specs/select06.spec.mjs specs/correct07.spec.mjs specs/play04.spec.mjs -g "boots|art loads|icons|restart|picker|click, awaken"
if [[ "${1:-}" == "--long" ]]; then
  run "browser: 3-minute play" "$HERE/tools/e2e.sh" specs/play04.spec.mjs -g "three minutes" --project desktop
  run "browser: three profiles" "$HERE/tools/e2e.sh" specs/profiles04.spec.mjs --project desktop
  run "browser: variants A/B/C vs base" "$HERE/tools/e2e.sh" specs/variants06.spec.mjs --project desktop
fi
echo
printf '%-70s %s\n' "stage" "exit"
fail=0
for i in "${!NAMES[@]}"; do printf '%-70s %s\n' "${NAMES[$i]}" "${CODES[$i]}"; [[ "${CODES[$i]}" == "0" ]] || fail=$((fail + 1)); done
echo "failed stages: $fail"
exit $fail
