#!/usr/bin/env bash
# The Fun Lab's browser tests (tests/e2e), with the game's Playwright install.
#
#   momonium/experiments/tools/e2e.sh                         # every spec, local docs/
#   momonium/experiments/tools/e2e.sh specs/funlab86.spec.mjs --project phone
#   FUNLAB_E2E_BASE=https://7bvcxz.github.io/gamo/momonium-experiments/ momonium/experiments/tools/e2e.sh
set -euo pipefail
E2E="$(cd "$(dirname "$0")/../tests/e2e" && pwd)"
GAME_MODULES="$(cd "$E2E/../../../tests/e2e" && pwd)/node_modules"
[[ -d "$GAME_MODULES/@playwright/test" ]] || { echo "e2e: install the game's tooling first (cd momonium/tests/e2e && npm ci)"; exit 2; }
[[ -e "$E2E/node_modules" ]] || ln -s "$GAME_MODULES" "$E2E/node_modules"
cd "$E2E"
exec npx playwright test "$@"
