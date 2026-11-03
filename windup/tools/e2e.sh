#!/usr/bin/env bash
# Windup's browser tests (tests/e2e) against the local docs/windup/ build, or a
# deployed one with WINDUP_E2E_BASE=https://7bvcxz.github.io/gamo/windup/.
#
#   windup/tools/e2e.sh                          # every spec, both projects
#   windup/tools/e2e.sh specs/boot02.spec.mjs --project desktop
#
# First time: (cd windup/tests/e2e && npm install && npx playwright install chromium).
# A checkout that already installed Momonium's browser tooling reuses it.
set -euo pipefail
E2E="$(cd "$(dirname "$0")/../tests/e2e" && pwd)"
if [[ ! -d "$E2E/node_modules/@playwright/test" ]]; then
  for other in "$E2E/../../../momonium/tests/e2e/node_modules" "${WINDUP_PLAYWRIGHT_MODULES:-}"; do
    if [[ -n "$other" && -d "$other/@playwright/test" ]]; then
      rm -f "$E2E/node_modules"; ln -s "$(cd "$other" && pwd)" "$E2E/node_modules"; break
    fi
  done
fi
[[ -d "$E2E/node_modules/@playwright/test" ]] || { echo "e2e: run (cd windup/tests/e2e && npm install) first"; exit 2; }
cd "$E2E"
exec npx playwright test "$@"
