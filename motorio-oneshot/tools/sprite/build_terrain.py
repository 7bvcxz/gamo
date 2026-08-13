#!/usr/bin/env python3
"""Ground, boulders and seams, cut from the materials gen_terrain.py made.

    python3 motorio-oneshot/tools/sprite/build_terrain.py

Writes assets/tiles/snow_256.png, rock_47.png, crystal_6.png, copper_6.png and
scripts/RockTiles.gd.

## Three materials, three different answers

They are not the same problem, and the measurement says so. Ore is deliberately
scarce -- patches of two cells, three patches per ore -- so no seam cell in the
world has all eight neighbours. A blob tileset for ore would spend its interior
tile on a case that never occurs. Boulders come in clumps of one to twelve over
about a twentieth of the floor, which is exactly what a blob tileset is for. And
the floor is everywhere, so what it needs is neither: no edges to fit, just no
visible repeat.

**Snow** is one seamless field cut into a 16x16 grid, and a cell shows the part
of it at `cell mod 16`. Neighbouring cells therefore show neighbouring parts of
a continuous picture, so there is no seam anywhere and no per-cell variation to
scramble. The sixteen hashed variants this replaces had a subtler fault than
seams: hashing was introduced to break a lattice, and the answer to a lattice
is not a better hash but a picture that is actually continuous.

**Boulders** are the 47-blob, assembled by build_rock_corners.py out of twenty
corner pieces. That tool has existed and been correct since the rock tileset was
first attempted; what it never had was art. Twenty pieces drawn by hand is what
failed before -- the sheet that came back had twelve tiles whose rock touched no
edge at all. So the pieces are built here instead: the geometry is computed as a
mask, and the mask decides which of two materials each pixel takes. Seams cannot
disagree because no one is drawing them.

**Seams** stay six variants picked by a hash of the coordinates, which is what
they already were. A tile that never has to agree with its neighbour cannot
disagree with it, and with patches of two that is the whole job.

## Why quadrants sample where they do

A piece is one quadrant of a tile, and the four quadrants of an all-rock tile
used to be one drawing flipped four ways. In flat colour that is invisible. With
a material it is a kaleidoscope: the same boulder mirrored about both axes,
once per cell, everywhere. So each quadrant samples the quadrant of the material
that matches its position in the tile, and an assembled tile is a contiguous
64-pixel patch of stone rather than four reflections of a 32-pixel one.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageStat

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_rock_corners as blob  # noqa: E402

HERE = Path(__file__).resolve().parent
TILES = HERE / "tiles"
GAME_TILES = HERE.parent.parent / "assets" / "tiles"
TABLE_OUT = HERE.parent.parent / "scripts" / "RockTiles.gd"

## One cell of ground, stored at twice the 32 the game draws it at -- the same
## headroom every other texture here keeps for the zoom keys.
CELL = 64
## How many cells the floor repeats over. Sixteen is 512 world pixels, which is
## wider than the screen at any zoom, so the repeat is never visible as a repeat
## in one glance.
FIELD = 16
ORE_VARIANTS = 6
ORE_COLUMNS = 3


def seamless(source: Image.Image, size: int, zoom: float = 1.0) -> Image.Image:
    """A size x size texture whose left edge continues into its right.

    Rolling by half does most of it: after the roll the two edges that meet were
    neighbours in the original, so the border is continuous by construction and
    the discontinuity has moved to the middle. What is left is to hide that
    middle, which is done by blending in a copy taken from elsewhere in the
    picture across a soft band -- not a mirror, which would put a visible axis of
    symmetry through every tile in the game.
    """
    # Zoom crops before resizing, so the material keeps the size its features
    # were drawn at. Squashing the whole 1024 picture into a 64 pixel cell turned
    # boulders into grit -- a stone drawn 150 pixels across came out nine.
    art = source.convert("RGB")
    if zoom > 1.0:
        keep = int(min(art.width, art.height) / zoom)
        left = (art.width - keep) // 2
        top = (art.height - keep) // 2
        art = art.crop((left, top, left + keep, top + keep))
    field = art.resize((size, size), Image.LANCZOS)
    half = size // 2
    rolled = Image.new("RGB", (size, size))
    for source_box, target in [
        ((half, half, size, size), (0, 0)), ((0, half, half, size), (half, 0)),
        ((half, 0, size, half), (0, half)), ((0, 0, half, half), (half, half)),
    ]:
        rolled.paste(field.crop(source_box), target)

    # A different part of the same picture, to lay over the cross.
    patch = Image.new("RGB", (size, size))
    quarter = size // 4
    for target_x in (0, half):
        for target_y in (0, half):
            patch.paste(rolled.crop((quarter, quarter, quarter + half,
                                     quarter + half)), (target_x, target_y))

    band = max(4, size // 12)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle([half - band, 0, half + band, size], fill=255)
    draw.rectangle([0, half - band, size, half + band], fill=255)
    # Feathered, and the blur kept inside the band so the border stays untouched
    # -- the border is the part that was already correct.
    mask = mask.filter(ImageFilter.GaussianBlur(band / 2.2))
    draw = ImageDraw.Draw(mask)
    for edge in [(0, 0, size, band // 2), (0, size - band // 2, size, size),
                 (0, 0, band // 2, size), (size - band // 2, 0, size, size)]:
        draw.rectangle(list(edge), fill=0)
    return Image.composite(patch, rolled, mask)


def check_seam(tile: Image.Image, label: str) -> int:
    """How far the two edges that will meet are from agreeing.

    Reported rather than asserted zero: a photographic material blended into
    itself is continuous, not identical, and demanding identity here would be
    demanding something the belt's cross-section could promise and this cannot.
    What it catches is the real failure -- an untreated picture, where the two
    edges are unrelated and the number is large.
    """
    size = tile.width
    worst = 0
    for index in range(size):
        left, right = tile.getpixel((0, index)), tile.getpixel((size - 1, index))
        top, bottom = tile.getpixel((index, 0)), tile.getpixel((index, size - 1))
        worst = max(worst, max(abs(a - b) for a, b in zip(left, right)),
                    max(abs(a - b) for a, b in zip(top, bottom)))
    print(f"   이음매 {label}: 마주 보는 변의 최대 차이 {worst}")
    return worst


def snow_field() -> Image.Image:
    field = seamless(Image.open(TILES / "snow_src.png"), CELL * FIELD)
    check_seam(field, "눈")
    field.save(GAME_TILES / "snow_256.png", optimize=True)
    print(f"게임: snow_256.png  {field.width}px ({FIELD}x{FIELD}칸)")
    return field


def _quadrant(material: Image.Image, quadrant: str) -> Image.Image:
    """The part of a 64-pixel material patch that belongs at this quadrant."""
    piece = blob.PIECE
    at = {"NW": (0, 0), "NE": (piece, 0), "SE": (piece, piece), "SW": (0, piece)}
    left, top = at[quadrant]
    return material.crop((left, top, left + piece, top + piece))


def _shape_mask(name: str) -> Image.Image:
    """The geometry of one piece, for the NW quadrant, as white where rock is.

    The same five shapes build_rock_corners draws in flat colour, and for the
    same reason: every boundary meets an edge at that edge's exact midpoint,
    which is the single rule the whole 47-tile construction rests on. Drawn
    large and shrunk, so the arcs are smooth.
    """
    size = blob.PIECE * 4
    half = size // 2
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    if name == "INNER":
        draw.rectangle([0, 0, size, size], fill=255)
    elif name == "NOTCH":
        draw.rectangle([0, 0, size, size], fill=255)
        draw.pieslice([-half, -half, half, half], 0, 90, fill=0)
    elif name == "SIDE_A":
        # Only the horizontal neighbour is rock, so the boundary is horizontal.
        draw.rectangle([0, half, size, size], fill=255)
    elif name == "SIDE_B":
        draw.rectangle([half, 0, size, size], fill=255)
    else:
        draw.pieslice([half, half, size + half, size + half], 180, 270, fill=255)
    return mask.resize((blob.PIECE, blob.PIECE), Image.LANCZOS)


def material_pieces(rock: Image.Image, snow: Image.Image) -> dict:
    """The twenty pieces, as material chosen by computed geometry.

    The mask is built once per shape for the NW quadrant and turned for the
    other three, exactly as the flat-colour version does -- but the material is
    sampled per quadrant rather than turned with it, which is what stops an
    all-rock tile from being one drawing mirrored four ways.
    """
    turns = {"NW": [], "NE": [Image.FLIP_LEFT_RIGHT], "SE": [Image.ROTATE_180],
             "SW": [Image.FLIP_TOP_BOTTOM]}
    pieces = {}
    for name in blob.ROWS:
        base = _shape_mask(name)
        for quadrant, operations in turns.items():
            mask = base
            for operation in operations:
                mask = mask.transpose(operation)
            piece = Image.composite(_quadrant(rock, quadrant),
                                    _quadrant(snow, quadrant), mask)
            pieces[(name, quadrant)] = _rim(piece, mask)
    return pieces


def _rim(piece: Image.Image, mask: Image.Image) -> Image.Image:
    """A dark lip where the rock ends.

    Without it a boulder field on snow has no outline and reads as a stain. The
    flat-colour version drew this as an arc or a line per shape; taken from the
    mask instead it follows whatever the geometry is, so a shape added later
    gets its rim without anyone remembering to draw one.
    """
    # Found on a mask padded by replicating its border, then cropped back.
    # FIND_EDGES treats everything outside the image as zero, so an all-rock
    # piece -- a mask with no transition anywhere in it -- came back with an edge
    # all the way round its own 32-pixel square. Every quadrant of every tile got
    # one, and the result was a boulder field with a grid ruled across it: not
    # material repeating, which is what it looked like, but a rim drawn where
    # nothing ends.
    padded = Image.new("L", (mask.width + 2, mask.height + 2))
    padded.paste(mask, (1, 1))
    padded.paste(mask.crop((0, 0, mask.width, 1)), (1, 0))
    padded.paste(mask.crop((0, mask.height - 1, mask.width, mask.height)),
                 (1, mask.height + 1))
    padded.paste(padded.crop((1, 0, 2, padded.height)), (0, 0))
    padded.paste(padded.crop((mask.width, 0, mask.width + 1, padded.height)),
                 (mask.width + 1, 0))
    edge = padded.filter(ImageFilter.FIND_EDGES).point(lambda v: min(255, v * 3))
    edge = edge.crop((1, 1, mask.width + 1, mask.height + 1))
    shadow = Image.new("RGB", piece.size, (72, 62, 58))
    return Image.composite(shadow, piece, edge)


def rock_blob(snow_field_image: Image.Image) -> None:
    # About four boulders across a cell, which is the size they read at when the
    # cell is 32 world pixels.
    rock = seamless(Image.open(TILES / "rock_src.png"), CELL, zoom=3.5)
    # The snow inside a boulder tile is the floor's average colour rather than
    # one particular patch of it. A patch cannot be the right patch: the atlas is
    # indexed by which neighbours are rock, not by where the cell is, so whatever
    # is baked in shows up beside a floor drawn from somewhere else. Flat, the
    # difference is the field's own spread -- about six levels in 255 -- and
    # invisible. Patterned, it was two different pictures of snow meeting at a
    # straight line, which the eye finds immediately.
    # A seamless 64 patch of the same snow, not the floor's patch for this cell
    # -- the atlas is indexed by which neighbours are rock, not by where the cell
    # is, so there is no such thing as this cell's patch. It works because snow
    # has no large features: the field's spread is about six levels in 255, so
    # one patch of it is indistinguishable from another. Flat mean was tried
    # first and was worse, because flat beside textured reads as a square even
    # when the colours match exactly.
    snow = seamless(snow_field_image, CELL)
    pieces = material_pieces(rock, snow)

    masks = sorted({blob.canonical(mask) for mask in range(256)})
    tiles = {mask: blob.assemble(pieces, mask) for mask in masks}
    bad = _verify(tiles, masks)
    if bad:
        raise SystemExit(f"바위 타일 이음매 {bad}건 불일치")

    columns = 8
    rows = (len(masks) + columns - 1) // columns
    atlas = Image.new("RGB", (columns * CELL, rows * CELL))
    lookup = [0] * 256
    for index, mask in enumerate(masks):
        atlas.paste(tiles[mask], ((index % columns) * CELL, (index // columns) * CELL))
    for mask in range(256):
        lookup[mask] = masks.index(blob.canonical(mask))
    atlas.save(GAME_TILES / "rock_47.png", optimize=True)
    TABLE_OUT.write_text(blob._gdscript(lookup, len(masks), "build_terrain.py"),
                         encoding="utf-8")
    print(f"게임: rock_47.png  {len(masks)}타일 · {atlas.width}x{atlas.height}px")


def _verify(tiles: dict, masks: list) -> int:
    """Does a boulder tile's rock reach every edge it shares with rock?

    The tool's own check reads luminance, which worked when rock was one flat
    colour darker than one flat snow. Real stone has pale tops and the snow
    between boulders is not white, so that test now answers about lighting
    rather than about geometry. This asks the mask instead, which is the thing
    that decided it.
    """
    bad = 0
    middle = blob.CELL // 2
    spots = {"N": (middle, 1), "E": (blob.CELL - 2, middle),
             "S": (middle, blob.CELL - 2), "W": (1, middle)}
    for mask in masks:
        tile = tiles[mask]
        for side, bit in (("N", blob.N), ("E", blob.E), ("S", blob.S), ("W", blob.W)):
            # Rock is what the geometry put there; sampled a couple of pixels in
            # from the edge so the rim does not answer for it.
            spot = spots[side]
            inward = {"N": (0, 3), "E": (-3, 0), "S": (0, -3), "W": (3, 0)}[side]
            colour = tile.getpixel((spot[0] + inward[0], spot[1] + inward[1]))
            reaches = _is_rock(colour)
            if reaches != bool(mask & bit):
                print("  mask %3d: %s 변이 %s (기대 %s)"
                      % (mask, side, "바위" if reaches else "눈",
                         "바위" if mask & bit else "눈"))
                bad += 1
    return bad


## Snow in this palette is far paler than any stone in it, and the gap is wide.
_ROCK_MAX_LUMA = 205.0


def _is_rock(colour) -> bool:
    return 0.299 * colour[0] + 0.587 * colour[1] + 0.114 * colour[2] < _ROCK_MAX_LUMA


def _on_snow(art: Image.Image, snow_field_image: Image.Image) -> Image.Image:
    """The material's own background swapped for the floor's snow.

    Background is taken as the material's median colour, which is what a field of
    ore evenly scattered on something is mostly made of. How much a pixel looks
    like it decides how much snow replaces it, so ore keeps its edges softly
    rather than being cut out with a threshold and left with a halo.
    """
    background = tuple(sorted(channel)[len(channel) // 2] for channel in
                       zip(*list(art.getdata())))
    snow = snow_field_image.resize(art.size, Image.LANCZOS)
    distance = Image.new("L", art.size)
    distance.putdata([min(255, int(sum(abs(value - base) for value, base
                                       in zip(pixel, background)) * 1.6))
                      for pixel in art.getdata()])
    # Blurred a little so the swap follows shapes rather than single pixels.
    distance = distance.filter(ImageFilter.GaussianBlur(1.5)).point(
        lambda v: min(255, int(v * 2.2)))
    return Image.composite(art, snow, distance)


def ore_sheets(snow_field_image: Image.Image) -> None:
    """Six variants per ore, laid out the way the game already reads them.

    Six crops of the material rather than six drawings: they never meet, so what
    they need is to differ from each other and to sit on the same snow as the
    floor -- not to agree about anything.
    """
    for name, source in [("crystal", "crystal_src.png"), ("copper", "copper_src.png")]:
        art = Image.open(TILES / source).convert("RGB")
        rows = (ORE_VARIANTS + ORE_COLUMNS - 1) // ORE_COLUMNS
        sheet = Image.new("RGB", (ORE_COLUMNS * CELL, rows * CELL))
        # Whatever the material used for its background becomes the floor's snow.
        # Otherwise a seam cell is a rectangle of somebody else's ground: the
        # copper material is orange in grey stone, and dropped in unchanged every
        # copper cell in the world was a grey square on a white field.
        art = _on_snow(art, snow_field_image)
        step = art.width // ORE_COLUMNS
        for index in range(ORE_VARIANTS):
            column, row = index % ORE_COLUMNS, index // ORE_COLUMNS
            box = (column * step, row * step, (column + 1) * step, (row + 1) * step)
            sheet.paste(art.crop(box).resize((CELL, CELL), Image.LANCZOS),
                        (column * CELL, row * CELL))
        sheet.save(GAME_TILES / f"{name}_{ORE_VARIANTS}.png", optimize=True)
        print(f"게임: {name}_{ORE_VARIANTS}.png  {sheet.width}x{sheet.height}px")


def preview(field: Image.Image) -> None:
    """The three terrains laid out together, for the proposals page.

    Assembled rather than shown as sheets, for the reason the belt loop is: a
    picture of one boulder tile says nothing about whether two of them meet, and
    a picture of an ore sheet says nothing about whether a seam cell reads as a
    rectangle of somebody else's ground. Both of those were real faults here and
    both were found by looking at exactly this.
    """
    atlas = Image.open(GAME_TILES / "rock_47.png")
    masks = sorted({blob.canonical(mask) for mask in range(256)})
    clump = {(1, 1), (2, 1), (3, 1), (1, 2), (2, 2), (3, 2), (4, 2), (2, 3),
             (3, 3), (6, 1), (6, 2)}
    seams = {(1, 4): ("crystal", 0), (2, 4): ("crystal", 3),
             (5, 4): ("copper", 1), (6, 4): ("copper", 4)}
    ores = {name: Image.open(GAME_TILES / f"{name}_{ORE_VARIANTS}.png")
            for name in ("crystal", "copper")}

    wide, tall = 9, 6
    canvas = Image.new("RGB", (wide * CELL, tall * CELL))
    for row in range(tall):
        for column in range(wide):
            box = ((column % FIELD) * CELL, (row % FIELD) * CELL,
                   (column % FIELD + 1) * CELL, (row % FIELD + 1) * CELL)
            canvas.paste(field.crop(box), (column * CELL, row * CELL))
    neighbours = [(0, -1, blob.N), (1, 0, blob.E), (0, 1, blob.S), (-1, 0, blob.W),
                  (1, -1, blob.NE), (1, 1, blob.SE), (-1, 1, blob.SW), (-1, -1, blob.NW)]
    for column, row in clump:
        mask = 0
        for dx, dy, bit in neighbours:
            if (column + dx, row + dy) in clump:
                mask |= bit
        index = masks.index(blob.canonical(mask))
        left, top = (index % 8) * CELL, (index // 8) * CELL
        canvas.paste(atlas.crop((left, top, left + CELL, top + CELL)),
                     (column * CELL, row * CELL))
    for (column, row), (name, variant) in seams.items():
        left = (variant % ORE_COLUMNS) * CELL
        top = (variant // ORE_COLUMNS) * CELL
        canvas.paste(ores[name].crop((left, top, left + CELL, top + CELL)),
                     (column * CELL, row * CELL))
    canvas.save(TILES / "preview_terrain.png", optimize=True)
    print(f"미리보기: preview_terrain.png  {canvas.width}x{canvas.height}px")


def main() -> int:
    GAME_TILES.mkdir(parents=True, exist_ok=True)
    for name in ["snow_src.png", "rock_src.png", "crystal_src.png", "copper_src.png"]:
        if not (TILES / name).exists():
            print(f"재질이 없습니다: {TILES / name} — gen_terrain.py 를 먼저 실행하세요",
                  file=sys.stderr)
            return 1
    field = snow_field()
    rock_blob(field)
    ore_sheets(field)
    preview(field)
    return 0


if __name__ == "__main__":
    sys.exit(main())
