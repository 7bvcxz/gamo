#!/usr/bin/env python3
"""Grim is 15% smaller in the north-facing mining sheet. This puts her back.

    python3 motorio/tools/sprite/fix_mine_north.py --check
    python3 motorio/tools/sprite/fix_mine_north.py

## Why the pipeline did not catch it

`spec.json` already carries the fix for the *other* half of this problem. The
normaliser used to size each clip by its own silhouette, and a raised pickaxe is
held in the hands -- so it counted as part of the body and the three mining
clips, measured at 530, 434 and 558, were each scaled to the same cell height.
Grim grew when she mined away from the camera and shrank when she mined to the
side. `subjects.grim.source_body` fixed that by measuring her once, from clips
where her hands are empty, and scaling every mining clip by that instead.

What it cannot fix is the generator drawing her at a different size to begin
with. That is the trade-off written down beside it: measuring each clip absorbs
the generator's drift, and forcing a shared number preserves it. The north clip
came back with a smaller Grim in it, and a faithful normalisation kept her
small.

## What is measured

The resting frames -- the ones where the pickaxe is down -- of the side and
north sheets are the same pose seen from two angles, so their silhouettes are
comparable. Side reads 64 pixels and north reads 54: 15% short, which is what a
player sees as "she gets smaller when she turns her back".

Every cell is scaled about the feet anchor, because the feet are what the game
draws on the ground line. The tool has room: the cell is 128 with the feet at
104, a body of 64 becomes 76 and a raised pickaxe reaches 84, still twenty
pixels clear of the top.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[3]
SHEET = REPO / "motorio" / "assets" / "characters" / "grim_mine_n.png"
REFERENCE = REPO / "motorio" / "assets" / "characters" / "grim_mine_w.png"
## Where the feet sit in a cell, from spec.json's character128 anchor.
FEET_Y = 104
ALPHA = 16
## The frames where the pickaxe is down, in both sheets. The swing frames are not
## comparable between two angles -- the tool is in a different place -- and the
## rest frames are the same standing pose.
REST = [0, 1, 6, 7]


def cells(image: Image.Image) -> list[Image.Image]:
    size = image.size[1]
    return [image.crop((i * size, 0, (i + 1) * size, size))
            for i in range(image.size[0] // size)]


def height(cell: Image.Image) -> int:
    mask = cell.getchannel("A").point(lambda v: 255 if v > ALPHA else 0)
    box = mask.getbbox()
    return 0 if box is None else box[3] - box[1]


def rest_height(path: Path) -> float:
    frames = cells(Image.open(path).convert("RGBA"))
    picked = [height(frames[i]) for i in REST if i < len(frames)]
    return sum(picked) / max(1, len(picked))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="측정만 하고 파일은 건드리지 않는다")
    args = parser.parse_args()

    want = rest_height(REFERENCE)
    have = rest_height(SHEET)
    ratio = want / max(have, 1.0)
    print("옆모습 서 있는 프레임 %.1fpx · 뒷모습 %.1fpx · 배율 %.3f" % (want, have, ratio))
    if args.check:
        return 0
    if abs(ratio - 1.0) < 0.03:
        print("이미 맞습니다 — 건드리지 않습니다")
        return 0

    image = Image.open(SHEET).convert("RGBA")
    size = image.size[1]
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    for index, cell in enumerate(cells(image)):
        grown = cell.resize((round(size * ratio), round(size * ratio)), Image.NEAREST)
        # About the feet: the same point on the ground before and after, so the
        # sheet does not need re-anchoring and she does not sink into the snow.
        dx = round((size - grown.size[0]) / 2)
        dy = round(FEET_Y - FEET_Y * ratio)
        out.alpha_composite(grown, (index * size + dx, dy))
    out.save(SHEET)
    print("다시 씀: %s" % SHEET.relative_to(REPO))
    after = rest_height(SHEET)
    print("이제 뒷모습 %.1fpx (목표 %.1f)" % (after, want))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
