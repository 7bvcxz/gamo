#!/usr/bin/env python3
"""Object art, generated to match the characters, keyed, and left as candidates.

    python3 motorio/tools/sprite/gen_objects.py --dry-run
    python3 motorio/tools/sprite/gen_objects.py core shelter
    python3 motorio/tools/sprite/gen_objects.py --all

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

Measure before believing a number here, and measure at the zoom people play at
rather than the one the game opens on. The zoom keys are not only for looking
around: players sit zoomed in, and `game_scale` runs 0.6 to 1.6 in steps of
0.05 from a desktop default of 0.90. So the miner is 43 screen pixels only at
the default on a 1280 window; at 1.20 on a 1920 window it is 86, and at the
ceiling 115.

Small either way. The miner being replaced had roughly twenty distinct
mechanical parts and none of those sizes can hold twenty of anything. Every
prompt here names a few large shapes and one warm light, because silhouette is
what makes an object readable and detail is not.

Generated at 1024 regardless, and stored by build_objects.py at twice the drawn
size. That is what makes zooming in safe: at the ceiling the stored art is
upscaled 1.6x by a NEAREST filter, which stays soft because these are painted
gradients rather than authored pixels.
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
    "shapes, so it stays readable when shown at 40 pixels across. Flat even "
    "lighting. Flat solid pure green background, one uniform colour."
)

## The camera is per subject rather than shared. Everything that stands on the
## plateau is drawn straight on with a slight tilt, which is how the shelter and
## the characters are drawn; the belt is drawn from directly overhead, because
## its cross-section is measured off the picture and a tilt makes that
## measurement a lie. A shared fragment has to be true of every subject -- this
## repository has already watched one that was not ("walking on the spot",
## applied to the prompt that said do not walk) flip a whole clip.
STANDING = ("The subject is centred and fills the frame, seen straight on with a "
            "slight downward tilt as in a top-down game. ")
OVERHEAD = ("Seen from directly overhead, looking straight down, with no tilt "
            "and no perspective. ")

## One entry per object the game draws from a PNG. The wording of each is the
## part worth arguing about; the style above is settled.
##
## Written as what is there, never as what is absent: naming a thing to forbid
## it puts it in the picture. An earlier cat clip was told there was no bowl and
## came back holding one.
## Which camera each subject is drawn with, defaulting to STANDING.
CAMERA = {"belt": OVERHEAD}

SUBJECTS = {
    # Only the surface and its rails. The belt's cross-section is sampled off
    # this picture and swept along a path to build the straight, corner and
    # splitter tiles, so anything that varies along the direction of travel --
    # slats, cleats, chevrons -- would smear into stripes. Movement is drawn by
    # the game, over the top, where it can also scroll.
    "belt": (
        "A short section of conveyor belt for a snowy top-down game, running "
        "straight from the top edge of the picture to the bottom edge and "
        "reaching both edges: one smooth continuous rubber belt surface down the "
        "middle in dark warm grey, and a chunky metal side rail running the full "
        "length along each side in muted blue-grey with warm brass bolts. The "
        "belt is uniform along its whole length, identical at the top and at the "
        "bottom."
    ),
    # The crate she wakes up next to, and the two things that come out of it.
    #
    # Three pictures rather than one because the case in the snow is closed and
    # what she carries is not: the whole opening is "there is a box, and what was
    # in it becomes the fire and the hut", and one grey rectangle for all three
    # states says none of that. Drawn as a case rather than a crate so it reads
    # as equipment that came off a ship, not as cargo someone stacked.
    "kit": (
        "A small closed emergency survival case half-buried in snow, for a snowy "
        "top-down game: a chunky rounded metal case with a thick lid, one broad "
        "band across the lid, two warm brass catches on the front, a carrying "
        "handle on top, a little snow settled on the lid."
    ),
    "kit_base": (
        "A small open emergency case for a snowy top-down game, seen with its lid "
        "raised: inside it a round amber ember glowing warmly, packed in a "
        "cream-coloured lining, the case itself chunky rounded muted blue-grey "
        "metal with warm brass catches."
    ),
    "kit_shelter": (
        "A small open emergency case for a snowy top-down game, seen with its lid "
        "raised: inside it a tight bundle of warm brown timber and folded cream "
        "canvas, the case itself chunky rounded muted blue-grey metal with warm "
        "brass catches."
    ),
    "generator": (
        "A cosy little power generator for a snowy top-down game: a chunky "
        "rounded metal drum lying on a low frame, one round port in front glowing "
        "cool blue-white, a short exhaust stack on top, warm brass bolts, a "
        "little snow on its top surfaces."
    ),
    # Both of these were drawn across two and a half tiles and are one tile now.
    # Nothing in the simulation changed -- the core has always been one machine on
    # one cell and the hut one cell beside it -- so the buildings were pictures
    # three times the size of the thing they stood for, swallowing the tiles their
    # neighbours were built on.
    #
    # At one tile the old prompts are impossible: three pipes around a rim and a
    # door and a window and log courses is twenty features in 32 pixels. These
    # name one silhouette and one light each, which is all that survives.
    # gen2 was a stone ring with a fire in it, which reads as a campfire -- a
    # thing you sit at, not a thing you bring ore to. The base is where heat is
    # thrown from *and* where things are made, so the silhouette has to be built
    # rather than gathered: a machine with a fire in it.
    "core": (
        "A cosy little furnace station for a snowy top-down game, seen from "
        "almost directly overhead: a chunky square metal housing with rounded "
        "corners, a big round door in the middle glowing warm amber, a short "
        "brass chimney at the back corner, and one small metal hopper mouth on "
        "each of its four sides. Snow settled on its top edges."
    ),
    "shelter": (
        "A tiny cosy hut for a snowy top-down game, seen from almost directly "
        "overhead: one steep square roof of warm brown timber under thick snow, "
        "a small stone chimney at one corner, and one small amber-lit window on "
        "the near slope. Nothing else."
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
    # Five pieces of the ship she came down in, scattered from eleven tiles out.
    #
    # Five prompts rather than five samples of one, because what makes a field of
    # wreckage read as wreckage is that no two pieces are the same shape. Five
    # rolls of "a piece of debris" come back as five of the same lump.
    #
    # Each names one silhouette and one warm or cold light, like every other
    # object here: these are drawn at roughly one tile, and a tangle of struts is
    # a grey smudge at that size. They share a palette -- scorched cream-white
    # hull plating, muted blue-grey metal, one amber or cyan light -- so that a
    # player who finds a second one recognises it as the same ship.
    "debris1": (
        "A broken nose cone from a small crashed spacecraft, lying half-buried in "
        "snow for a snowy top-down game: one smooth cream-white cone tipped on "
        "its side with a torn ragged base, scorch marks along one flank, a band "
        "of muted blue-grey metal round it."
    ),
    "debris2": (
        "A ruptured fuel tank from a small crashed spacecraft, lying in snow for "
        "a snowy top-down game: one fat rounded cream-white cylinder on its side, "
        "a jagged split down the middle showing muted blue-grey metal inside, two "
        "brass bands round it, a little snow settled along the top."
    ),
    "debris3": (
        "A broken rocket engine nozzle from a small crashed spacecraft, lying in "
        "snow for a snowy top-down game: one wide flared bell of muted blue-grey "
        "metal opening toward the viewer, warm brass rings round its throat, the "
        "inside of the bell glowing faint amber, soot along its rim."
    ),
    "debris4": (
        "A torn hull panel from a small crashed spacecraft, lying flat in snow "
        "for a snowy top-down game: one buckled rectangular plate of cream-white "
        "plating with rounded corners and a ragged torn edge, one round porthole "
        "in it glowing cool cyan, warm brass rivets along its edges."
    ),
    "debris5": (
        "A bent antenna dish from a small crashed spacecraft, lying in snow for a "
        "snowy top-down game: one shallow cream-white dish crumpled on one side, "
        "a short muted blue-grey mast leaning out of it with a small amber lamp "
        "at the tip, snow gathered in the bowl."
    ),
    # The pickaxe lying in the snow, which is the second thing the game ever
    # gives her. It was drawn in code -- a grey wedge on a brown stick -- next to
    # a case and a hut that are painted, so the one tool in the opening looked
    # like a placeholder beside them.
    #
    # Lying down rather than standing: it is on the ground, and the drop it
    # replaces was drawn flat. One head, one shaft, one warm binding.
    "pickaxe": (
        "A sturdy pickaxe lying flat on snow for a snowy top-down game, seen "
        "from above: one chunky muted blue-grey steel head with two curved "
        "points, a thick warm brown wooden shaft running out of it, a band of "
        "warm brass leather binding where the two meet, a little snow gathered "
        "along one side."
    ),
    # The gun, which was the one thing in her hands drawn as something else
    # entirely: the slot and the drop both showed a picture of a miner, so the
    # tool and the machine it puts down were the same object twice.
    #
    # Lying down like the pickaxe, because these two are drawn by the same code
    # in the same two places -- the snow it falls on and the slot it sits in --
    # and one standing beside one lying flat reads as two kinds of thing.
    #
    # A gun, but a builder's: short and blunt rather than long and aimed, with
    # the amber of the fire in it, so what it fires reads as the machine rather
    # than as a shot.
    "build_gun": (
        "A chunky builder's tool gun lying flat on snow for a snowy top-down "
        "game, seen from above: one short wide muted blue-grey metal barrel with "
        "a broad warm brass ring around its mouth, a thick rounded warm brown "
        "grip below it, one small cream-white canister along its top, one round "
        "amber lamp glowing on its side, a little snow gathered along one edge."
    ),
    # 냥마을 and the sign that points at it. Five subjects that have to read as
    # one place: a village is not four unrelated buildings, so they share a
    # palette -- warm orange-brown timber, cream plaster, grey-blue stone -- and
    # each names one silhouette and one warm light like everything else here.
    #
    # No lettering anywhere. What the sign says is drawn by the game in its own
    # font when she reads it; asked for as part of the picture it comes back as
    # convincing gibberish, and gibberish on a signpost is worse than a blank
    # board because a player will squint at it.
    "signpost": (
        "A wooden signpost standing in deep snow for a snowy top-down game: one "
        "thick warm brown timber post with a single blank horizontal plank board "
        "fixed near the top, one small carved cat paw print in the middle of the "
        "board, a little snow settled along the top edge of the board and at the "
        "foot of the post."
    ),
    "village_house": (
        "A tiny cosy cat cottage for a snowy top-down game, seen from almost "
        "directly overhead: one steep round thatched roof in warm orange-brown "
        "under thick snow, a small grey-blue stone chimney at one side, one small "
        "round window on the near slope glowing warm amber, a low cream plaster "
        "wall showing below the roof."
    ),
    "village_well": (
        "A small stone well for a snowy top-down game, seen from almost directly "
        "overhead: a round ring of chunky grey-blue stones with snow on top, a "
        "dark round opening in the middle, a warm brown timber frame with a small "
        "peaked roof over it, a coiled rope on the rim."
    ),
    "village_fire": (
        "A cosy village fire pit for a snowy top-down game, seen from almost "
        "directly overhead: a round ring of chunky grey-blue stones, warm amber "
        "flames rising from a few split logs in the middle, glowing embers "
        "underneath, snow settled on the outer stones."
    ),
    "village_gate": (
        "A simple wooden village gate for a snowy top-down game: two thick warm "
        "brown timber posts standing in snow with one crossbeam over them, a "
        "round wooden plaque shaped like a cat's head hanging from the middle of "
        "the beam, snow along the top of the beam."
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
    prompt = f"{SUBJECTS[name]} {CAMERA.get(name, STANDING)}{STYLE}"
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
    # low, not medium. Measured 2026-08-13: medium bills 1,756 output tokens an
    # image and low bills 196 -- nine times -- and at the sizes this game draws
    # at, 43 to 115 pixels, the difference is not visible. The five objects that
    # shipped first were generated at medium before anyone checked, which is
    # where most of the first dollar went.
    parser.add_argument("--quality", default="low",
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
