#!/usr/bin/env bash
# Popcorn's browser tests (tests/e2e) against the web build in docs/popcorn-glory/.
#
#   popcorn-glory/tools/e2e.sh                                  # every spec, local docs/
#   popcorn-glory/tools/e2e.sh specs/stub03.spec.mjs --project phone
#   POPCORN_E2E_BASE=https://7bvcxz.github.io/gamo/popcorn-glory/ popcorn-glory/tools/e2e.sh
#   POPCORN_SHOTS=/abs/dir popcorn-glory/tools/e2e.sh           # also save screenshots
#
# Run tools/deploy.sh first: this tests what is in docs/, not the source.
set -euo pipefail
E2E="$(cd "$(dirname "$0")/../tests/e2e" && pwd)"
cd "$E2E"
[[ -d node_modules/@playwright/test ]] || npm ci --no-audit --no-fund
port="${POPCORN_E2E_PORT:-18530}"
if [[ -z "${POPCORN_E2E_BASE:-}" ]] && (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
  echo "e2e: port $port is already in use (set POPCORN_E2E_PORT)"; exit 2
fi
exec npx playwright test "$@"
