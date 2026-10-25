#!/usr/bin/env bash
# Waits until GitHub Pages serves this deploy, then runs the browser smoke check
# against the public URL.
#
#   momonium/tools/verify_pages.sh            # pack and version from the working tree
#
# Pages publishes a push in one to ten minutes and caches index.html for ten, so
# this polls for the pack name the stable index redirects to instead of assuming.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
URL="${MOMONIUM_URL:-https://7bvcxz.github.io/gamo/momonium/}"
PACK="$(sed -E 's/.*"pack":"([^"]+)".*/\1/' "$ROOT/docs/momonium/version.json")"
VERSION="$(sed -nE 's/^config\/version="([^"]+)"/\1/p' "$HERE/project.godot")"
deadline=$(( $(date +%s) + ${MOMONIUM_PAGES_TIMEOUT:-1500} ))
echo "waiting for $URL to serve $PACK (v$VERSION)"
until curl -s --max-time 15 "${URL}index.html?nocache=$(date +%s)" | grep -q "$PACK"; do
  if (( $(date +%s) > deadline )); then echo "PAGES TIMEOUT: $PACK not served"; exit 2; fi
  sleep 20
done
echo "pages serves $PACK after $(( $(date +%s) - deadline + ${MOMONIUM_PAGES_TIMEOUT:-1500} ))s"
cd "$HERE/tests/e2e" && node smoke.mjs --url "$URL" --version "$VERSION" --pack "$PACK"
