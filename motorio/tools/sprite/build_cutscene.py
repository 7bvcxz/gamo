#!/usr/bin/env python3
"""The generated cutscene panels, cut down to something a phone will download.

    python3 tools/sprite/build_cutscene.py
    python3 tools/sprite/build_cutscene.py --check   # measure, write nothing

Reads tools/sprite/cutscene/*.png (see gen_cutscene.py) and writes
assets/cutscene/NN.webp at 16:9.

## Why WebP, and why these numbers

The generated panels are 1536x1024 PNGs of about 3 MB each. Twenty-one
megabytes of opening for a game whose entire pack is 1.2 MB is not an opening,
it is a reason to close the tab -- this repository already spent 16 MB of an 18
MB pack on font glyphs it never drew, and the symptom was minutes of blank
screen on a phone.

**These files are the master.** The 1536 PNGs are intermediates and are not
committed; what regenerates a panel is the prompt in gen_cutscene.py and the
sidecar beside its output. Ten megabytes of PNG in the repository buys nothing
the player ever sees.

1280x720 rather than 960x540: measured across all seven the two cost the same
(596 KB against 565 KB), and more pixels wins for painterly art that gets
upscaled into a 1920 window.

Quality 90 here, not 72. The pack does its own lossy pass -- assets/cutscene's
.import files are compress/mode=1 -- and that is the compression the player
sees. Committing an already-crushed file would put two of them in series for no
saving, because the pack re-encodes either way.

## The pack, not the repository, is what has to stay small

Left at the default lossless import, seven of these turned a 1.23 MB pack into
7.33 MB: Godot stored them decoded. compress/mode=1 puts them back to roughly
what they weigh here. Check the pack size after adding a panel, not the file.

## 3:2 to 16:9 is a crop, not a squeeze

The model offers 1536x1024 and the game is 16:9. Scaled to width and cropped
about the centre, which is where every one of these was composed.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "cutscene"
OUT = HERE.parent.parent / "assets" / "cutscene"

WIDTH = 1280
HEIGHT = 720
QUALITY = 90


def fit(image: Image.Image) -> Image.Image:
    scaled = image.convert("RGB").resize(
        (WIDTH, round(image.height * WIDTH / image.width)), Image.LANCZOS)
    top = max(0, (scaled.height - HEIGHT) // 2)
    return scaled.crop((0, top, WIDTH, top + HEIGHT))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    panels = sorted(SOURCE.glob("*.png"))
    if not panels:
        print(f"원본이 없습니다: {SOURCE}", file=sys.stderr)
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for index, path in enumerate(panels, start=1):
        target = OUT / f"{index:02d}.webp"
        if args.check:
            size = target.stat().st_size if target.exists() else 0
            print(f"{target.name}  {size/1024:6.0f} KB  <- {path.name}")
            total += size
            continue
        fit(Image.open(path)).save(target, "WEBP", quality=QUALITY, method=6)
        size = target.stat().st_size
        total += size
        print(f"{target.name}  {size/1024:6.0f} KB  <- {path.name}")
    # Anything left from a run that had more panels than this one. A cutscene
    # that lost a panel must not keep showing it.
    if not args.check:
        for stale in sorted(OUT.glob("*.webp")):
            if int(stale.stem) > len(panels):
                stale.unlink()
                print(f"정리: {stale.name}")
    print(f"합계 {total/1024:.0f} KB · {len(panels)}장 · {WIDTH}x{HEIGHT} q{QUALITY}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
