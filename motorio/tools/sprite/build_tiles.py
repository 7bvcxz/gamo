#!/usr/bin/env python3
"""Cuts the ground tile sheet into the atlas the game draws.

    python3 tools/sprite/build_tiles.py

The output is committed. This does not run at build time; re-run it when the
source sheet changes.

Two decisions are baked in here rather than left to the caller, because both
were measured and neither is a matter of taste.

**Where a tile ends.** The source is 4x4 tiles separated by a white gutter about
six pixels wide, and each tile carries its own dark outline just inside that.
Cutting on the raw 313.5 pixel pitch keeps the gutter, and laying those
edge-to-edge gives a white line around every cell -- a bathroom floor rather
than a snowfield. Cutting seven pixels in drops the gutter and keeps the
outline, so the tiles touch and the grid reads as quilting.

**How big.** 64. A world tile is 32 world pixels and the camera never zooms past
2.56, so a tile covers at most 82 device pixels in ordinary play -- 29 on a
default desktop, 51 on a default phone. At those sizes a 64 source and a 128
source are indistinguishable, because the art is soft painted snow with no
crisp detail to lose, and 128 costs 291 KB against 78 KB for pixels nobody is
shown. The one case that exceeds 82 is the nightfall push-in at maximum zoom,
which reaches about 139 -- five seconds of a deliberately dark scene.
"""

from pathlib import Path

from PIL import Image

GAME = Path(__file__).resolve().parent.parent.parent
SOURCE = GAME / "tools" / "sprite" / "tiles" / "tile_org_16.png"
OUTPUT = GAME / "assets" / "tiles" / "ground_16.png"

COLUMNS = 4
ROWS = 4
## Pixels to cut in from each cell edge: past the white gutter, short of the
## drawn outline. Measured off the sheet -- the gutter runs to x=5 and the
## outline sits at x=7.
INSET = 7
CELL = 64


def main() -> None:
    sheet = Image.open(SOURCE).convert("RGB")
    pitch_x = sheet.size[0] / COLUMNS
    pitch_y = sheet.size[1] / ROWS
    atlas = Image.new("RGB", (CELL * COLUMNS, CELL * ROWS))
    for row in range(ROWS):
        for column in range(COLUMNS):
            box = (round(column * pitch_x) + INSET, round(row * pitch_y) + INSET,
                   round((column + 1) * pitch_x) - INSET, round((row + 1) * pitch_y) - INSET)
            tile = sheet.crop(box).resize((CELL, CELL), Image.LANCZOS)
            atlas.paste(tile, (column * CELL, row * CELL))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT, optimize=True)
    print("TILES: %s -> %s  %dx%d, %d tiles of %d, %d bytes"
          % (SOURCE.name, OUTPUT.relative_to(GAME), atlas.size[0], atlas.size[1],
             COLUMNS * ROWS, CELL, OUTPUT.stat().st_size))


if __name__ == "__main__":
    main()
