#!/usr/bin/env python3
"""Belt tiles, built from one generated picture so the seams cannot disagree.

    python3 motorio/tools/sprite/build_belt.py

Writes assets/objects/belt_straight.png, belt_corner.png and splitter.png.

## The idea

A conveyor has to read as one continuous one-way path however it is laid out,
and that is a seam problem, not a drawing problem. This repository already
learned the shape of the answer on the rock tileset: pieces meet correctly
because every piece was drawn to the same edge, rather than because separate
drawings happened to agree.

A belt's edge is its cross-section -- rail, surface, rail, measured across the
direction of travel. So exactly one thing is measured off the generated art:

    profile[i] for i in 0..SIZE-1

and every tile here is that profile swept along a path. A straight tile sweeps
it down a line, a corner along an elbow, a splitter along a T. Wherever a path
reaches a tile edge it arrives perpendicular, so the edge *is* the profile, and
any two tiles that meet there match exactly. Not approximately -- they are the
same numbers.

That is also why the generated belt was asked for as a smooth uniform surface
with nothing crossing it. Anything that varies along the direction of travel --
slats, cleats, chevrons -- has no single cross-section, and sweeping it would
smear it into stripes. Movement is drawn by the game over the top, where it can
also scroll, which a texture cannot.

## The sizes

Stored at three times the drawn 32, not the two that the painted objects use.
Players play zoomed in and `game_scale` reaches 1.6, which on a 1920 window
draws a tile at 102 pixels; two times would be upscaling by then. The painted
objects survive that because they are soft gradients, and these are not -- a
rail is a hard edge, and a hard edge upscaled by a NEAREST filter is where the
unevenness shows.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "objects" / "belt_gen1.png"
GAME_ART = HERE.parent.parent / "assets" / "objects"

## Drawn at one tile; stored at three times that. See the docstring.
TILE = 32
SIZE = TILE * 3

## How much of the cell the belt itself covers. Not all of it: at full width the
## rails land on the cell boundary, so two belts running side by side merge into
## one slab and a run reads as a painted area rather than as a path. The gap is
## what makes it a line on the snow.
WIDTH = int(SIZE * 0.82)

ALPHA_FLOOR = 16

## Bolts, put back after the median took them out.
##
## They had to come out of the cross-section -- a bolt is a feature of one place
## along the rail, and swept it would become a stripe running the length of every
## belt in the game. But they are also most of what said "machine" rather than
## "ribbon", and without them a run of belts reads as a brown road.
##
## So they go back on by arc length along the path, at a period that divides the
## tile. Both the straight tile and the corner are 96 long from edge to edge, so
## the count comes out whole and a bolt never lands half on one tile and half on
## the next -- the spacing carries across a seam the same way the profile does.
BOLT_PERIOD = SIZE // 3
BOLT_RADIUS = 3.0


def luminance(colour) -> float:
    return 0.299 * colour[0] + 0.587 * colour[1] + 0.114 * colour[2]


def rail_centres(profile: list) -> list[float]:
    """Where the two rails sit across the belt, as offsets from the middle.

    Found by brightness rather than by a hand-written fraction: the rails are the
    pale metal, the surface between them is dark rubber, and a number written
    here would stop being true the moment the belt is generated again.
    """
    bright = [i for i, c in enumerate(profile) if c[3] > ALPHA_FLOOR
              and luminance(c) > 115.0]
    if not bright:
        raise SystemExit("레일을 찾지 못했습니다")
    middle = (WIDTH - 1) / 2.0
    low = [i for i in bright if i < middle]
    high = [i for i in bright if i >= middle]
    if not low or not high:
        raise SystemExit("레일이 한쪽에만 있습니다")
    return [sum(low) / len(low) - middle, sum(high) / len(high) - middle]


def bolt_colour(image: Image.Image) -> tuple[int, int, int, int]:
    """The warmest pixel on the rail, which is a bolt.

    Warmest rather than brightest: the rail has specular highlights that are
    paler than the brass, and picking the palest pixel returns one of those and
    puts white dots down the belt.
    """
    rgba = image.convert("RGBA")
    left, right = content_columns(rgba)
    edge = (right - left) // 6
    best = None
    for x in list(range(left, left + edge)) + list(range(right - edge, right)):
        for y in range(rgba.height // 4, rgba.height * 3 // 4):
            r, g, b, a = rgba.getpixel((x, y))
            if a <= ALPHA_FLOOR:
                continue
            warmth = r - b
            if best is None or warmth > best[0]:
                best = (warmth, (r, g, b, 255))
    return best[1]


def content_columns(image: Image.Image) -> tuple[int, int]:
    mask = image.getchannel("A").point(lambda v: 255 if v > ALPHA_FLOOR else 0)
    box = mask.getbbox()
    if box is None:
        raise SystemExit("빈 이미지입니다")
    return box[0], box[2]


def cross_section(image: Image.Image) -> list[tuple[int, int, int, int]]:
    """The belt's appearance across its width, as SIZE pixels.

    Taken as a median down the middle half of the picture rather than from one
    row. A single row can land on a bolt, and a bolt is a feature of one place
    on the rail rather than of the rail -- swept, it would become a stripe
    running the length of every belt in the game. The ends are avoided because
    the generator rounds a subject off as it approaches the frame edge even when
    asked not to.
    """
    rgba = image.convert("RGBA")
    left, right = content_columns(rgba)
    height = rgba.height
    band = range(height // 4, height * 3 // 4)
    pixels = rgba.load()

    wide: list[tuple[int, int, int, int]] = []
    for x in range(left, right):
        channels = []
        for index in range(4):
            values = sorted(pixels[x, y][index] for y in band)
            channels.append(values[len(values) // 2])
        wide.append(tuple(channels))

    # To tile width. A belt occupies its whole cell, so the measured strip is
    # stretched across the tile rather than placed inside it.
    out = []
    for i in range(WIDTH):
        source = i * len(wide) / WIDTH
        low = int(source)
        high = min(low + 1, len(wide) - 1)
        t = source - low
        out.append(tuple(round(wide[low][c] * (1 - t) + wide[high][c] * t)
                         for c in range(4)))
    return out


def sweep(profile: list, segments: list) -> Image.Image:
    """The profile swept along a polyline, as one tile.

    Every pixel takes the profile entry at its distance from the path, so the
    rails follow the path around and the surface stays the same width. Where the
    path meets a tile edge it meets it square, which is what makes the edge equal
    the profile and therefore what makes two tiles match.
    """
    half = (WIDTH - 1) / 2.0
    rails = rail_centres(profile)
    bolt = bolt_colour(Image.open(SOURCE))
    tile = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pixels = tile.load()
    for y in range(SIZE):
        for x in range(SIZE):
            px, py = x + 0.5, y + 0.5
            best_distance = None
            best_signed = 0.0
            best_arc = 0.0
            for (ax, ay), (bx, by), arc0 in segments:
                dx, dy = bx - ax, by - ay
                length = dx * dx + dy * dy
                t = 0.0 if length == 0 else ((px - ax) * dx + (py - ay) * dy) / length
                t = max(0.0, min(1.0, t))
                cx, cy = ax + dx * t, ay + dy * t
                distance = ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5
                if best_distance is not None and distance >= best_distance:
                    continue
                # Which side of the path, from the cross product with the
                # segment's own direction. Taken per arm rather than globally, so
                # each arm of a junction carries the profile the right way round
                # for the way that arm travels.
                cross = dx * (py - ay) - dy * (px - ax)
                best_distance = distance
                best_signed = distance if cross >= 0.0 else -distance
                best_arc = arc0 + t * (length ** 0.5)
            if best_distance is None or best_distance > half + 0.5:
                continue
            index = int(round(half + best_signed))
            pixels[x, y] = profile[max(0, min(WIDTH - 1, index))]

            # A bolt is round, so it is placed by distance from its centre rather
            # than by a band in each axis -- a square bolt at this size reads as
            # a chip out of the rail.
            along = best_arc % BOLT_PERIOD
            along = min(along, BOLT_PERIOD - along)
            for rail in rails:
                across = best_signed - rail
                if along * along + across * across <= BOLT_RADIUS * BOLT_RADIUS:
                    pixels[x, y] = bolt
    return tile


def main() -> int:
    if not SOURCE.exists():
        print(f"원본이 없습니다: {SOURCE}", file=sys.stderr)
        return 1
    profile = cross_section(Image.open(SOURCE))
    mid, end = SIZE / 2.0, float(SIZE)

    # Canonical orientation is travel to the east, which is the direction the
    # game rotates from. Straight runs the whole way across; the corner enters
    # from the west and leaves to the south; the splitter takes from the west
    # and gives to both sides.
    # Each arm carries the arc length at which it starts, so bolt spacing is
    # measured from where an item enters the tile rather than from the start of
    # whichever segment happens to be listed first. A junction's two output arms
    # both begin at the middle, so both are given the same starting arc.
    pieces = {
        "belt_straight": [((0.0, mid), (end, mid), 0.0)],
        "belt_corner": [((0.0, mid), (mid, mid), 0.0),
                        ((mid, mid), (mid, end), mid)],
        "splitter": [((0.0, mid), (mid, mid), 0.0),
                     ((mid, mid), (mid, 0.0), mid),
                     ((mid, mid), (mid, end), mid)],
    }
    GAME_ART.mkdir(parents=True, exist_ok=True)
    for name, segments in pieces.items():
        art = sweep(profile, segments)
        art.save(GAME_ART / f"{name}.png")
        print(f"게임: {name}.png  {SIZE}px (그릴 크기 {TILE})")

    return check_seams()


def check_seams() -> int:
    """The seam, measured on tiles placed the way the game places them.

    The first version of this compared the corner's open edges against the
    straight tile's, read in the same direction, and reported a mismatch of 255.
    Nothing was wrong with the tiles: an edge that runs north-south on one tile
    runs east-west on its neighbour, so the two are read in opposite order and
    comparing them directly compares the profile with itself reversed. The check
    was wrong, and a check that is wrong about a thing that is right is worse
    than no check -- it argues for changing something correct.

    So this places tiles instead of reasoning about them: a belt running east,
    turning south, continuing south, and the two touching edges compared as
    pixels. Whatever the convention is, the pixels either meet or they do not.
    """
    straight = Image.open(GAME_ART / "belt_straight.png").convert("RGBA")
    corner = Image.open(GAME_ART / "belt_corner.png").convert("RGBA")
    # Canonical art travels east; the game rotates it clockwise for south.
    south = straight.transpose(Image.ROTATE_270)

    seams = [
        ("직선(동) → 코너",
         [straight.getpixel((SIZE - 1, y)) for y in range(SIZE)],
         [corner.getpixel((0, y)) for y in range(SIZE)]),
        ("코너 → 직선(남)",
         [corner.getpixel((x, SIZE - 1)) for x in range(SIZE)],
         [south.getpixel((x, 0)) for x in range(SIZE)]),
        ("직선(동) 자기 자신",
         [straight.getpixel((SIZE - 1, y)) for y in range(SIZE)],
         [straight.getpixel((0, y)) for y in range(SIZE)]),
    ]
    failures = 0
    for label, left, right in seams:
        worst = max(max(abs(a - b) for a, b in zip(p, q))
                    for p, q in zip(left, right))
        print(f"   이음매 {label}: 최대 차이 {worst}")
        failures += worst > 0
    if failures:
        print("   이음매가 어긋납니다", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
