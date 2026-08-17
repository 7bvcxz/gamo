#!/usr/bin/env python3
"""The title screen, generated to match the characters rather than the cutscene.

    python3 motorio/tools/sprite/gen_title.py --dry-run
    python3 motorio/tools/sprite/gen_title.py --quality high

Writes `title/title_genN.png`; `build_title.py` crops one to 16:9 and stores it
as `assets/title.webp`.

## Why this is not gen_cutscene with another prompt

The opening panels are watercolour storybook illustration -- soft pencil
outlines, muted palette, painterly grain -- because they are a story being told
about something that already happened. The title is the game itself: the first
picture of Grim anyone sees, and the one they will compare the sprite against a
minute later. It is drawn in the sprite style, and the style plate is passed for
the same reason `gen_objects.py` passes it -- line weight and palette come
across from a reference in a way adjectives do not.

## Why the middle of the frame is deliberately quiet

The game draws over this: MOTORIO at 0.30 of the height, two lines of subtitle
under it, and the menu centred at 0.64. All of that is text on a painting, and
text on a busy painting is text nobody reads. So the composition puts its
subjects low and to the sides and leaves the upper middle as sky -- which is
also where a title belongs.

## Why the cats are named as a number

"cats" came back as a pile of them. The picture has one girl and three animals
in it and the count is the composition, so it is stated.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLATE = HERE / "refs" / "style_plate.png"
OUT = HERE / "title"

## True of the whole picture, and nothing about what is in it -- this repository
## has watched a shared fragment ("walking on the spot") quietly overturn the
## prompt it was attached to.
STYLE = (
    "Cute cozy chibi game art style, matching the reference image exactly: the "
    "same thick warm dark-brown outlines, the same flat cel shading with gentle "
    "soft gradients, the same warm palette of orange, cream, soft brown and "
    "muted blue-grey metal against cold blue-white snow. Soft rounded chunky "
    "forms. Clean and readable, not sketchy."
)

## The same girl the sprite is. Described in full because this is the picture
## everyone sees first, and a title Grim who is not the sprite Grim is a promise
## the game breaks in its first minute.
GRIM = (
    "a small chibi girl with a silver-white bob covering one eye, sleepy "
    "half-lidded eyes, wearing a rust-red duffel coat with cream fur trim, "
    "brown mittens and brown fur-lined boots"
)

## And the animals, which are the other half of what this game is about.
CATS = (
    "three small round cream-and-orange tabby cats with tiny red caps"
)

SCENE = (
    f"Wide cinematic title illustration for a cosy snow factory game. {GRIM} "
    f"stands on a snowfield in the lower right, seen from a low three-quarter "
    f"angle, holding a pickaxe over one shoulder and looking out across the "
    f"valley. {CATS} sit and stand around her boots. On the lower left, far "
    f"behind her, a small chunky metal furnace glows warm amber on the snow "
    f"with a thin plume of smoke. The upper half of the picture is a wide "
    f"empty twilight sky over a pale blue-white horizon, deep blue at the top "
    f"and warm near the ground, with soft falling snow. The middle of the frame "
    f"is open sky and empty snow. {STYLE}"
)

## 3:2 is the widest the model offers; build_title.py crops it to 16:9.
SIZE = "1536x1024"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--quality", default="low")
    parser.add_argument("--count", type=int, default=1)
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    existing = sorted(OUT.glob("title_gen*.png"))
    start = len(existing) + 1
    for offset in range(args.count):
        target = OUT / f"title_gen{start + offset}.png"
        command = ["imagegen", SCENE, "--out", str(target),
                   "--ref", str(PLATE), "--size", SIZE, "--quality", args.quality]
        if args.dry_run:
            command.append("--dry-run")
        print(f"── {target.name}")
        result = subprocess.run(command)
        if result.returncode != 0:
            return result.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
