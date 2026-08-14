#!/usr/bin/env python3
"""Ore seam sheets, generated.

    python3 tools/sprite/gen_tiles.py --dry-run
    python3 tools/sprite/gen_tiles.py heatstone
    python3 tools/sprite/build_rock6.py heatstone     # then cut it

Writes tools/sprite/tiles/tile_<name>_6.png -- the 3x2 page build_rock6.py
expects. The prompts live here for the reason every other prompt in this
directory does: a picture that cannot be regenerated can only be replaced.

## The layout is the prompt's job, and the reference does most of it

Six tiles on one page, in a grid, with the ore arranged differently on each.
Asking for that in words alone gives six pictures of a mineral; passing the
crystal sheet as a reference gives the same page with a different mineral on
it, which is what the atlas cutter is measuring against. The cutter finds each
tile by its own painted bounds, so the gutters have to stay white.

## Heat stone is not copper

They are both warm, and at 64 pixels on snow a player has to tell them apart
without reading anything. Copper is metallic: bright nuggets with a hard
specular edge. Heat stone is burning: dark rounded pebbles with molten cracks
and a glow that spills onto the snow around them. Different value, different
edge, different light -- three differences, because one is not enough at that
size.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TILES = HERE / "tiles"
## The page every ore sheet is drawn on. Passed as a reference so the six tiles
## land in a grid with white between them.
REFERENCE = TILES / "tile_crystal_6.png"

LAYOUT = (
    "A 3 by 2 grid of six separate square game tiles on a plain white page, "
    "evenly spaced with wide white gutters between them and a white margin "
    "around the outside. Every tile is the same rounded square of clean pale "
    "snow with a few tiny grey pebbles and dry grass tufts near its corners. "
    "The six tiles differ only in how the cluster on them is arranged: a round "
    "clump in the middle, a diagonal streak, two separate small clumps, a "
    "crescent, a triangle, and six pieces scattered apart. Seen from directly "
    "overhead, looking straight down, with no tilt and no perspective. Cute "
    "cozy chibi game art style with soft watercolour shading and fine pencil "
    "outlines, matching the reference image."
)

SHEETS = {
    "heatstone": (
        "Clusters of glowing ember stones on snow. Each stone is a rounded dark "
        "charcoal pebble split by molten orange-red cracks, lit from inside, "
        "spilling a soft warm glow and a faint orange tint onto the snow "
        "immediately around it. " + LAYOUT),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("name", nargs="?", default="", help="one sheet, or all")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--quality", default="low")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    for name, prompt in SHEETS.items():
        if args.name and args.name != name:
            continue
        target = TILES / f"tile_{name}_6.png"
        if target.exists() and not args.force and not args.dry_run:
            print(f"있음, 건너뜀: {target.name}  (--force 로 다시)")
            continue
        command = ["imagegen", prompt, "--ref", str(REFERENCE), "--out", str(target),
                   "--size", "1536x1024", "--quality", args.quality]
        if args.force:
            command.append("--force")
        if args.dry_run:
            command.append("--dry-run")
        print(f"── {name}")
        result = subprocess.run(command)
        if result.returncode != 0:
            print(f"실패: {name}", file=sys.stderr)
            return result.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
