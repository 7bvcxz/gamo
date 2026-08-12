#!/usr/bin/env python3
"""Cuts a six-tile sheet into the atlas the game draws.

    python3 tools/sprite/build_rock6.py            # every sheet below
    python3 tools/sprite/build_rock6.py crystal    # just one

The output is committed. Re-run it when the source sheet changes.

These are not terrain that connects. Each tile is snow with a few boulders on
it, they have no relationship to each other, and the game drops them at random
-- so there is no autotiling here and no mask, which is the whole reason this
sheet works where the last two did not. A tile that does not have to agree with
its neighbour cannot disagree with it.

Cut to each tile's own painted bounds rather than on the 512 grid. The six are
not registered inside their cells: the white page margin around them runs from
15 to 48 pixels depending on the tile, so a fixed inset either keeps the margin
on some or eats the art on others. Measuring each one puts all six at the same
size in the atlas, which is what a random pick needs.

64 pixels, for the reason build_tiles.py gives: a cell is 32 world pixels and
the camera stops at 2.56, so 82 device pixels is the most a tile is ever drawn
at, and the art is soft enough that more is paid for and thrown away.
"""

import sys
from pathlib import Path

from PIL import Image

GAME = Path(__file__).resolve().parent.parent.parent
TILES = GAME / "tools" / "sprite" / "tiles"
ASSETS = GAME / "assets" / "tiles"
## Every sheet cut the same way. Ore joined boulders here when ore stopped being
## a structure the player walks around and became terrain they walk over -- the
## same kind of thing, so the same tool rather than a second copy of it.
SHEETS = {
    "rock": ("tile_rock_6.png", "rock_6.png"),
    "crystal": ("tile_crystal_6.png", "crystal_6.png"),
}

COLUMNS = 3
ROWS = 2
CELL = 64
## Anything brighter than this on all three channels is the page, not the tile.
PAGE = 248


def bounds(sheet: Image.Image, column: int, row: int, pitch_x: float, pitch_y: float) -> tuple:
    px = sheet.load()
    x0, y0 = int(column * pitch_x), int(row * pitch_y)
    width, height = int(pitch_x), int(pitch_y)

    def painted(x: int, y: int) -> bool:
        r, g, b = px[x0 + x, y0 + y]
        return not (r > PAGE and g > PAGE and b > PAGE)

    # Scanned along the middle of each side, where the tile is widest.
    left = next(d for d in range(width // 2) if painted(d, height // 2))
    right = next(d for d in range(width // 2) if painted(width - 1 - d, height // 2))
    top = next(d for d in range(height // 2) if painted(width // 2, d))
    bottom = next(d for d in range(height // 2) if painted(width // 2, height - 1 - d))
    return (x0 + left, y0 + top, x0 + width - right, y0 + height - bottom)


def cut(source: Path, output: Path) -> None:
    sheet = Image.open(source).convert("RGB")
    pitch_x = sheet.size[0] / COLUMNS
    pitch_y = sheet.size[1] / ROWS
    atlas = Image.new("RGB", (CELL * COLUMNS, CELL * ROWS))
    sizes = []
    for row in range(ROWS):
        for column in range(COLUMNS):
            box = bounds(sheet, column, row, pitch_x, pitch_y)
            sizes.append((box[2] - box[0], box[3] - box[1]))
            atlas.paste(sheet.crop(box).resize((CELL, CELL), Image.LANCZOS),
                        (column * CELL, row * CELL))
    atlas.save(output, optimize=True)
    spread = max(max(s) for s in sizes) - min(min(s) for s in sizes)
    print("TILES: %s -> %s  %dx%d, %d tiles of %d, %d bytes"
          % (source.name, output.relative_to(GAME), atlas.size[0], atlas.size[1],
             COLUMNS * ROWS, CELL, output.stat().st_size))
    print("TILES: source tiles measured %s, spread %d px"
          % (" ".join("%dx%d" % s for s in sizes), spread))


def main() -> int:
    wanted = sys.argv[1:] or sorted(SHEETS)
    unknown = [name for name in wanted if name not in SHEETS]
    if unknown:
        print("모르는 시트: %s (아는 것: %s)" % (", ".join(unknown), ", ".join(sorted(SHEETS))),
              file=sys.stderr)
        return 1
    ASSETS.mkdir(parents=True, exist_ok=True)
    for name in wanted:
        source, output = SHEETS[name]
        cut(TILES / source, ASSETS / output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
