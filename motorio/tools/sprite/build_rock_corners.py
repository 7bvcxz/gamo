#!/usr/bin/env python3
"""Assembles the 47 rock tiles out of a 20-piece corner sheet.

    python3 tools/sprite/build_rock_corners.py tools/sprite/tiles/tile_rock_20.png --quadrant=SE
    python3 tools/sprite/build_rock_corners.py --synthetic     # proof, no sheet needed

**The game does not draw rock.** It did for a few versions and the ground read
worse for it -- dark slabs on a snowfield, which is not what the plateau wants
to look like -- so the floor is snow again. This tool and the sheets it reads
are kept because the work in them is the hard part and none of it is wrong: it
assembles a mathematically complete 47-blob and proves the seams. If rock comes
back, run it and wire assets/tiles/rock_47.png and scripts/RockTiles.gd back
into GroundLayer -- both are generated here, and both were deleted when the
feature was.

Why this exists is in CORNER_TILESET_REQUEST.md. Briefly: a tile is 2x2
quadrants, a quadrant's picture depends only on its two adjacent orthogonal
neighbours and the diagonal between them, and there are five such pictures. Draw
five, get 47. The seams cannot misalign because every piece meets its neighbour
along an edge both of them were drawn to, rather than because 47 separate
drawings happened to agree.

Sheet layout: 4 columns x 5 rows of square pieces.
  rows    INNER, NOTCH, SIDE_A, SIDE_B, OUTER
  columns NW, NE, SE, SW  (which quadrant of the tile the piece is for)

--synthetic builds the same 20 pieces from flat colour instead of art. It is not
for shipping; it is how the geometry was checked before anyone spent a
generation on the real thing, and it stays so the check can be repeated.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

GAME = Path(__file__).resolve().parent.parent.parent
ATLAS_OUT = GAME / "assets" / "tiles" / "rock_47.png"
TABLE_OUT = GAME / "scripts" / "RockTiles.gd"

CELL = 64                      ## finished tile size
PIECE = CELL // 2              ## one quadrant
ROWS = ["INNER", "NOTCH", "SIDE_A", "SIDE_B", "OUTER"]
## Column order, and what each quadrant's two orthogonal neighbours are.
QUADRANTS = [("NW", "N", "W"), ("NE", "N", "E"), ("SE", "S", "E"), ("SW", "S", "W")]

N, E, S, W, NE, SE, SW, NW = 1, 2, 4, 8, 16, 32, 64, 128
BIT = {"N": N, "E": E, "S": S, "W": W}
DIAGONAL = {"NW": NW, "NE": NE, "SE": SE, "SW": SW}
PAIR = {NE: (N, E), SE: (S, E), SW: (S, W), NW: (N, W)}


def canonical(mask: int) -> int:
    out = mask & 15
    for diagonal, (a, b) in PAIR.items():
        if mask & diagonal and mask & a and mask & b:
            out |= diagonal
    return out


def piece_for(mask: int, quadrant: str, first: str, second: str) -> str:
    """Which of the five pictures this quadrant of this tile needs.

    `first` is the quadrant's vertical neighbour (N or S), `second` its
    horizontal one (E or W). SIDE_A is the vertical boundary, so it is the case
    where only the horizontal neighbour is rock.
    """
    up = bool(mask & BIT[first])
    across = bool(mask & BIT[second])
    if up and across:
        return "INNER" if mask & DIAGONAL[quadrant] else "NOTCH"
    if across:
        return "SIDE_A"
    if up:
        return "SIDE_B"
    return "OUTER"


## Turning one quadrant's piece into another's. The outer corner is what moves:
## SE's is bottom-right, NW's is top-left, and so on, so the transform is
## whichever flip or turn carries one corner onto the other.
TO_QUADRANT = {
    ("SE", "NW"): [Image.ROTATE_180], ("SE", "NE"): [Image.FLIP_TOP_BOTTOM],
    ("SE", "SW"): [Image.FLIP_LEFT_RIGHT], ("SE", "SE"): [],
    ("NW", "SE"): [Image.ROTATE_180], ("NW", "NE"): [Image.FLIP_LEFT_RIGHT],
    ("NW", "SW"): [Image.FLIP_TOP_BOTTOM], ("NW", "NW"): [],
    ("NE", "SW"): [Image.ROTATE_180], ("NE", "NW"): [Image.FLIP_LEFT_RIGHT],
    ("NE", "SE"): [Image.FLIP_TOP_BOTTOM], ("NE", "NE"): [],
    ("SW", "NE"): [Image.ROTATE_180], ("SW", "SE"): [Image.FLIP_LEFT_RIGHT],
    ("SW", "NW"): [Image.FLIP_TOP_BOTTOM], ("SW", "SW"): [],
}


def load_pieces(path: Path, only: str = "") -> dict:
    """Cuts the sheet into twenty pieces.

    `only` names a quadrant column to take as the whole truth: that column's
    five pieces are used and the other three quadrants are derived by turning
    them. The request offers this as its fallback -- five pieces beat twenty
    that disagree -- and it is what a sheet needs when some columns are drawn
    correctly and others are not.
    """
    sheet = Image.open(path).convert("RGB")
    wide = sheet.size[0] / len(QUADRANTS)
    tall = sheet.size[1] / len(ROWS)
    # A hairline often separates the cells; sampling it reads as snow and can
    # flip an edge. Two percent in from every side clears it without touching
    # the midpoint the whole construction depends on.
    inset_x, inset_y = wide * 0.02, tall * 0.02

    def cut(row: int, column: int) -> Image.Image:
        box = (round(column * wide + inset_x), round(row * tall + inset_y),
               round((column + 1) * wide - inset_x), round((row + 1) * tall - inset_y))
        return sheet.crop(box).resize((PIECE, PIECE), Image.LANCZOS)

    pieces = {}
    for row, name in enumerate(ROWS):
        for column, (quadrant, _a, _b) in enumerate(QUADRANTS):
            if not only:
                pieces[(name, quadrant)] = cut(row, column)
                continue
            source = cut(row, [q for q, _a, _b in QUADRANTS].index(only))
            for step in TO_QUADRANT[(only, quadrant)]:
                source = source.transpose(step)
            pieces[(name, quadrant)] = source
    return pieces


ROCK = (150, 150, 152)
SNOW = (232, 238, 248)
LIP = (252, 253, 255)


def synthetic_pieces() -> dict:
    """The same twenty pieces in flat colour, drawn to the letter of the request.

    Every boundary meets an edge at that edge's exact midpoint, which is the one
    rule the whole construction rests on. Building the atlas from these and
    checking that neighbouring tiles join is what proves the rule is sufficient.
    """
    size = PIECE * 4           ## drawn large, then downsampled, so arcs are smooth
    half = size // 2
    pieces = {}
    for name in ROWS:
        base = Image.new("RGB", (size, size), SNOW)
        draw = ImageDraw.Draw(base)
        if name == "INNER":
            draw.rectangle([0, 0, size, size], fill=ROCK)
        elif name == "NOTCH":
            # Rock everywhere but a quarter disc of snow at the outer corner,
            # meeting both outer edges at their midpoints.
            draw.rectangle([0, 0, size, size], fill=ROCK)
            draw.pieslice([-half, -half, half, half], 0, 90, fill=SNOW)
            draw.arc([-half, -half, half, half], 0, 90, fill=LIP, width=3)
        elif name == "SIDE_A":
            # Only the horizontal neighbour is rock, so the rock comes in from
            # the side and the snow is above it: the boundary is HORIZONTAL.
            # Getting this the wrong way round is the easiest mistake here and
            # the verify step caught it -- 64 edges disagreed.
            draw.rectangle([0, half, size, size], fill=ROCK)
            draw.line([0, half, size, half], fill=LIP, width=3)
        elif name == "SIDE_B":
            # Only the vertical neighbour is rock: boundary VERTICAL.
            draw.rectangle([half, 0, size, size], fill=ROCK)
            draw.line([half, 0, half, size], fill=LIP, width=3)
        else:
            # Rock only at the inner corner, meeting both inner edges at their
            # midpoints -- the same radius as NOTCH, because the two sit side by
            # side around a corner.
            draw.pieslice([half, half, size + half, size + half], 180, 270, fill=ROCK)
            draw.arc([half, half, size + half, size + half], 180, 270, fill=LIP, width=3)
        piece = base.resize((PIECE, PIECE), Image.LANCZOS)
        # The drawing above is for the NW quadrant. The other three are it,
        # turned -- which is exactly what the request offers as its fallback.
        pieces[(name, "NW")] = piece
        pieces[(name, "NE")] = piece.transpose(Image.FLIP_LEFT_RIGHT)
        pieces[(name, "SE")] = piece.transpose(Image.ROTATE_180)
        pieces[(name, "SW")] = piece.transpose(Image.FLIP_TOP_BOTTOM)
    return pieces


def assemble(pieces: dict, mask: int) -> Image.Image:
    tile = Image.new("RGB", (CELL, CELL))
    at = {"NW": (0, 0), "NE": (PIECE, 0), "SE": (PIECE, PIECE), "SW": (0, PIECE)}
    for quadrant, first, second in QUADRANTS:
        name = piece_for(mask, quadrant, first, second)
        tile.paste(pieces[(name, quadrant)], at[quadrant])
    return tile


def rock_at(tile: Image.Image, x: int, y: int) -> bool:
    r, g, b = tile.getpixel((x, y))
    return 0.299 * r + 0.587 * g + 0.114 * b < 190


def verify(tiles: dict, masks: list) -> int:
    """Does a rock cell's rock actually reach every edge it shares with rock?

    Checked on the assembled tiles rather than on the pieces, because that is
    the property the player sees, and because an error in the quadrant wiring
    would leave the pieces perfectly correct and the tiles wrong.
    """
    bad = 0
    for mask in masks:
        tile = tiles[mask]
        middle = CELL // 2
        for side, bit in (("N", N), ("E", E), ("S", S), ("W", W)):
            spot = {"N": (middle, 1), "E": (CELL - 2, middle),
                    "S": (middle, CELL - 2), "W": (1, middle)}[side]
            reaches = rock_at(tile, *spot)
            if reaches != bool(mask & bit):
                print("  mask %3d: %s edge is %s but should be %s"
                      % (mask, side, "rock" if reaches else "snow",
                         "rock" if mask & bit else "snow"))
                bad += 1
    return bad


def _gdscript(lookup: list, count: int, source: str) -> str:
    rows = ["\t" + ", ".join("%d" % v for v in lookup[start:start + 16]) + ","
            for start in range(0, 256, 16)]
    return (
        "extends RefCounted\n"
        "class_name RockTiles\n"
        "\n"
        "## Generated by tools/sprite/build_rock_corners.py from %s.\n"
        "## Do not edit by hand.\n"
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
        "## Every configuration here is exact. The tiles are assembled from corner\n"
        "## pieces rather than drawn one by one, so a seam can only be wrong if the\n"
        "## five pieces disagree with each other -- not if 47 drawings do.\n"
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
        % (source, count, CELL, "\n".join(rows), count - 1)
    )


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    synthetic = "--synthetic" in sys.argv
    only = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--quadrant=")), "")
    if synthetic:
        pieces, source = synthetic_pieces(), "the synthetic proof pieces"
    elif args:
        path = Path(args[0])
        pieces = load_pieces(path, only)
        source = path.name + (" (%s column, turned)" % only if only else "")
    else:
        raise SystemExit(__doc__)

    masks = sorted({canonical(m) for m in range(256)})
    tiles = {mask: assemble(pieces, mask) for mask in masks}

    print("CORNERS: assembled %d tiles from %d pieces" % (len(tiles), len(pieces)))
    bad = verify(tiles, masks)
    print("CORNERS: %d edge mismatches" % bad)
    if bad:
        raise SystemExit("refusing to write an atlas whose rock does not join up")

    atlas = Image.new("RGB", (CELL * 8, CELL * ((len(masks) + 7) // 8)))
    for position, mask in enumerate(masks):
        atlas.paste(tiles[mask], ((position % 8) * CELL, (position // 8) * CELL))
    if synthetic:
        # A proof does not get to overwrite the shipping asset.
        out = Path("/tmp") / "rock_47_synthetic.png"
        atlas.save(out)
        print("CORNERS: proof atlas -> %s (not shipped)" % out)
        return
    ATLAS_OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(ATLAS_OUT, optimize=True)
    slot = {mask: position for position, mask in enumerate(masks)}
    TABLE_OUT.write_text(
        _gdscript([slot[canonical(m)] for m in range(256)], len(masks), source),
        encoding="utf-8")
    print("CORNERS: %s, %s" % (ATLAS_OUT.relative_to(GAME), TABLE_OUT.relative_to(GAME)))


if __name__ == "__main__":
    main()
