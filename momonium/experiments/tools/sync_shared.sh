#!/usr/bin/env bash
# Copies what the Fun Lab reuses from the game into shared/, byte for byte.
#
#   momonium/experiments/tools/sync_shared.sh
#
# The Lab is its own Godot project (it cannot read the game's res://), and a
# fresh clone must open it without running anything first, so the copies are
# committed. shared/MANIFEST.json names each copy's source; the test
# tests/unit/test_shared_assets.gd fails when a copy and its source differ --
# run this, and commit, when the game's art changes and the Lab should follow.
# Only owned files (the game's own art, sound and font) are listed here.
set -euo pipefail
LAB="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$(cd "$LAB/.." && pwd)"
FILES=(
  assets/atlas/sprites.png assets/atlas/sprites.json
  assets/momo/momo_sheet.png assets/momo/momo_sheet.json
  assets/momo/momo_work.png assets/momo/momo_work.json
  assets/hands/hand_tools.png assets/hands/hand_tools.json
  assets/textures/grass.png assets/textures/cliff.png assets/textures/dirt.png assets/textures/stone.png
  assets/shaders/ocean.gdshader
  assets/fonts/ui_ko.otf
  assets/audio/music_calm.ogg assets/audio/amb_ocean.ogg
  assets/audio/sfx_coin.ogg assets/audio/sfx_click.ogg assets/audio/sfx_refuse.ogg
  assets/audio/sfx_built.ogg assets/audio/sfx_promote.ogg assets/audio/sfx_harvest.ogg
  assets/audio/sfx_tap_pick.ogg assets/audio/sfx_tap_metal.ogg assets/audio/sfx_thunk.ogg
  assets/audio/sfx_demolish.ogg assets/audio/sfx_land.ogg assets/audio/sfx_momo.ogg
  assets/audio/sfx_tap_soft.ogg assets/audio/sfx_tap_wood.ogg assets/audio/sfx_tap_water.ogg
)
manifest="{\n  \"_doc\": \"Copies of the game's own files (momonium/<source>), made by tools/sync_shared.sh; tests/unit/test_shared_assets.gd checks each is byte-identical to its source.\",\n  \"files\": {"
sep=""
for src in "${FILES[@]}"; do
  dst="shared/${src#assets/}"
  mkdir -p "$LAB/$(dirname "$dst")"
  cp "$GAME/$src" "$LAB/$dst"
  # The game's import settings too (mipmaps, compression), so a copy imports
  # the way its source does -- once: after that the Lab's importer owns the
  # file (its uid and cache paths), and the test compares the [params].
  [[ -f "$GAME/$src.import" && ! -f "$LAB/$dst.import" ]] && sed '/^uid=/d;/^path=/d;/^dest_files=/d;s|^source_file=.*|source_file="res://'"$dst"'"|' "$GAME/$src.import" > "$LAB/$dst.import"
  manifest+="$sep\n    \"$dst\": \"$src\""
  sep=","
done
manifest+="\n  }\n}\n"
printf "$manifest" > "$LAB/shared/MANIFEST.json"
echo "shared/: ${#FILES[@]} files copied from momonium/assets"
