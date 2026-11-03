#!/usr/bin/env bash
# Exports the Fun Lab to docs/momonium-experiments/, served by GitHub Pages at
#   https://7bvcxz.github.io/gamo/momonium-experiments/
#
#   momonium/experiments/tools/deploy.sh
#
# Its own folder and nothing else: the game's folder, its deploy tooling and
# the other games are never touched (the run fails if anything outside this
# folder and the shared engine changed). Like deploy-web.sh it gives the pack a
# content-hashed name, writes the current one into the stable index.html, and
# points at the one shared engine in docs/engine/ (the same Godot build makes
# the same engine file, so normally nothing is added there). Two packs are
# kept: the new one and the one published at HEAD (a cached index.html can
# still ask for it).
#
# Commit the source first: version.json records the source commit (-dirty when
# the Lab had uncommitted changes).
set -euo pipefail
LAB="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$LAB/../.." && pwd)"
GODOT="${GODOT:-godot}"
SITE="docs/momonium-experiments"
OUT="$REPO/$SITE"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$REPO"

outside() { git status --porcelain -- docs | grep -v " $SITE/" | grep -v " docs/engine/" || true; }
before="$(outside)"

"$GODOT" --headless --path "$LAB" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$LAB" --export-release Web "$WORK/index.html" >"$WORK/export.log" 2>&1 || true
if [[ ! -f "$WORK/index.pck" ]] || grep -qE 'SCRIPT ERROR|Parse Error' "$WORK/export.log"; then
  tail -n 20 "$WORK/export.log"; echo "deploy: export failed"; exit 1
fi

engine="engine-$(sha256sum "$WORK/index.wasm" | cut -c1-12)"
pack="lab-$(sha256sum "$WORK/index.pck" | cut -c1-12).pck"
mkdir -p "$OUT" "$REPO/docs/engine"
for part in js wasm audio.worklet.js audio.position.worklet.js; do
  [[ -f "$REPO/docs/engine/$engine.$part" ]] || cp "$WORK/index.$part" "$REPO/docs/engine/$engine.$part"
done
cp "$WORK/index.pck" "$OUT/$pack"
for icon in index.icon.png index.apple-touch-icon.png index.png; do
  [[ -f "$WORK/$icon" ]] && cp "$WORK/$icon" "$OUT/$icon"
done

# The page: Godot's own shell, pointed at the shared engine and the hashed pack.
python3 - "$WORK/index.html" "$OUT/index.html" "$engine" "$pack" <<'PY'
import sys
src, dst, engine, pack = sys.argv[1:]
page = open(src).read()
for old, new in [
    ('src="index.js"', 'src="../engine/%s.js"' % engine),
    ('"executable":"index"', '"executable":"../engine/%s"' % engine),
    ('"args":[]', '"args":[],"mainPack":"%s"' % pack),
    ('"index.pck":', '"%s":' % pack),
    ('"index.wasm":', '"../engine/%s.wasm":' % engine),
]:
    assert page.count(old) == 1, "shell: %s appears %d times" % (old, page.count(old))
    page = page.replace(old, new)
open(dst, "w").write(page)
PY

# The pages beside the Lab: the six-way comparison (Step 93, with its
# pictures and the scripted player's numbers in web/compare/, made by
# tools/compare_assets.sh) and the C/E tracks' protocol and scorecard (Step 94).
for page in "$LAB"/web/*.html; do
  cp "$page" "$OUT/$(basename "$page")"
done
if [[ -d "$LAB/web/compare" ]]; then
  mkdir -p "$OUT/compare"
  cp "$LAB/web/compare/"* "$OUT/compare/"
fi

# Keep the new pack and the one published at HEAD.
published="$(git show "HEAD:$SITE/version.json" 2>/dev/null | sed -E 's/.*"pack":"([^"]+)".*/\1/' || true)"
for old in "$OUT"/lab-*.pck; do
  name="$(basename "$old")"
  [[ "$name" == "$pack" || "$name" == "$published" ]] && continue
  unlink "$old"
  echo "  · removed unpublished pack $name"
done

version="$(sed -nE 's/^config\/version="([^"]+)"/\1/p' "$LAB/project.godot")"
source="$(git rev-parse --short=12 HEAD)"
[[ -n "$(git status --porcelain -- "$LAB" | grep -v '^??' | head -n 1)" ]] && source="$source-dirty"
printf '{"version":"%s","pack":"%s","packSize":%s,"engine":"%s","godot":"%s","source":"%s"}' \
  "$version" "$pack" "$(stat -c%s "$OUT/$pack")" "$engine" "$("$GODOT" --version | head -n 1)" "$source" > "$OUT/version.json"

after="$(outside)"
if [[ "$before" != "$after" ]]; then
  echo "deploy: something outside $SITE/ and docs/engine/ changed:"; diff <(echo "$before") <(echo "$after") || true
  exit 1
fi
echo "deploy: $SITE/ $pack ($(stat -c%s "$OUT/$pack") bytes), engine $engine, version $version, source $source"
