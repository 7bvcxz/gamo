#!/usr/bin/env python3
"""Four stages of a frozen cat melting, cut from one generated clip.

    NODE_PATH=<playwright> SPRITE_CHROME=<chromium with H.264> \
      node tools/sprite/extract_frames.cjs melt.mp4 frames --fps 12
    python3 tools/sprite/build_freeze.py frames     # cut the sheet, then publish
    python3 tools/sprite/build_freeze.py --publish  # publish the committed sheet

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

## The cat does not move, and neither do the frames

The generator was asked for an animal that holds still and it did: measured
across all 48 frames, the top of its cap sits between y=94 and y=106 -- twelve
pixels out of 640, under two percent. The camera is locked, so the frames are
already aligned with each other and there is nothing to correct.

The first version of this did correct it, and that is what made the stages
wrong. It tracked the cap by centroid using a strict red threshold, and through
thick ice only a few pixels of the cap survive that threshold -- in the most
frozen frame, one row of them. The centroid of one row is not the centroid of a
cap, so the measurement said the cat had travelled 115 pixels and every early
stage was shoved down by a correction for movement that never happened. The cat
visibly sank between stages one and two.

The lesson is the ordinary one and it cost a re-cut: a measurement taken through
an obstruction measures the obstruction. Loosening the threshold made the cap
readable at every stage and the movement disappeared.

So: one transform, shared by all four stages, and a check at the end that the
cap really does land in the same place in each.
"""
from __future__ import annotations

import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sprite_tool import despeckle  # noqa: E402

HERE = Path(__file__).resolve().parent
GAME_ART = HERE.parent.parent / "assets" / "characters"
REPO = HERE.parent.parent.parent
## Its own directory and its own manifest, not the object candidates'. That
## publisher deletes everything in its directory that its own manifest does not
## name, so anything else written there disappears on its next run -- which is
## the shape of a bug this repository has already had twice.
PUBLISH_DIR = REPO / "web" / "public" / "freeze"
MANIFEST = REPO / "web" / "lib" / "generated" / "freeze.json"

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


