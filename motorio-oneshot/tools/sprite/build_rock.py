#!/usr/bin/env python3
"""Turns the painted rock sheet into an autotiling atlas plus its lookup table.

    python3 tools/sprite/build_rock.py

Writes assets/tiles/rock_47.png and scripts/RockTiles.gd. Both are committed;
re-run when the sheet changes.

The sheet is not a blob47, whatever its name says. Measured: 47 drawn tiles in
an 8x6 grid, and between them about fifteen distinct eight-neighbour
configurations -- the rest are second and third variants of the same shape
(five different "snow to the west" tiles), three tiles of plain snow with no
rock at all, and a row of decorative pebbles. Rotating and mirroring what is
there reaches 31 of the 47 configurations; the other sixteen are simply not
drawn.

So the mapping cannot come from a convention, and it does not come from reading
eight sample points off each tile either -- that was tried and the corner
samples land inside curved shapes often enough to be unreliable (12% of
readings fell in the ambiguous band). It comes from matching whole tiles
against synthesised ideals:

  1. For each of the 47 configurations, draw what the rock region ought to look
     like -- the cell, minus a margin on every side whose neighbour is snow,
     with the corners rounded or notched as the diagonals dictate.
  2. Binarise every tile, in all eight of its rotations and mirrors, at the same
     small resolution.
  3. Score each pairing by agreement and keep the best.

Configurations the sheet cannot draw fall back to the closest one it can, which
is what "best effort with what we have" means here: a junction here and there is
approximate, and no cell is ever left blank.

The atlas is baked with the rotations already applied, so the game indexes it
and nothing rotates at draw time.
"""

import json
from pathlib import Path

from PIL import Image

GAME = Path(__file__).resolve().parent.parent.parent
SOURCE = GAME / "tools" / "sprite" / "tiles" / "tile_rock_47.png"
ATLAS_OUT = GAME / "assets" / "tiles" / "rock_47.png"
TABLE_OUT = GAME / "scripts" / "RockTiles.gd"

## The sheet's artwork sits inside a cream page margin; these are measured, not
## assumed. Dividing the raw image by eight and six lands every sample a few
## pixels off and turns a full-rock tile into an edge tile.
ORIGIN = (14.0, 15.0)
SHEET = (1418.0, 1056.0)
COLUMNS, ROWS = 8, 6
BLANK = {47}

CELL = 64
GRID = 24          ## resolution the matching runs at
## How far the rock pulls back from a snow neighbour. Swept from 0.20 to 0.42:
## mean agreement moves only between 0.873 and 0.890, which says the ceiling is
## the sheet rather than the template. 0.34 is the best of them.
MARGIN = 0.34
ROCK_LUMA = 190

N, E, S, W, NE, SE, SW, NW = 1, 2, 4, 8, 16, 32, 64, 128
PAIR = {NE: (N, E), SE: (S, E), SW: (S, W), NW: (N, W)}


def canonical(mask: int) -> int:
    """A diagonal only counts when both of its orthogonals do, because that is
    the only case a tile can draw differently."""
    out = mask & 15
    for diagonal, (a, b) in PAIR.items():
        if mask & diagonal and mask & a and mask & b:
            out |= diagonal
    return out


