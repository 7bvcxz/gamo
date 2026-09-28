#!/usr/bin/env python3
"""Building art for World Visual Pass 01: generated, then keyed by key_buildings.gd.

    python3 motorio/tools/art/gen_buildings.py --dry-run
    python3 motorio/tools/art/gen_buildings.py base shelter miner
    python3 motorio/tools/art/gen_buildings.py --all

Writes raw candidates to tools/art/raw/<name>.png (with imagegen's sidecar
.json beside each). Adopting one is running key_buildings.gd, which keys the
green out, fits the picture to its footprint and writes assets/objects/.

## Why this is not gen_objects.py

That script is the house pipeline and its prompts are still the style this game
settled on in August. It needs Pillow, which this machine no longer has, and the
keying half of it is rewritten in Godot's Image API (key_buildings.gd) rather
than installed. The prompts here follow its rules: what is there, never what is
absent; a few large shapes and one warm light; the style plate passed so line
weight, palette and the pure green background come across.

## What changed in the direction

The brief (World Visual Pass 01) and the Visual North Star
(design/reference/motorio-visual-north-star.png): cold metal bodies, warm
orange-yellow functional light, cozy, never cyberpunk or sci-fi or realistic.
So the metal is a darker, colder blue-grey than the August set, and every
building gets exactly one or two warm lights that say what it does -- the
furnace mouth, the cabin window, the drill lamp, the firebox. The North Star is
passed as the second reference for that.

And every building is drawn to its footprint, seen from the same slight
top-down tilt as the characters, filling a square: the game draws each one
exactly over the cells it blocks, and a picture that is not square is a
picture that is either smaller than its building or hangs over the next one.
"""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
PLATE = HERE.parent / "sprite" / "refs" / "style_plate.png"
NORTH_STAR = HERE.parents[1] / "design" / "reference" / "motorio-visual-north-star.png"

STYLE = (
    "Cute cozy chibi game art style matching the first reference image exactly: the "
    "same thick warm dark-brown outline, the same flat cel shading with gentle soft "
    "gradients. The building's body is cold dark blue-grey metal like the machines "
    "in the second reference image, with a little white snow settled on its top "
    "edges, and its one or two lights glow warm orange-yellow. Soft rounded chunky "
    "forms, very few large simple shapes so it stays readable at 40 pixels across. "
    "The subject is centred, seen straight on with a slight downward tilt as in a "
    "top-down game, and its body fills a square frame edge to edge. Flat solid pure "
    "green background, one uniform colour."
)

SUBJECTS = {
    # The base. Eight cells across, the thing the whole game is read around: the
    # fire has to be the brightest thing in it.
    "base": (
        "A small sturdy survival base built around a heat furnace, for a snowy "
        "top-down game: a square squat dark metal building with rounded corners and "
        "a flat roof, a big round furnace hatch in the middle of the front glowing "
        "warm orange, a short thick chimney pipe on the back left corner, and two "
        "small warm lamps on the front corners."
    ),
    # The hut. Four cells by four now, a quarter of what it was: a cabin, not a
    # barn. The window is the one warm thing, and it has glass with sky in it --
    # an empty frame is a request for a cat to sit in it.
    "shelter": (
        "A tiny cozy winter cabin for a snowy top-down game: a small square hut of "
        "dark metal panels and warm brown timber with a thick snow-covered roof, one "
        "small square window glowing warm yellow, a short metal stove pipe on the "
        "roof, and a small closed wooden door at the front with one step."
    ),
    # The mining post. Two cells by two, exactly its node. The cat works it
    # standing on the front half, so the rig is at the back of the picture and
    # the front is a flat deck -- the machine stays readable with a worker on it.
    "miner": (
        "A small mining drill post for a snowy top-down game: a square dark metal "
        "platform, a compact drill rig standing at the back of it with a short "
        "vertical drill shaft going down into the ground, one warm orange lamp on "
        "top of the rig, and a flat metal deck across the front half of the platform."
    ),
    "miner_mk2": (
        "A small upgraded mining drill post for a snowy top-down game: a square dark "
        "metal platform, a taller heavier drill rig standing at the back of it with "
        "two short vertical drill shafts going down into the ground and brass bands "
        "round them, two warm orange lamps on top of the rig, and a flat metal deck "
        "across the front half of the platform."
    ),
    "generator": (
        "A small power generator for a snowy top-down game: a squat rounded dark "
        "metal boiler drum on a square base, a small firebox window at the front "
        "glowing warm orange, a short copper coil on top with a soft yellow glow, "
        "and a short exhaust pipe."
    ),
    "manufacturer": (
        "A small workshop press machine for a snowy top-down game: a square squat "
        "dark metal machine with a heavy press head on top, a wide input slot on one "
        "side and an output tray on the other, and one warm orange indicator lamp."
    ),
    "assembler": (
        "A small assembly machine for a snowy top-down game: a square squat dark "
        "metal machine with two short robotic arms folded over a small work table "
        "in the middle, two input hoppers at the back, and one warm yellow lamp."
    ),
    "food_bin": (
        "A small cat food feeding station for a snowy top-down game: a square "
        "wooden crate with dark metal corner bands, its lid open, full of little "
        "orange fish, with a small warm lantern hanging on one side."
    ),
}


def generate(name: str, quality: str, dry_run: bool) -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    out = RAW / f"{name}.png"
    command = ["imagegen", f"{SUBJECTS[name]} {STYLE}", "--out", str(out),
               "--ref", str(PLATE), "--ref", str(NORTH_STAR), "--quality", quality,
               "--size", "1024x1024", "--force"]
    if dry_run:
        command.append("--dry-run")
    print(f"== {name} -> {out}")
    if subprocess.run(command).returncode != 0:
        raise SystemExit(f"{name} 생성 실패")


def main() -> None:
    parser = argparse.ArgumentParser(description="건물 아트 생성 (World Visual Pass 01)")
    parser.add_argument("names", nargs="*", choices=list(SUBJECTS) + [])
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--quality", default="low", choices=["low", "medium", "high"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    names = list(SUBJECTS) if args.all else args.names
    for name in names:
        generate(name, args.quality, args.dry_run)


if __name__ == "__main__":
    main()
