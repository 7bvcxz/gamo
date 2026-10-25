#!/usr/bin/env bash
# Exports Momonium to docs/momonium/ with the repository's deploy-web.sh, then
# keeps exactly two builds: the new one and the one that is currently published
# (the pack named by version.json at HEAD).
#
# deploy-web.sh keeps "the two newest", which is right when every export is
# published. Exporting twice before a push would otherwise keep an unpublished
# intermediate and drop the build players' cached runners still ask for.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
./deploy-web.sh momonium | tail -n 3
current="$(sed -E 's/.*"pack":"([^"]+)".*/\1/' docs/momonium/version.json)"
published="$(git show HEAD:docs/momonium/version.json 2>/dev/null | sed -E 's/.*"pack":"([^"]+)".*/\1/' || true)"
if [[ -n "$published" && "$published" != "$current" && ! -f "docs/momonium/$published" ]]; then
  git checkout HEAD -- "docs/momonium/$published" "docs/momonium/${published%.pck}.html"
  echo "  · 게시 중인 빌드 복원: $published"
fi
for pack in docs/momonium/game-*.pck; do
  name="$(basename "$pack")"
  [[ "$name" == "$current" || "$name" == "$published" ]] && continue
  unlink "$pack"
  unlink "${pack%.pck}.html"
  echo "  · 게시되지 않은 중간 빌드 제거: $name"
done
echo "current: $current  previous: ${published:-(none)}"
