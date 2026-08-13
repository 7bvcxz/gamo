#!/usr/bin/env python3
"""Object art, generated to match the characters, keyed, and left as candidates.

    python3 motorio-oneshot/tools/sprite/gen_objects.py --dry-run
    python3 motorio-oneshot/tools/sprite/gen_objects.py core shelter
    python3 motorio-oneshot/tools/sprite/gen_objects.py --all

Writes RGBA cutouts into objects/ as `<name>_gen<N>.png`, which is what
build_objects.py already reads. This script only produces candidates; adopting
one is still an edit to ADOPTED in that file, so a regeneration can never
silently change what ships.

## Why the prompts live here

They are the asset. The PNG is a render of them, and a PNG with no prompt beside
it can only be replaced by guessing and paying again. Kept next to the pipeline
that consumes them, versioned, so a change to the house style is a diff.

## Why every prompt passes the style plate

The objects that shipped before this were cool-toned semi-realistic steampunk
and the characters are warm chibi; they read as two different games standing in
one field. Describing the style in words got most of the way there, and passing
`refs/style_plate.png` -- Grim and the cat, on green -- got the rest: line
weight and palette come across in a way adjectives do not.

It also fixes the background for free. The same prompt without the plate came
back on murky (3, 150, 11) green, which no key can lift cleanly; with it, the
plate's own (0, 255, 0) came through at (2, 250, 3). The reference decides the
background -- a lesson this pipeline already had, working in its favour for once.

## Why the shapes are so simple

The game draws these at 43 screen pixels on a 1280-wide desktop and 23 on a
phone. The miner being replaced had roughly twenty distinct mechanical parts,
and at 23 pixels it was grey mud. Every prompt here names a small number of
large shapes and one warm light, because that is all that survives the trip
down. Detail is not the thing that makes an object readable; silhouette is.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sprite_tool import despeckle  # noqa: E402

HERE = Path(__file__).resolve().parent
PLATE = HERE / "refs" / "style_plate.png"
OBJECTS = HERE / "objects"

## Held for every object. Adjectives that were measured against the characters
## rather than guessed: the outlines really are warm dark brown rather than
## black, and the shading really is flat with a soft gradient rather than
## painted. Anything here is true of all five subjects -- a fragment that is only
## true of some is how a shared prompt ends up contradicting an individual one.
STYLE = (
    "Cute cozy chibi game art style, matching the reference image exactly: the "
    "same thick warm dark-brown outline, the same flat cel shading with gentle "
    "soft gradients, the same warm palette of orange, cream, soft brown and "
    "muted blue-grey metal. Soft rounded chunky forms. Very few large simple "
    "shapes, so it stays readable when shown at 40 pixels across. The subject is "
    "centred and fills the frame, seen straight on with a slight downward tilt "
    "as in a top-down game. Flat even lighting. Flat solid pure green "
    "background, one uniform colour."
)

## One entry per object the game draws from a PNG. The wording of each is the
## part worth arguing about; the style above is settled.
##
## Written as what is there, never as what is absent: naming a thing to forbid
## it puts it in the picture. An earlier cat clip was told there was no bowl and
## came back holding one.
SUBJECTS = {
    "core": (
        "A cosy round heat core for a snowy top-down game: a warm glowing "
        "furnace at the centre of a circular stone-and-metal base, a big amber "
        "fire glowing through a round window, three chunky pipes around the rim, "
        "soft snow settled on the outer ring."
    ),
    "shelter": (
        "A tiny cosy log cabin for a snowy top-down game, seen from the front "
        "with its roof visible: thick snow piled on a steep wooden roof, warm "
        "amber light in one round window, a small round door, chunky log walls."
    ),
    "food_bin": (
        "A cosy wooden feeding trough for cats in a snowy top-down game: a "
        "chunky wooden box with rounded corners and metal bands, filled to the "
        "brim with round cream-coloured kibble, a little snow on the rim."
    ),
    # Left-right symmetric on purpose. Which way a miner sends its output is
    # said by an arrow drawn over it, and the art is never rotated to agree, so
    # a machine whose drill leans one way is a second answer to that question.
    "miner": (
        "A small mining machine for a snowy top-down game, perfectly symmetric "
        "left to right: a round drill head at the centre pointing straight down "
        "into the ground, one thick chunky pipe on each side, a glowing warm "
        "amber lamp on each side, a dusting of snow on its top surfaces."
    ),
    # The cat holds this in front of itself and it bobs straight up and down.
    # Nothing rotates it, so the drill has to point down in the picture; the
    # first version came back as a drill gun aimed sideways, which reads as a
    # cat holding a gun.
    "cat_tool": (
        "A small handheld drill tool standing upright with its drill bit "
        "pointing straight down at the bottom of the picture: a stubby grey "
        "cone-shaped drill bit below, a chunky rounded orange body above it, one "
        "small warm amber lamp, a short grip on top. A single simple object "
        "alone in the frame."
    ),
}

## Below this, a pixel is background rather than art.
ALPHA_FLOOR = 16


def key_green(image: Image.Image) -> Image.Image:
    """Chroma key, with the spill taken off the edge pixels.

    Greenness is `G - max(R, B)` rather than distance to a colour, because the
    generated background is near but not exactly (0, 255, 0) and the subject's
    own greens -- there are none here, but there will be one day -- are never
    that far from their own red and blue.

    The soft ramp matters more than the threshold. A hard cut leaves a one-pixel
    green rind that survives every downscale and shows up as a lime halo on
    snow, which is the colour it is least able to hide against.
    """
    rgba = image.convert("RGBA")
    pixels = list(rgba.getdata())
    out = []
    for r, g, b, a in pixels:
        greenness = g - max(r, b)
        if greenness >= 90:
            out.append((r, g, b, 0))
            continue
        if greenness <= 30:
            out.append((r, g, b, a))
            continue
        # Between the two: fade out, and pull the green back down to what the
        # rest of the pixel can justify so the survivor is not tinted.
        alpha = int(a * (1.0 - (greenness - 30) / 60.0))
        out.append((r, min(g, max(r, b) + 12), b, alpha))
    rgba.putdata(out)
    return despeckle(rgba, ALPHA_FLOOR)


def next_slot(name: str) -> Path:
    """A new numbered file rather than an overwrite, so a regeneration that comes
    back worse has not destroyed the one that was good."""
    index = 1
    while (OBJECTS / f"{name}_gen{index}.png").exists():
        index += 1
    return OBJECTS / f"{name}_gen{index}.png"


def generate(name: str, quality: str, dry_run: bool) -> None:
    prompt = f"{SUBJECTS[name]} {STYLE}"
    target = next_slot(name)
    raw = target.with_name(target.stem + "_raw.png")
    command = [
        "imagegen", prompt, "--out", str(raw), "--ref", str(PLATE),
        "--quality", quality,
    ]
    if dry_run:
        command.append("--dry-run")
    print(f"== {name} -> {target.name}")
    if subprocess.run(command).returncode != 0:
        raise SystemExit(f"{name} 생성 실패")
    if dry_run:
        return

    keyed = key_green(Image.open(raw))
    keyed.save(target)
    # The sidecar imagegen wrote belongs to the picture that is kept.
    sidecar = raw.with_suffix(raw.suffix + ".json")
    if sidecar.exists():
        sidecar.replace(target.with_suffix(target.suffix + ".json"))
    raw.unlink()

    alpha = keyed.getchannel("A")
    clear = sum(1 for v in alpha.getdata() if v <= ALPHA_FLOOR)
    total = keyed.width * keyed.height
    print(f"   키잉 완료 · 배경 {100 * clear / total:.0f}% · {target}")


def main() -> None:
    parser = argparse.ArgumentParser(description="오브젝트 아트 생성 (후보만)")
    parser.add_argument("names", nargs="*", choices=list(SUBJECTS) + [],
                        help="생성할 오브젝트. 비우고 --all 을 쓰면 전부")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--quality", default="medium",
                        choices=["low", "medium", "high"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    names = list(SUBJECTS) if args.all else args.names
    if not names:
        parser.error("오브젝트 이름 또는 --all 이 필요합니다")
    if not PLATE.exists():
        raise SystemExit(f"스타일 판이 없습니다: {PLATE}")
    for name in names:
        generate(name, args.quality, args.dry_run)


if __name__ == "__main__":
    main()
