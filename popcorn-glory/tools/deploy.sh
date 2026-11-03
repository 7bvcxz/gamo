#!/usr/bin/env bash
# Exports Popcorn & Glory to docs/popcorn-glory/, served by GitHub Pages at
#   https://7bvcxz.github.io/gamo/popcorn-glory/
#
#   popcorn-glory/tools/deploy.sh
#
# Why not ./deploy-web.sh: its runner rewrites the address to the game folder
# before the game starts (history.replaceState('./')) and its loader drops the
# hash, so a direct link to one experiment (#click) could not survive. This is
# the Fun Lab's way instead (momonium/experiments/tools/deploy.sh): Godot's own
# page, pointed at the one shared engine in docs/engine/ and at a content-hashed
# pack whose name is written into the stable index.html. No api.github.com.
#
# Its own folder and nothing else: the run fails if anything outside
# docs/popcorn-glory/ and docs/engine/ changed. Two packs are kept, the new one
# and the one published at HEAD (a cached index.html can still ask for it).
# Commit the source first: version.json records the source commit.
set -euo pipefail
GAME="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$GAME/.." && pwd)"
GODOT="${GODOT:-godot}"
SITE="docs/popcorn-glory"
OUT="$REPO/$SITE"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$REPO"

outside() { git status --porcelain -- docs | grep -v " $SITE/" | grep -v " docs/engine/" || true; }
before="$(outside)"

"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$GAME" --export-release Web "$WORK/index.html" >"$WORK/export.log" 2>&1 || true
if [[ ! -f "$WORK/index.pck" ]] || grep -qE 'SCRIPT ERROR|Parse Error' "$WORK/export.log"; then
  tail -n 20 "$WORK/export.log"; echo "deploy: export failed"; exit 1
fi
# Nothing the game does not use may ride along (AGENTS.md, 2026-09-29 and 2026-11-02).
for folder in design tests tools evidence; do
  if strings "$WORK/index.pck" | grep -q "res://$folder/"; then
    echo "deploy: the pack contains res://$folder/"; exit 1
  fi
done

engine="engine-$(sha256sum "$WORK/index.wasm" | cut -c1-12)"
pack="game-$(sha256sum "$WORK/index.pck" | cut -c1-12).pck"
mkdir -p "$OUT" "$REPO/docs/engine"
for part in js wasm audio.worklet.js audio.position.worklet.js; do
  [[ -f "$REPO/docs/engine/$engine.$part" ]] || cp "$WORK/index.$part" "$REPO/docs/engine/$engine.$part"
done
cp "$WORK/index.pck" "$OUT/$pack"
for icon in index.icon.png index.apple-touch-icon.png index.png; do
  [[ -f "$WORK/$icon" ]] && cp "$WORK/$icon" "$OUT/$icon"
done

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
    ('<title>Popcorn Glory</title>', '<title>Popcorn &amp; Glory</title>'),
]:
    assert page.count(old) == 1, "shell: %s appears %d times" % (old, page.count(old))
    page = page.replace(old, new)
open(dst, "w").write(page)
PY

published="$(git show "HEAD:$SITE/version.json" 2>/dev/null | sed -E 's/.*"pack":"([^"]+)".*/\1/' || true)"
for old in "$OUT"/game-*.pck; do
  name="$(basename "$old")"
  [[ "$name" == "$pack" || "$name" == "$published" ]] && continue
  unlink "$old"
  echo "  · removed unpublished pack $name"
done

version="$(sed -nE 's/^config\/version="([^"]+)"/\1/p' "$GAME/project.godot")"
# The last commit that changed the game, not HEAD: a docs commit or a rebase
# onto another session's push moves HEAD, and the record pointed at commits
# that held no game change or no longer existed (Steps 03 and 04).
source="$(git log -1 --format=%h --abbrev=12 -- "$GAME")"
# Evidence (screenshots, logs) is not game source: it may be uncommitted while a step is checked.
[[ -n "$(git status --porcelain -- "$GAME" ":(exclude)$GAME/evidence" | head -n 1)" ]] && source="$source-dirty"
printf '{"version":"%s","pack":"%s","packSize":%s,"engine":"%s","godot":"%s","source":"%s"}' \
  "$version" "$pack" "$(stat -c%s "$OUT/$pack")" "$engine" "$("$GODOT" --version | head -n 1)" "$source" > "$OUT/version.json"

after="$(outside)"
if [[ "$before" != "$after" ]]; then
  echo "deploy: something outside $SITE/ and docs/engine/ changed:"; diff <(echo "$before") <(echo "$after") || true
  exit 1
fi
echo "deploy: $SITE/ $pack ($(stat -c%s "$OUT/$pack") bytes), engine $engine, version $version, source $source"