def measure(art: Image.Image) -> tuple[float, int]:
    """How much ice is left, and where the top of the cap is.

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
    cap_top = art.height
    width = art.width
    for index, (r, g, b, a) in enumerate(pixels):
        if a < 32:
            continue
        solid += 1
        if b >= r and b > 150:
            ice += 1
        # Loose on purpose. Through thick ice the cap is pale and desaturated;
        # at `r - g > 45` the most frozen frame yielded a single row of pixels,
        # and a centroid taken from that is what produced a phantom 115 pixels
        # of movement. This threshold reads the cap at every stage.
        if r > 140 and r - g > 20 and r - b > 20:
            cap += 1
            cap_top = min(cap_top, index // width)
    if cap == 0:
        raise SystemExit("모자를 찾지 못했습니다")
    return ice / max(solid, 1), cap_top


def _publish_one(image: Image.Image, name: str) -> str:
    """One cell, under a content-hashed name. Returns the path the page uses."""
    payload = io.BytesIO()
    image.save(payload, format="PNG", optimize=True)
    data = payload.getvalue()
    digest = hashlib.sha256(data).hexdigest()[:12]
    filename = f"{name}-{digest}.png"
    PUBLISH_DIR.mkdir(parents=True, exist_ok=True)
    (PUBLISH_DIR / filename).write_bytes(data)
    return f"/freeze/{filename}"


def publish() -> int:
    """The four stages onto the graphics page, beside the cat they turn into.

    Read off the shipped sheet rather than off the frames, so this runs without
    the clip and can only ever show what the game actually loads. The live cat
    goes in the same manifest on purpose: the one thing a person has to judge
    here is whether the animal is in the same place before and after the ice
    goes, and that judgement is impossible if the two are on different pages.
    """
    if not MANIFEST.parent.is_dir():
        print(f"{MANIFEST.parent}가 없습니다. 사이트가 매니페스트를 읽는 곳이므로 "
              f"디렉터리를 만들 것이 아니라 경로가 낡은 것입니다.", file=sys.stderr)
        return 1
    sheet_path = GAME_ART / "cat_freeze_4.png"
    if not sheet_path.exists():
        print("시트가 없습니다: %s" % sheet_path, file=sys.stderr)
        return 1
    sheet = Image.open(sheet_path).convert("RGBA")
    stages = sheet.width // CELL
    manifest = {
        "cell": CELL,
        "sheet": _publish_one(sheet, "cat_freeze_sheet"),
        # How icy each stage is, measured rather than described, so the page can
        # say what "1단계" means without anyone writing a number down.
        "stages": [],
    }
    for index in range(stages):
        cell = sheet.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        ice, _ = measure(cell)
        manifest["stages"].append({
            "index": index,
            "ice": round(ice, 3),
            "image": _publish_one(cell, f"cat_freeze_{index}"),
        })
    live = Image.open(GAME_ART / "cat_idle_s.png").convert("RGBA").crop((0, 0, CELL, CELL))
    manifest["live"] = _publish_one(live, "cat_live")
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n",
                        encoding="utf-8")
    # Anything the manifest no longer points at. Same rule as the other
    # publishers: a renamed stage must not leave its old render served.
    referenced = {manifest["sheet"], manifest["live"]}
    referenced |= {stage["image"] for stage in manifest["stages"]}
    referenced = {url.rsplit("/", 1)[-1] for url in referenced}
    for stale in PUBLISH_DIR.glob("*.png"):
        if stale.name not in referenced:
            stale.unlink()
            print("정리: %s" % stale.name)
    print("발행: %d단계 + 살아있는 고양이 -> %s"
          % (stages, MANIFEST.relative_to(REPO)))
    return 0


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--publish":
        return publish()
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

    # Stated rather than corrected. If a future clip really does move the animal
    # this is where it shows, and the answer then is to ask for a better clip --
    # not to shove the frames about, which is what went wrong the first time.
    drift = max(caps) - min(caps)
    print("모자 top: %d~%d (움직임 %d px / %d)" % (min(caps), max(caps), drift, art[0].height))
    if drift > art[0].height * 0.05:
        print("경고: 클립 안에서 고양이가 움직입니다 — 다시 생성하는 편이 낫습니다",
              file=sys.stderr)

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

    # One transform for all four. The frames are already aligned with each
    # other -- the camera is locked and the animal holds still -- so anything
    # per-stage here would be moving them apart rather than together.
    place = (round(live_foot[0] - foot[0] * scale), round(live_foot[1] - foot[1] * scale))
    sheet = Image.new("RGBA", (CELL * STAGES, CELL), (0, 0, 0, 0))
    for slot, index in enumerate(chosen):
        source = art[index]
        small = source.resize((max(1, round(source.width * scale)),
                               max(1, round(source.height * scale))), Image.LANCZOS)
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        cell.alpha_composite(small, place)
        sheet.alpha_composite(cell, (slot * CELL, 0))

    # The thing the player actually notices, checked rather than assumed: the cat
    # has to be in the same place in every stage, and in the same place as the
    # live sprite that replaces it. The first cut of this sheet failed exactly
    # here -- the cap sat at 56, 50, 42, 40 -- and nothing caught it but an eye.
    tops = []
    for slot in range(STAGES):
        _, top = measure(sheet.crop((slot * CELL, 0, (slot + 1) * CELL, CELL)))
        tops.append(top)
    _, live_top = measure(live)
    spread = max(tops + [live_top]) - min(tops + [live_top])
    print("결과 모자 top: %s · 살아있는 고양이 %d · 최대 차이 %d px" % (tops, live_top, spread))
    if spread > 3:
        print("고양이가 단계마다 다른 자리에 있습니다", file=sys.stderr)
        return 1

    GAME_ART.mkdir(parents=True, exist_ok=True)
    out = GAME_ART / "cat_freeze_4.png"
    sheet.save(out, optimize=True)
    print(f"게임: {out.name}  {sheet.width}x{sheet.height}px  ({STAGES}단계)")
    return publish()


if __name__ == "__main__":
    sys.exit(main())
