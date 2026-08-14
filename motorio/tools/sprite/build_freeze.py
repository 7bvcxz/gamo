#!/usr/bin/env python3
"""Four stages of a frozen cat melting, cut from one generated clip.

    NODE_PATH=<playwright> SPRITE_CHROME=<chromium with H.264> \
      node tools/sprite/extract_frames.cjs melt.mp4 frames --fps 12
    python3 tools/sprite/build_freeze.py frames

Writes assets/characters/cat_freeze_4.png -- one row of four cells, most frozen
first -- and a contact sheet beside the frames for looking at.

## Stages are chosen by ice, not by time

The clip melts fast at the start and slowly at the end, so four frames taken at
equal times are not four equal steps of melting: the first two would look almost
identical and the last two would be a cat with a puddle. Each frame is measured
for how much ice it still carries, and the four are spread evenly along *that*.

The last stage is deliberately still icy. What follows it in the game is not a
fifth picture but the ordinary cat sprite, so a stage that had already finished
melting would be a duplicate of something the game already draws.

## The cat is held still; the ice is what moves

The generator was asked for an animal that does not move, and it very nearly
obliged -- the pose is identical throughout. But the block shrinks, and as it
shrinks the cat settles: its cap travels 115 pixels down the frame, 18 percent
of the height. Used as they are, the four stages would show the cat sliding
downward while the ice receded.

So the frames are aligned on the cat rather than on the frame, using the cap --
the one part visible through the ice at every stage -- and everything is placed
where the cat sits in the final, thawed frame. The ice then recedes *around* a
cat that stays put, which is both what the fiction says happens and what makes
the last stage line up with the live cat sprite that replaces it.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sprite_tool import despeckle  # noqa: E402

HERE = Path(__file__).resolve().parent
GAME_ART = HERE.parent.parent / "assets" / "characters"

## The character cell every sheet in this game uses.
CELL = 128
STAGES = 4
## Chroma: anything this much greener than its own red and blue is background.
CHROMA_MARGIN = 90
## How icy the last stage still is. Above zero on purpose -- see the docstring.
LAST_ICE = 0.10


def keyed(path: Path) -> Image.Image:
    """The frame with the chroma removed, and the green pulled off the edges."""
    image = path.open("rb")
    art = Image.open(image).convert("RGB")
    out = Image.new("RGBA", art.size)
    source = list(art.getdata())
    result = []
    for r, g, b in source:
        greenness = g - max(r, b)
        if greenness >= CHROMA_MARGIN:
            result.append((r, g, b, 0))
        elif greenness <= 30:
            result.append((r, g, b, 255))
        else:
            alpha = int(255 * (1.0 - (greenness - 30) / (CHROMA_MARGIN - 30)))
            result.append((r, min(g, max(r, b) + 12), b, alpha))
    out.putdata(result)
    return _despill(out)


def _despill(art: Image.Image) -> Image.Image:
    """Green pulled out of everything that stayed.

    The ice is translucent, so the chroma behind it shows *through* it: the first
    cut had a green block sitting inside stages two and three, which would have
    been a green block sitting on the snow. Keying cannot fix that -- those
    pixels really are part of the ice and removing them punches holes in it.

    Clamping green to what the pixel's own red and blue can justify turns the
    tint back into the blue-white it should have been. The cat survives it
    untouched: its colours are warm, so its green is already below its red.
    """
    out = []
    for r, g, b, a in art.getdata():
        if not a:
            out.append((r, g, b, a))
            continue
        # Green held to the average of the other two, not to the larger of them.
        # The first attempt clamped to max(r, b) + 8, which let (130, 175, 167)
        # through untouched -- green above blue, and a fifth of the ice in stages
        # two and three still reading as green. Averaging is what actually
        # removes a colour cast, and it leaves the cat alone: warm fur already
        # has green below the mean of its red and blue.
        limit = (r + b) // 2 + 6
        out.append((r, min(g, limit), b, a))
    art.putdata(out)
    return art


def measure(art: Image.Image) -> tuple[float, tuple[float, float]]:
    """How much ice is left, and where the cap is.

    Ice is counted as pale blue: the palette has no other blue in it, and the
    cat's own colours are warm. The cap is the warm red, which is the only thing
    in frame that is visible at every stage -- the body is behind opaque ice at
    the start and the outline is not, so tracking the outline finds nothing in
    the first frames and returns a centroid of zero. That silently reported the
    cat as moving 362 pixels, which is how the alignment came to be checked
    properly in the first place.
    """
    pixels = list(art.getdata())
    solid = ice = 0
    cap = 0
    cap_x = cap_y = 0
    width = art.width
    for index, (r, g, b, a) in enumerate(pixels):
        if a < 32:
            continue
        solid += 1
        if b >= r and b > 150:
            ice += 1
        if r > 150 and r - g > 45 and r - b > 45:
            cap += 1
            cap_x += index % width
            cap_y += index // width
    if cap == 0:
        raise SystemExit("모자를 찾지 못했습니다 — 정렬 기준이 없습니다")
    return ice / max(solid, 1), (cap_x / cap, cap_y / cap)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    frames = sorted(Path(sys.argv[1]).glob("*.png"))
    if not frames:
        print("프레임이 없습니다", file=sys.stderr)
        return 1

    art = [keyed(path) for path in frames]
    measured = [measure(image) for image in art]
    ice = [m[0] for m in measured]
    caps = [m[1] for m in measured]

    # Where the cat ends up, which is where every stage is moved to.
    anchor = caps[-1]
    print("모자 이동: %.0f px (정렬 기준 %.0f, %.0f)"
          % (max(c[1] for c in caps) - min(c[1] for c in caps), anchor[0], anchor[1]))

    # Four steps evenly spread along how much ice is left, from the most frozen
    # frame down to LAST_ICE.
    top = max(ice)
    wanted = [top - (top - LAST_ICE) * index / (STAGES - 1) for index in range(STAGES)]
    chosen: list[int] = []
    for target in wanted:
        best = min(range(len(ice)), key=lambda i: abs(ice[i] - target))
        chosen.append(best)
    print("고른 프레임:", [(i, round(ice[i], 2)) for i in chosen])
    if len(set(chosen)) != STAGES:
        print("경고: 같은 프레임이 두 번 뽑혔습니다 — 클립의 변화가 부족합니다",
              file=sys.stderr)

    # What the cat has to end up as. The last stage is followed by the ordinary
    # cat sprite, so if the two are different sizes the animal jumps at the exact
    # moment the rescue pays off. Measured from the live sheet rather than
    # written down, so it survives that sheet being re-cut.
    live = Image.open(GAME_ART / "cat_idle_s.png").convert("RGBA").crop((0, 0, CELL, CELL))
    live_box = live.getchannel("A").point(lambda v: 255 if v > 16 else 0).getbbox()
    live_height = live_box[3] - live_box[1]
    live_foot = ((live_box[0] + live_box[2]) / 2.0, float(live_box[3]))

    # The cat in the last frame, with the puddle it is standing in removed --
    # droplets are separate specks and would otherwise be measured as part of the
    # animal, which makes it look taller and everything come out too small.
    thawed = despeckle(art[-1], 32)
    box = thawed.getchannel("A").point(lambda v: 255 if v > 16 else 0).getbbox()
    scale = live_height / float(box[3] - box[1])
    foot = ((box[0] + box[2]) / 2.0, float(box[3]))
    print("크기 맞춤: 프레임의 고양이 %dpx -> 셀의 %dpx (%.3f배)"
          % (box[3] - box[1], live_height, scale))

    sheet = Image.new("RGBA", (CELL * STAGES, CELL), (0, 0, 0, 0))
    for slot, index in enumerate(chosen):
        source = art[index]
        # Two moves, in order: the cap onto the anchor, so every stage shares the
        # last frame's geometry, and then that geometry onto the live cat's.
        offset = (round(anchor[0] - caps[index][0]), round(anchor[1] - caps[index][1]))
        moved = Image.new("RGBA", source.size, (0, 0, 0, 0))
        moved.paste(source, offset)

        small = moved.resize((max(1, round(source.width * scale)),
                              max(1, round(source.height * scale))), Image.LANCZOS)
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        cell.alpha_composite(small, (round(live_foot[0] - foot[0] * scale),
                                     round(live_foot[1] - foot[1] * scale)))
        sheet.alpha_composite(cell, (slot * CELL, 0))

    GAME_ART.mkdir(parents=True, exist_ok=True)
    out = GAME_ART / "cat_freeze_4.png"
    sheet.save(out, optimize=True)
    print(f"게임: {out.name}  {sheet.width}x{sheet.height}px  ({STAGES}단계)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
