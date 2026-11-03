#!/usr/bin/env bash
# One picture per run of specs/play180.spec.mjs: for each experiment a row of
# its checkpoints -- first action, first upgrade, 1:00, 3:00 -- at the same
# size, so 'what actually changed' can be read off one image.
#
#   popcorn-glory/tools/contact_sheet.sh <shots dir> <project> <out.png>
#   (rows: click, perfect, explosion; a missing checkpoint is a grey tile)
set -euo pipefail
dir="$1"; project="$2"; out="$3"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
rows=()
for id in click perfect explosion; do
  tiles=()
  for mark in first_action first_upgrade 60s 180s; do
    f="$dir/${id}_${mark}_${project}.png"
    t="$tmp/${id}_${mark}.png"
    if [[ -f "$f" ]]; then
      ffmpeg -hide_banner -loglevel error -y -i "$f" -vf "scale=270:-2,pad=280:ih+10:5:5:0x333333" "$t"
    else
      ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=0x777777:s=280x490" -frames:v 1 "$t"
    fi
    tiles+=("$t")
  done
  r="$tmp/row_${id}.png"
  ffmpeg -hide_banner -loglevel error -y -i "${tiles[0]}" -i "${tiles[1]}" -i "${tiles[2]}" -i "${tiles[3]}" \
    -filter_complex "[0][1][2][3]scale2ref=oh*mdar:ih[a][b];[a][1]hstack[x];[x][2][3]hstack=inputs=3" "$r" 2>/dev/null \
    || ffmpeg -hide_banner -loglevel error -y -i "${tiles[0]}" -i "${tiles[1]}" -i "${tiles[2]}" -i "${tiles[3]}" -filter_complex "[0][1][2][3]hstack=inputs=4" "$r"
  rows+=("$r")
done
ffmpeg -hide_banner -loglevel error -y -i "${rows[0]}" -i "${rows[1]}" -i "${rows[2]}" -filter_complex "[0][1][2]vstack=inputs=3" "$out"
echo "contact sheet: $out"
