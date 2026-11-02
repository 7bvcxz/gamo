#!/usr/bin/env bash
# The comparison page's pictures and numbers (Step 93), into web/compare/:
#   1. each experiment played fresh in the deployed build at 720x1280 and
#      photographed at 5 s, 1:00 and 3:00 (tests/e2e/specs/compare93.spec.mjs),
#   2. the labelled grid of all eighteen (tools/compare_grid.gd),
#   3. the scripted player's three minutes of each (tools/selftest.gd).
# Run tools/deploy.sh first (the pictures are of what is deployed), then this,
# then tools/deploy.sh again to publish them beside the Lab.
set -euo pipefail
LAB="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$LAB/web/compare"
RAW="$(mktemp -d)"
trap 'rm -rf "$RAW"' EXIT
mkdir -p "$OUT"
FUNLAB_COMPARE_OUT="$RAW" "$LAB/tools/e2e.sh" specs/compare93.spec.mjs --project p720 -g "fresh three minutes"
xvfb-run -a -s "-screen 0 2000x1700x24" godot --path "$LAB" --audio-driver Dummy --script res://tools/compare_grid.gd -- "$RAW" "$RAW/grid.png" >/dev/null 2>&1
godot --headless --path "$LAB" --script res://tools/compare_jpg.gd -- "$RAW" "$OUT" >/dev/null 2>&1
godot --headless --path "$LAB" --script res://tools/selftest.gd -- --json "$OUT/selftest.json" >/dev/null 2>&1
ls -la "$OUT"
