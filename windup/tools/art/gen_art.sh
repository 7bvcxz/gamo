#!/usr/bin/env bash
# Generates Windup's source art with the shared imagegen CLI (OpenAI images).
#
#   windup/tools/art/gen_art.sh                # dry run: prints every request, spends nothing
#   windup/tools/art/gen_art.sh --go [names]   # really calls (costs money), skips files that exist
#
# Names: backdrop doll_wake key. Writes windup/art/raw/<name>.png and, beside
# it, imagegen's <name>.png.json sidecar (prompt, model, refs, tokens) -- the
# sidecar is committed so a picture can be made again without guessing.
# The green references come first: godot --headless --path windup --script res://tools/art/build_art.gd -- --green
# Then: godot --headless --path windup --script res://tools/art/build_art.gd   (raw -> assets/art)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
RAW="$HERE/art/raw"; REF="$HERE/art/ref"
mkdir -p "$RAW"
GO=0; [[ "${1:-}" == "--go" ]] && { GO=1; shift; }
ONLY=("$@")
command -v imagegen >/dev/null || { echo "gen_art: imagegen is not on PATH (~/Workspace/tools/imagegen)"; exit 2; }

STYLE="Hand-painted storybook gouache illustration with soft brush texture, warm muted colours, gentle rim light and clean readable silhouettes. No text, no letters, no watermark."

declare -A PROMPT SIZE QUALITY REFS
PROMPT[backdrop]="The inside of a small old tailoring workshop at night, seen straight on from the side like a stage set, wide view. Wooden floorboards across the bottom third. Back wall of faded plum wallpaper above dark wooden wainscoting. On the left a tall arched window; cool moonlight falls through it in a pale blue beam across the floorboards. In the centre a sturdy wooden workbench; on the middle of its top stands a small upright round brass gear housing. Around the room: a dress form wearing a half-finished jacket, a sewing machine under a dust cloth on a side table, shelves of rolled fabric bolts and spools of thread, a tall stopped grandfather clock on the right, an unlit brass chandelier hanging from the ceiling with dust on it, heavy curtains drawn shut on the right wall, cobwebs in the corners. Everything is still and asleep, lit only by the moonlight: deep blue and plum shadows, a few brass edges catching the light. ${STYLE}"
SIZE[backdrop]=1536x1024; QUALITY[backdrop]=medium; REFS[backdrop]=""
PROMPT[doll_wake]="Paint on this flat green canvas and keep the whole background exactly this flat pure green. Four poses of the same small clockwork tailor doll in one row, left to right, evenly spaced, each one complete with green space all around it, all drawn at the same scale: 1) sitting on the floor slumped forward, head bowed, eyes closed, arms hanging loose; 2) sitting on the floor lifting its head, eyes half open; 3) sitting upright on the floor, eyes wide open; 4) standing, both arms stretched high above its head, eyes open, smiling. The doll: wooden jointed body, round porcelain face with rosy cheeks and a short dark painted bob, cream shirt, burgundy waistcoat with brass buttons, dark brown trousers, a yellow tape measure around its neck, a small brass wind-up key sticking out of its back. Three-quarter view facing right. ${STYLE}"
SIZE[doll_wake]=1536x1024; QUALITY[doll_wake]=medium; REFS[doll_wake]="$REF/green_1536x1024.png"
PROMPT[key]="Paint on this flat green canvas and keep the whole background exactly this flat pure green. The bow of one large ornate brass wind-up key seen straight from the front, centred and filling most of the canvas: a butterfly shape with two big rounded lobes joined by a round boss in the middle, polished warm brass with soft highlights, dark engraved swirls and slight wear on the edges. ${STYLE}"
SIZE[key]=1024x1024; QUALITY[key]=medium; REFS[key]="$REF/green_1024x1024.png"

for name in backdrop doll_wake key; do
  if [[ ${#ONLY[@]} -gt 0 && ! " ${ONLY[*]} " =~ " $name " ]]; then continue; fi
  out="$RAW/$name.png"
  args=(--out "$out" --size "${SIZE[$name]}" --quality "${QUALITY[$name]}")
  if [[ -n "${REFS[$name]}" ]]; then
    [[ -f "${REFS[$name]}" ]] || { echo "gen_art: missing ${REFS[$name]} (run build_art.gd -- --green)"; exit 2; }
    args+=(--ref "${REFS[$name]}")
  fi
  if [[ $GO -eq 0 ]]; then
    imagegen "${PROMPT[$name]}" "${args[@]}" --dry-run
  elif [[ -f "$out" ]]; then
    echo "gen_art: $out exists, skipped (delete it to make it again)"
  else
    imagegen "${PROMPT[$name]}" "${args[@]}"
  fi
done
