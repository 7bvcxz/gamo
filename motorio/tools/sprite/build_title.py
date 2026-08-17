#!/usr/bin/env python3
"""Crops the adopted title painting to 16:9 and stores it as assets/title.webp.

    python3 motorio/tools/sprite/build_title.py
    python3 motorio/tools/sprite/build_title.py --check

Which candidate ships is ADOPTED below, so regenerating can never silently
change the first picture anyone sees.

## Why 1280x720 and not larger

The same measurement the cutscene panels were sized by: the game's viewport is
960x540 and the title is drawn to cover it, so anything past 1280 is detail no
screen in this game resolves. It is one file rather than seven, so a little more
would be affordable -- it just would not be visible.

## Why WEBP and why the compress mode matters

Godot imports a lossless WEBP by re-encoding it, and the pack grew six times
over the last time that was left at the default. `title.webp.import` carries
`compress/mode=1` for the same reason `assets/cutscene/*.import` do.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "title"
OUT = HERE.parent.parent / "assets" / "title.webp"

## gen3 rather than gen4: both are the right style and gen4 puts pine trees and a
## conveyor line through the middle of the frame, which is where MOTORIO and the
## menu are drawn. The title has to be a painting that survives text on it.
ADOPTED = "title_gen3.png"

WIDTH = 1280
HEIGHT = 720
QUALITY = 92


def fit(image: Image.Image) -> Image.Image:
    scaled = image.convert("RGB").resize(
        (WIDTH, round(image.height * WIDTH / image.width)), Image.LANCZOS)
    top = max(0, (scaled.height - HEIGHT) // 2)
    return scaled.crop((0, top, WIDTH, top + HEIGHT))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    source = SOURCE / ADOPTED
    if not source.exists():
        print(f"채택본이 없습니다: {source}", file=sys.stderr)
        return 1
    if args.check:
        size = OUT.stat().st_size if OUT.exists() else 0
        print(f"{OUT.name}  {size/1024:6.0f} KB  <- {ADOPTED}")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fit(Image.open(source)).save(OUT, "WEBP", quality=QUALITY, method=6)
    print(f"{OUT.name}  {OUT.stat().st_size/1024:6.0f} KB  <- {ADOPTED}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
