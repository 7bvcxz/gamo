#!/usr/bin/env python3
"""The inside of the hut, generated to match Grim and the cat.

    python3 motorio/tools/sprite/gen_room.py --dry-run
    python3 motorio/tools/sprite/gen_room.py --all --quality low

Writes candidates into room/ as `<name>_gen<N>.png`; adopting one is an edit to
ADOPTED in build_room.py, so regenerating can never silently change what ships.

## Why this is a second script and not more entries in gen_objects.py

Two different products come out of here. The furniture is a keyed cutout, the
same as a miner or a case: green behind it, chroma keyed, drawn into a rect.
The floor and the wall are *surfaces* -- they fill their frame edge to edge and
are tiled, so keying them would eat the picture. Same style, same reference,
different post-processing, and a single table with a "is this one keyed" column
is how the wrong half gets applied to the wrong file.

## Why every prompt passes the style plate

`refs/style_plate.png` is Grim and the cat on pure green. The whole ask here is
that the room looks like it belongs to them, and this repository has measured
that adjectives get most of the way and the reference gets the rest: line
weight, palette and the flat cel shading come across in a way words do not. It
also fixes the background, which is what makes the keyed half possible.

For the two surfaces the plate is a risk in exactly that way -- it is a green
background, and a texture with green in it is a texture with a hole in it. So
those prompts say the wood reaches every edge, and `--check` prints the corner
pixels of what came back. Verifying is a second; regenerating is money.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_objects import ALPHA_FLOOR, key_green  # noqa: E402

HERE = Path(__file__).resolve().parent
PLATE = HERE / "refs" / "style_plate.png"
ROOM = HERE / "room"

## True of all seven, which is the only thing a shared fragment may be. The
## palette is named rather than implied because the room has to sit beside a
## character who is already drawn: her coat is that rust orange, her trim is
## that cream, and the hut outside is that warm brown under snow.
STYLE = (
    "Cute cozy chibi game art style, matching the reference image exactly: the "
    "same thick warm dark-brown outline, the same flat cel shading with gentle "
    "soft gradients, the same warm palette of rust orange, cream, soft warm "
    "brown and muted blue-grey. Soft rounded chunky forms, very few large simple "
    "shapes, readable when shown small. Flat even lighting, no photographic "
    "detail, no text."
)

## The furniture is seen the way the room is: from the front and slightly above,
## as if standing in the doorway. Said once, because a piece drawn from another
## angle is a piece that cannot stand next to the others.
PIECE_VIEW = (
    "A single object alone in the frame, seen from the front and slightly above "
    "as if by someone standing in the doorway of a small room. The object is "
    "centred and fills the frame. Flat solid pure green background, one uniform "
    "colour, nothing else in the picture. "
)

## A surface fills its frame. No subject, no background, no edges -- and said in
## those words, because the reference it is being given has a green background
## and a texture with green in it is a texture with a hole in it.
TILE_VIEW = (
    "A flat repeating surface texture that fills the entire frame edge to edge "
    "with no border, no background, no object and no empty space. Seen straight "
    "on. The pattern continues past all four edges so that copies laid side by "
    "side line up. "
)

## name -> (keyed?, prompt). The keyed half becomes a cutout; the other half is
## a texture the room tiles.
SUBJECTS: dict[str, tuple[bool, str]] = {
    # --- Surfaces -------------------------------------------------------------
    "floor": (False,
        "Warm brown wooden floorboards for a cosy cabin: long planks running "
        "left to right, a few visible grain lines and two or three darker knots, "
        "thin dark seams between the boards, gently varied plank tones."),
    "wall": (False,
        "The inside wall of a cosy log cabin: horizontal timber boards in a "
        "warmer, lighter brown than a floor, soft grain, thin dark shadow lines "
        "between the boards."),
    # --- Furniture ------------------------------------------------------------
    # Twice as wide as tall, twice as tall as wide, and square: each is drawn to
    # the shape of the cells it stands on, so the room can place it without
    # stretching it. Naming the proportion in the prompt is what makes the crop
    # come out at that proportion.
    "fireplace": (True,
        "A cosy stone fireplace, as wide as it is tall: a chunky rounded stone "
        "surround in warm grey, a dark arched opening in the middle with a small "
        "orange fire burning low inside it, two split logs stacked beside the "
        "hearth, a thick wooden mantel across the top."),
    "bed": (True,
        "A small single bed for one person, twice as tall as it is wide, seen "
        "with the pillow at the top end: a chunky warm brown wooden frame, a "
        "cream mattress, a folded dusty-purple blanket over the lower half and a "
        "plump cream pillow at the head."),
    # gen1 came back with the cat sitting in it. Nothing in the prompt asked for
    # that -- the style plate did, and an empty pane is an invitation. So the
    # glass is given something to hold: a night sky with the snow outside, which
    # is also the thing the window is in the room to say.
    "window": (True,
        "A cosy cabin window, twice as wide as it is tall: a chunky warm brown "
        "wooden frame with one crossbar down the middle, a narrow wooden sill "
        "along the bottom, a short cream curtain gathered at each side, and "
        "beyond the glass a deep blue night sky over a snowy hill, filling the "
        "whole of both panes."),
    "sofa": (True,
        "A small cosy two-seat sofa, twice as wide as it is tall, seen from the "
        "front: rounded rust-orange cushions, a low back with two cushions, "
        "chunky cream piping along the edges and short warm brown wooden feet."),
    # The same window with the morning behind it. Two pictures rather than one
    # window with a transparent pane and the sky drawn behind it: the pane would
    # have to come back keyed green, and a model that has just been handed a
    # green reference will fill an empty rectangle with the character standing in
    # it -- which is exactly what the first two attempts here did.
    "window_day": (True,
        "A cosy cabin window, twice as wide as it is tall: a chunky warm brown "
        "wooden frame with one crossbar down the middle, a narrow wooden sill "
        "along the bottom, a short cream curtain gathered at each side, and "
        "beyond the glass a pale morning sky over a snowy hill with a low sun, "
        "filling the whole of both panes."),
    # gen1 asked for this one from above while PIECE_VIEW asks for every piece
    # from the front -- two instructions about the camera in one prompt, which
    # is the shared-fragment trap this repository has already paid for once. It
    # is a doorway seen the way the rest of the room is, and it came back with a
    # travelling bag on the step that nobody asked for: the frame was mostly
    # empty, so the model filled it.
    # Three attempts asked for an open doorway and three came back with Grim
    # standing in it -- once with a travelling bag instead. The reference is a
    # character on a plain background, and a door-shaped hole in a picture is a
    # character-shaped hole: filling it with darkness and then with a snowy night
    # did not help, because she was drawn in *front* of both.
    #
    # So the door is shut. There is no opening to stand in, the room reads it as
    # the way out just as well, and pressing Z is what opens it.
    "door": (True,
        "A closed cabin door in its frame, twice as wide as it is tall, seen "
        "straight on: chunky vertical planks in warm brown wood, two dark iron "
        "bands across them, a round iron handle, and a heavier frame around the "
        "whole door. The door fills the frame completely."),
}


def next_slot(name: str) -> Path:
    index = 1
    while (ROOM / f"{name}_gen{index}.png").exists():
        index += 1
    return ROOM / f"{name}_gen{index}.png"


def corners(image: Image.Image) -> list[tuple[int, int, int]]:
    rgb = image.convert("RGB")
    w, h = rgb.size
    return [rgb.getpixel(p) for p in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3))]


def generate(name: str, quality: str, dry_run: bool) -> None:
    keyed, subject = SUBJECTS[name]
    prompt = f"{subject} {PIECE_VIEW if keyed else TILE_VIEW}{STYLE}"
    target = next_slot(name)
    raw = target.with_name(target.stem + "_raw.png")
    command = ["imagegen", prompt, "--out", str(raw), "--ref", str(PLATE),
               "--quality", quality]
    if dry_run:
        command.append("--dry-run")
    print(f"== {name} -> {target.name}  ({'keyed' if keyed else 'tiled'})")
    if subprocess.run(command).returncode != 0:
        raise SystemExit(f"{name} 생성 실패")
    if dry_run:
        return

    source = Image.open(raw)
    print(f"   모서리 {corners(source)}")
    if keyed:
        out = key_green(source)
        alpha = out.getchannel("A")
        clear = sum(1 for v in alpha.getdata() if v <= ALPHA_FLOOR)
        print(f"   키잉 완료 · 배경 {100 * clear / (out.width * out.height):.0f}%")
    else:
        # A surface keeps every pixel. If the corners came back green the
        # reference bled through and the file is not usable -- which is what the
        # line above is printed for.
        out = source.convert("RGBA")
    out.save(target)
    sidecar = raw.with_suffix(raw.suffix + ".json")
    if sidecar.exists():
        sidecar.replace(target.with_suffix(target.suffix + ".json"))
    raw.unlink()
    print(f"   저장 {target}")


def main() -> int:
    parser = argparse.ArgumentParser(description="숙소 내부 아트 생성 (후보만)")
    parser.add_argument("names", nargs="*", choices=list(SUBJECTS) + [])
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--quality", default="low", choices=["low", "medium", "high"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    names = list(SUBJECTS) if args.all else args.names
    if not names:
        parser.error("이름 또는 --all 이 필요합니다")
    if not PLATE.exists():
        raise SystemExit(f"스타일 판이 없습니다: {PLATE}")
    ROOM.mkdir(parents=True, exist_ok=True)
    for name in names:
        generate(name, args.quality, args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