def ideal(mask: int) -> list:
    """What the rock region of a cell with this mask ought to look like."""
    grid = []
    for row in range(GRID):
        y = (row + 0.5) / GRID
        line = []
        for column in range(GRID):
            x = (column + 0.5) / GRID
            rock = True
            # Pull back from every side whose neighbour is snow.
            if not mask & N and y < MARGIN:
                rock = False
            if not mask & S and y > 1.0 - MARGIN:
                rock = False
            if not mask & W and x < MARGIN:
                rock = False
            if not mask & E and x > 1.0 - MARGIN:
                rock = False
            # Where two sides pulled back, the rock corner between them is
            # round rather than square.
            for diagonal, (a, b) in PAIR.items():
                if mask & a or mask & b:
                    continue
                cx = MARGIN if diagonal in (NW, SW) else 1.0 - MARGIN
                cy = MARGIN if diagonal in (NW, NE) else 1.0 - MARGIN
                if (x - cx) * (1 if diagonal in (NE, SE) else -1) > 0 and \
                   (y - cy) * (1 if diagonal in (SE, SW) else -1) > 0:
                    if (x - cx) ** 2 + (y - cy) ** 2 > MARGIN ** 2:
                        rock = False
            # Where both sides are rock but the diagonal is not, a notch of snow
            # reaches in at that corner. This is the whole reason the diagonal
            # bits exist.
            for diagonal, (a, b) in PAIR.items():
                if not (mask & a and mask & b) or mask & diagonal:
                    continue
                cx = 0.0 if diagonal in (NW, SW) else 1.0
                cy = 0.0 if diagonal in (NW, NE) else 1.0
                if (x - cx) ** 2 + (y - cy) ** 2 < MARGIN ** 2:
                    rock = False
            line.append(rock)
        grid.append(line)
    return grid


def tile_image(sheet: Image.Image, index: int) -> Image.Image:
    column, row = index % COLUMNS, index // COLUMNS
    pitch_x, pitch_y = SHEET[0] / COLUMNS, SHEET[1] / ROWS
    x0 = ORIGIN[0] + column * pitch_x
    y0 = ORIGIN[1] + row * pitch_y
    # A pixel in from every side: the seams between tiles carry a hairline that
    # is neither rock nor snow, and it drags every edge reading toward snow.
    return sheet.crop((round(x0) + 2, round(y0) + 2,
                       round(x0 + pitch_x) - 2, round(y0 + pitch_y) - 2))


def binarise(image: Image.Image) -> list:
    small = image.convert("RGB").resize((GRID, GRID), Image.BOX).load()
    return [[(0.299 * small[c, r][0] + 0.587 * small[c, r][1]
              + 0.114 * small[c, r][2]) < ROCK_LUMA
             for c in range(GRID)] for r in range(GRID)]


TRANSFORMS = [
    ("", []), ("r90", [Image.ROTATE_270]), ("r180", [Image.ROTATE_180]),
    ("r270", [Image.ROTATE_90]),
    ("m", [Image.FLIP_LEFT_RIGHT]),
    ("mr90", [Image.FLIP_LEFT_RIGHT, Image.ROTATE_270]),
    ("mr180", [Image.FLIP_LEFT_RIGHT, Image.ROTATE_180]),
    ("mr270", [Image.FLIP_LEFT_RIGHT, Image.ROTATE_90]),
]


def apply(image: Image.Image, steps: list) -> Image.Image:
    for step in steps:
        image = image.transpose(step)
    return image


def agreement(a: list, b: list) -> float:
    same = sum(1 for r in range(GRID) for c in range(GRID) if a[r][c] == b[r][c])
    return same / float(GRID * GRID)


def touches(grid: list) -> int:
    """Which edges the rock actually reaches, as a mask of N/E/S/W.

    This is the property that has to be exact, and agreement alone will not give
    it. Two neighbouring rock cells whose tiles do not both reach the boundary
    between them read as two separate stones, and a field of them reads as a
    dotted line -- which is what the first build produced. Conversely a tile
    reaching an edge whose neighbour is snow spills rock into the snow cell.
    Silhouette is a preference; joining up is not.
    """
    low, high = GRID // 3, GRID - GRID // 3
    mask = 0
    if any(grid[0][c] for c in range(low, high)):
        mask |= N
    if any(grid[r][GRID - 1] for r in range(low, high)):
        mask |= E
    if any(grid[GRID - 1][c] for c in range(low, high)):
        mask |= S
    if any(grid[r][0] for r in range(low, high)):
        mask |= W
    return mask


