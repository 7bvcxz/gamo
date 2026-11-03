#!/usr/bin/env bash
# Exports Windup to docs/windup/ through the shared ./deploy-web.sh, then keeps
# exactly two packs: the new one and the one published at HEAD (a cached
# runner can still ask for it). deploy-web.sh keeps the two NEWEST by mtime,
# which after a few local re-exports is the new build and an unpublished
# intermediate one -- the published pack was pruned twice that way.
#
#   windup/tools/deploy.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SITE="docs/windup"
cd "$REPO"
published="$(git show "HEAD:$SITE/version.json" 2>/dev/null | sed -E 's/.*"pack":"([^"]+)".*/\1/' || true)"
./deploy-web.sh windup
current="$(sed -E 's/.*"pack":"([^"]+)".*/\1/' "$SITE/version.json")"
if [[ -n "$published" && "$published" != "$current" && ! -f "$SITE/$published" ]]; then
  git checkout HEAD -- "$SITE/$published" "$SITE/${published%.pck}.html"
  echo "  · kept the published pack $published"
fi
for f in "$SITE"/game-*.pck; do
  name="$(basename "$f")"
  [[ "$name" == "$current" || "$name" == "$published" ]] && continue
  unlink "$f"; unlink "${f%.pck}.html" 2>/dev/null || true
  echo "  · removed unpublished pack $name"
done
# The variant picker page beside the game (Step 06); the game itself serves all variants.
cp "$REPO/windup/web/variants.html" "$SITE/variants.html"
ls "$SITE"/game-*.pck
