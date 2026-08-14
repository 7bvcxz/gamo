#!/usr/bin/env python3
"""The opening cutscene, seven panels, generated.

    python3 tools/sprite/gen_cutscene.py --dry-run
    python3 tools/sprite/gen_cutscene.py            # only the missing ones
    python3 tools/sprite/gen_cutscene.py --only 03 --force

Writes tools/sprite/cutscene/NN-name.png. The prompts live here rather than in a
notes file because a picture in this repository that cannot be regenerated is a
picture that can only ever be replaced -- the same reason the sounds moved into
build_sfx.py and the font into build_font.cjs.

## Twelve beats, seven pictures

The story was written as twelve. Twelve panels of a game that has not started
yet is not an opening, it is a wait, so beats that share a place and a moment
were merged: running for the rocket happens inside the bombardment, the launch
and the climb are one shot, and the break-up, the ejection and the falling
debris are one picture rather than three.

What could not be merged is what changes the player's situation: the fleet
arriving, the city falling, leaving Earth, Earth ending, waking to the alarm,
the crash, and the snow. Seven.

## The style clause is shared and has to be true of every panel

Whatever every prompt carries is a claim about all seven. This repository has
already had a shared fragment that said "walking on the spot" quietly overturn
a prompt that asked for standing still, so STYLE holds only what is true of a
wide painted shot, and nothing about what is in it.

Grim is described the same way every time. She is drawn small in most panels
and a description that drifts panel to panel is a different girl each time.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "cutscene"

## True of all seven and about nothing but the medium.
STYLE = (
    "soft watercolour and coloured-pencil storybook illustration with visible "
    "pencil outlines, muted desaturated palette, warm light against cold blue "
    "shadow, cinematic wide shot, painterly grain"
)
## The same girl in every panel, drawn small.
GRIM = (
    "a small chibi girl with a silver-white bob and sleepy half-lidded eyes, "
    "wearing a rust-red duffel coat with cream fur trim, brown mittens and "
    "brown fur-lined boots"
)
## The enemy, described once. Penguin-shaped hulls rather than "penguin ships",
## because the second reads as an animal and draws one.
FLEET = (
    "a fleet of dark angular airships with black and white penguin-shaped hulls "
    "and small orange beaks"
)

PANELS = [
    ("01-fleet-arrives",
     f"{GRIM} stands alone in the street of a small evening town and looks up. "
     f"High above the rooftops {FLEET} fills the whole sky in ordered rows, "
     f"laying a long shadow across the town. Warm lit windows below, cold sky "
     f"above. {STYLE}"),
    ("02-city-falls",
     f"The same small town at night, its buildings collapsing into orange fire "
     f"and black smoke as streaks of light fall from {FLEET} overhead. {GRIM} "
     f"runs across the foreground from left to right, small against the flames, "
     f"her coat lit orange on one side. {STYLE}"),
    ("03-launch",
     f"A slender white rocket climbing steeply through smoke on a column of "
     f"orange flame, the burning town small and far below it, {FLEET} as dark "
     f"silhouettes among the clouds around it. {STYLE}"),
    ("04-earth-ends",
     f"Seen from inside a rocket through a round cockpit window: the blue Earth "
     f"in black space, ringed all around by hundreds of tiny dark penguin-shaped "
     f"airships, and a white flash blooming out of its surface. In the dark "
     f"foreground {GRIM} is a small silhouette gripping the seat, thrown "
     f"sideways by the light. {STYLE}"),
    ("05-alarm",
     f"Inside a cramped rocket cockpit lit only by a red alarm lamp, {GRIM} "
     f"pushes herself up off the floor with one mitten on the seat. Through the "
     f"round window behind her: a white ice planet, and on its horizon two tall "
     f"pointed ice peaks side by side shaped like a cat's ears. {STYLE}"),
    ("06-crash",
     f"A white rocket breaking apart as it falls through pale ice clouds, with "
     f"{GRIM} flung clear of it as a tiny figure, and a long trail of glowing "
     f"debris scattering behind. The white surface of the ice planet far below. "
     f"{STYLE}"),
    ("07-snow",
     f"{GRIM} lies on her side in deep snow under a pale empty sky, her breath "
     f"showing in the cold. A collapsed white parachute is spread across the "
     f"snow beside her, and a scuffed metal case sits half-buried within reach "
     f"of her hand. Snow drifts across the ground. {STYLE}"),
]

## 3:2 is the widest the model offers; the game crops it to 16:9.
SIZE = "1536x1024"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only", default="", help="panel number, e.g. 03")
    parser.add_argument("--quality", default="low")
    parser.add_argument("--force", action="store_true",
                        help="regenerate panels that already exist")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    for name, prompt in PANELS:
        if args.only and not name.startswith(args.only):
            continue
        target = OUT / f"{name}.png"
        if target.exists() and not args.force and not args.dry_run:
            print(f"있음, 건너뜀: {target.name}")
            continue
        command = ["imagegen", prompt, "--out", str(target),
                   "--size", SIZE, "--quality", args.quality]
        if args.force:
            command.append("--force")
        if args.dry_run:
            command.append("--dry-run")
        print(f"── {name}")
        result = subprocess.run(command)
        if result.returncode != 0:
            print(f"실패: {name}", file=sys.stderr)
            return result.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
