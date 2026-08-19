#!/usr/bin/env python3
"""Adopted room art -> motorio/assets/room/.

    python3 motorio/tools/sprite/build_room.py

Reads the chosen candidate for each piece, trims it to what is actually drawn,
and writes it at twice the size the game draws it. Nothing here regenerates
anything: `gen_room.py` makes candidates and this file names which one ships, so
a regeneration cannot quietly change the game.

## Why the pieces are trimmed and the surfaces are not

A keyed cutout has a margin of nothing around it, and how much is whatever the
model felt like -- so a sofa and a bed adopted straight would sit at two
different scales inside their cells. Trimming to the alpha bounding box makes
"the size it is drawn at" mean the size of the furniture rather than the size of
the picture around it.

The floor and the wall have no subject to trim to. They are stretched across
their whole surface rather than tiled: the generator's output is only roughly
seamless, and a visible seam every eight cells is worse than planks that are a
little longer than they would be at 1:1.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent
ROOM = HERE / "room"
GAME = REPO / "motorio" / "assets" / "room"

## Anything at or below this is matting residue rather than art.
ALPHA_FLOOR = 16

## name -> (candidate, width x height in game pixels). The room draws a cell at
## Defs.TILE, so a 2x1 piece is 64x32 and is stored at twice that.
##
## The reasons for the choices that were not the first candidate:
##   window   gen1 had the cat from the style plate sitting in the pane.
##   door     gen1 put a travelling bag on the step, gen2 and gen3 put Grim in
##            the opening. A door-shaped hole is a character-shaped hole; gen4
##            is shut, and there is nothing to stand in.
ADOPTED = {
    "floor": ("floor_gen1", (256, 192)),
    "wall": ("wall_gen1", (256, 64)),
    "fireplace": ("fireplace_gen1", (128, 128)),
    "bed": ("bed_gen1", (64, 128)),
    "window_night": ("window_gen2", (128, 64)),
    "window_day": ("window_day_gen1", (128, 64)),
    "sofa": ("sofa_gen1", (128, 64)),
    "door": ("door_gen4", (128, 64)),
}
SURFACES = {"floor", "wall"}


def trim(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A").point(lambda v: 255 if v > ALPHA_FLOOR else 0)
    box = alpha.getbbox()
    return image if box is None else image.crop(box)


def main() -> int:
    GAME.mkdir(parents=True, exist_ok=True)
    for name, (candidate, size) in ADOPTED.items():
        source = ROOM / f"{candidate}.png"
        if not source.is_file():
            print(f"없음: {source}", file=sys.stderr)
            return 1
        art = Image.open(source).convert("RGBA")
        if name not in SURFACES:
            art = trim(art)
        target = GAME / f"{name}.png"
        art.resize(size, Image.LANCZOS).save(target)
        print("방: %-13s <- %s  %dx%d" % (name, candidate, size[0], size[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
