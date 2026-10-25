#!/usr/bin/env bash
# Exports Momonium to docs/momonium/ with the repository's deploy-web.sh, then
# keeps exactly two builds: the new one and the one that is currently published
# (the pack named by version.json at HEAD) -- or, when the new one IS the
# published one, that and the build before it.
#
# deploy-web.sh keeps "the two newest", which is right when every export is
# published. Exporting twice before a push would otherwise keep an unpublished
# intermediate and drop the build players' cached runners still ask for; and
# re-exporting the published build itself (the export is reproducible: the same
# source gives the same pack) must not drop the one before it.
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
# Re-exporting the published build: the one before it stays too (both tracked).
keep_tracked=""
[[ "$current" == "$published" ]] && keep_tracked="$(git ls-files 'docs/momonium/game-*.pck' | xargs -r -n1 basename)"
for pack in docs/momonium/game-*.pck; do
  name="$(basename "$pack")"
  [[ "$name" == "$current" || "$name" == "$published" ]] && continue
  [[ -n "$keep_tracked" ]] && grep -qxF "$name" <<<"$keep_tracked" && continue
  unlink "$pack"
  unlink "${pack%.pck}.html"
  echo "  · 게시되지 않은 중간 빌드 제거: $name"
done
# Version metadata beside the pack names (the launch page and testers read it):
# the game's version, the engine that built it, and the source commit (-dirty
# when momonium/ had uncommitted changes -- commit first, then deploy).
version="$(sed -nE 's/^config\/version="([^"]+)"/\1/p' momonium/project.godot)"
engine="$(godot --version | head -n 1)"
source="$(git rev-parse --short=12 HEAD)"
[[ -n "$(git status --porcelain -- momonium | grep -v '^??' | head -n 1)" ]] && source="$source-dirty"
python3 - "$version" "$engine" "$source" <<'PY'
import json, sys
path = "docs/momonium/version.json"
v = json.load(open(path))
v.update({"version": sys.argv[1], "godot": sys.argv[2], "source": sys.argv[3]})
open(path, "w").write(json.dumps(v, separators=(",", ":")))
PY
cp momonium/web/launch.html docs/momonium/launch.html
python3 momonium/tools/check_release.py "docs/momonium/$current" --site docs/momonium --version "$version" | tail -n 4
echo "current: $current  previous: ${published:-(none)}"