def main() -> None:
    sheet = Image.open(SOURCE).convert("RGB")
    candidates = []
    for index in range(COLUMNS * ROWS):
        if index in BLANK:
            continue
        base = tile_image(sheet, index)
        for name, steps in TRANSFORMS:
            image = apply(base, steps)
            grid = binarise(image)
            candidates.append((index, name, image, grid, touches(grid)))

    masks = sorted({canonical(m) for m in range(256)})
    chosen = {}
    for mask in masks:
        want = ideal(mask)
        # Connectivity first, silhouette second. Every one of the sixteen edge
        # combinations exists somewhere in the sheet once rotations are counted,
        # so this filter never empties -- but the fallback is kept because a
        # changed sheet should degrade rather than crash.
        pool = [c for c in candidates if c[4] == mask & 15] or candidates
        best = max(pool, key=lambda c: agreement(want, c[3]))
        chosen[mask] = (best[0], best[1], agreement(want, best[3]), best[2])

    atlas = Image.new("RGB", (CELL * 8, CELL * ((len(masks) + 7) // 8)))
    slot = {}
    for position, mask in enumerate(masks):
        slot[mask] = position
        atlas.paste(chosen[mask][3].resize((CELL, CELL), Image.LANCZOS),
                    ((position % 8) * CELL, (position // 8) * CELL))
    ATLAS_OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(ATLAS_OUT, optimize=True)

    lookup = [slot[canonical(m)] for m in range(256)]
    scores = sorted(chosen[m][2] for m in masks)
    exact = sum(1 for m in masks if chosen[m][2] >= 0.93)
    TABLE_OUT.write_text(_gdscript(lookup, len(masks), exact, scores), encoding="utf-8")

    print("ROCK: %d configurations -> %s (%dx%d)"
          % (len(masks), ATLAS_OUT.relative_to(GAME), atlas.size[0], atlas.size[1]))
    print("ROCK: agreement  worst %.2f  median %.2f  best %.2f  ·  %d/%d above 0.93"
          % (scores[0], scores[len(scores) // 2], scores[-1], exact, len(masks)))
    print("ROCK: table -> %s" % TABLE_OUT.relative_to(GAME))
    weak = [(m, chosen[m][2]) for m in masks if chosen[m][2] < 0.86]
    print("ROCK: %d approximations below 0.86: %s"
          % (len(weak), ", ".join("%d(%.2f)" % w for w in weak[:12])))


def _gdscript(lookup: list, count: int, exact: int, scores: list) -> str:
    rows = []
    for start in range(0, 256, 16):
        rows.append("\t" + ", ".join("%d" % v for v in lookup[start:start + 16]) + ",")
    return (
        "extends RefCounted\n"
        "class_name RockTiles\n"
        "\n"
        "## Generated by tools/sprite/build_rock.py. Do not edit by hand.\n"
        "##\n"
        "## Which cell of assets/tiles/rock_47.png a rock cell draws, indexed by\n"
        "## its eight neighbours: bit 1 north, 2 east, 4 south, 8 west, 16 north-\n"
        "## east, 32 south-east, 64 south-west, 128 north-west.\n"
        "##\n"
        "## 256 entries rather than %d because the caller should not have to know\n"
        "## that a diagonal only matters when both of its orthogonals are rock.\n"
        "## The table folds that rule in, so a raw neighbour mask indexes it\n"
        "## directly and two masks that must look the same cannot drift apart.\n"
        "##\n"
        "## The source sheet does not contain all %d configurations -- see the\n"
        "## tool's header -- so %d of them are exact and the rest are the closest\n"
        "## shape it does contain. Agreement against the ideal runs %.2f to %.2f.\n"
        "const ATLAS: Texture2D = preload(\"res://assets/tiles/rock_47.png\")\n"
        "const ATLAS_COLUMNS := 8\n"
        "const CELL := %d.0\n"
        "\n"
        "const LOOKUP: Array[int] = [\n%s\n]\n"
        "\n"
        "## Where in the atlas one of those cells lives.\n"
        "static func region(slot: int) -> Rect2:\n"
        "\tvar index: int = clampi(slot, 0, %d)\n"
        "\treturn Rect2(float(index %% ATLAS_COLUMNS) * CELL,\n"
        "\t\tfloat(index / ATLAS_COLUMNS) * CELL, CELL, CELL)\n"
        % (count, count, exact, scores[0], scores[-1], CELL,
           "\n".join(rows), count - 1)
    )


if __name__ == "__main__":
    main()
