#!/usr/bin/env python3
"""Terrain materials: one picture per material, for build_terrain.py to cut up.

    python3 motorio-oneshot/tools/sprite/gen_terrain.py --all --dry-run
    python3 motorio-oneshot/tools/sprite/gen_terrain.py snow rock

Writes tiles/<name>_src.png. Separate from gen_objects.py because these are not
objects: nothing is keyed out of them, there is no subject and no ground line,
and the whole frame is the material. Asking for them through the object prompt
would mean asking for a chroma background and then cutting the material away.

## What is being asked for, and what is built afterwards

A material, not a tile. Every seam in this game is settled by build_terrain.py,
which measures these and constructs the tiles -- the same division of labour the
belt uses, for the same reason: a generator can be asked for the look of snow and
cannot be asked for a picture whose left edge equals its right edge.

So each prompt asks for an evenly covered field with nothing in it that would
draw the eye to one spot. A boulder in the middle of the snow becomes a boulder
in the middle of every cell of snow in the world.
"""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLATE = HERE / "refs" / "style_plate.png"
TILES = HERE / "tiles"

## Shared, and true of every one of these: a flat overhead field. No chroma
## background, because the frame is the material and there is nothing to key.
STYLE = (
    "Seen from directly overhead, looking straight down, with no tilt, no "
    "perspective and no horizon. It fills the entire frame edge to edge as an "
    "even field with no single focal point and nothing placed in the middle. "
    "Cute cozy chibi game art style, matching the reference image: the same soft "
    "shading and the same warm palette sensibility. Flat even lighting across the "
    "whole picture, no vignette, no shadow of anything outside the frame."
)

MATERIALS = {
    # Very low contrast on purpose. This is drawn under everything else in the
    # game and multiplied over a warm pool of light; snow with strong shapes in
    # it fights the pool and turns the floor into the loudest thing on screen.
    "snow": (
        "Clean fresh snow, a soft powdery surface with very gentle undulations "
        "and faint wind ripples, almost uniform pale cool white with only the "
        "softest hints of shadow."
    ),
    # The material a boulder field is made of. Cut into corner pieces afterwards,
    # so what matters is that the stone is the same everywhere in the picture --
    # a piece taken from the top has to belong beside a piece taken from the left.
    "rock": (
        "A dense field of rounded grey granite boulders packed together, warm "
        "grey stone with soft rounded tops and a little snow caught between them, "
        "the boulders the same size and the same colour all across the picture."
    ),
    "crystal": (
        "Pale cyan crystal shards growing out of snowy ground, clusters of "
        "translucent blue-white crystals of the same size scattered evenly across "
        "the whole picture."
    ),
    # On snow, not in stone. Asking for copper "in snowy grey stone" produced a
    # field of stone, and since a seam cell fills its cell, every copper cell in
    # the world was a grey rectangle lying on a white floor. What the ground
    # under a seam should be is the ground.
    "copper": (
        "Warm orange copper nuggets and short metallic veins lying on clean pale "
        "snow, all the same size and scattered evenly across the whole picture, "
        "with plenty of plain pale snow between them."
    ),
}


def generate(name: str, quality: str, dry_run: bool) -> None:
    TILES.mkdir(parents=True, exist_ok=True)
    target = TILES / f"{name}_src.png"
    command = [
        "imagegen", f"{MATERIALS[name]} {STYLE}", "--out", str(target),
        "--ref", str(PLATE), "--quality", quality, "--force",
    ]
    if dry_run:
        command.append("--dry-run")
    print(f"== {name}")
    if subprocess.run(command).returncode != 0:
        raise SystemExit(f"{name} 생성 실패")


def main() -> None:
    parser = argparse.ArgumentParser(description="지형 재질 생성")
    parser.add_argument("names", nargs="*", choices=list(MATERIALS) + [])
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--quality", default="low",
                        choices=["low", "medium", "high"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    names = list(MATERIALS) if args.all else args.names
    if not names:
        parser.error("재질 이름 또는 --all 이 필요합니다")
    for name in names:
        generate(name, args.quality, args.dry_run)


if __name__ == "__main__":
    main()
