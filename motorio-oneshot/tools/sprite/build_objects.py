"""Object art: cutouts in, square proposals out, one comparison sheet per subject.

The subjects here are buildings and machines rather than characters -- the base,
the food bin, the shelter, an ore seam, a miner -- so they do not go through the
character normaliser in sprite_tool.py, which exists to hold a walk cycle's feet
on one anchor. What they need instead is the thing every object in this game
shares: a bottom edge that sits on the ground, and a size that says how much
detail survives the trip down to a tile.

Two things about the input are worth knowing before touching the numbers.

The cutouts arrive with a film of alpha=1 dust across the whole canvas -- three
of the four corners are 1, not 0 -- so a plain getbbox() on the alpha channel
returns the entire 1254 square and every subject looks like it fills its frame.
Everything here thresholds instead.

And RGBA resizing does not premultiply. Those dust pixels carry whatever colour
the matting left behind, and a straight LANCZOS pass smears it into the subject's
edge as a halo. So alpha is cleared below the threshold and the image is
premultiplied for the resize and unpremultiplied after.

    python3 motorio-oneshot/tools/sprite/build_objects.py
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[3]
INBOX = Path.home() / "Workspace" / "Download"
# Beside refs/ and tiles/, which hold the other two kinds of source art. Inside
# tools/, so the originals stay in the repository without riding along in a Web
# export.
OBJECTS = REPO / "motorio-oneshot" / "tools" / "sprite" / "objects"
PROPOSALS = REPO / "graphic" / "proposals"

## Anything at or below this is matting residue rather than art.
ALPHA_FLOOR = 16
SIZES = (128, 64)
## A little air under the subject so it does not sit flush against the frame.
BOTTOM_MARGIN = 3
## What counts as object art in the inbox: a bare subject name and a number, with
## or without the cutout tool's suffix. Deliberately narrow -- the same folder
## holds tile sheets like tile_rock_20.png, and a glob loose enough to sweep
## those up would move them somewhere they do not belong and only be noticed the
## next time a tileset failed to load.
INCOMING = re.compile(r"^([a-z]+)(\d+)(-Photoroom)?$")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def clean(image: Image.Image) -> Image.Image:
    """Drop the matting dust, so the bounding box and the resize both see art."""
    out = image.convert("RGBA")
    alpha = out.getchannel("A").point(lambda v: 0 if v <= ALPHA_FLOOR else v)
    out.putalpha(alpha)
    return out


def content_box(image: Image.Image) -> tuple[int, int, int, int]:
    mask = image.getchannel("A").point(lambda v: 255 if v > ALPHA_FLOOR else 0)
    box = mask.getbbox()
    if box is None:
        raise SystemExit("빈 이미지입니다")
    return box


def fit(image: Image.Image, size: int) -> Image.Image:
    """Into a square, aspect kept, centred across and standing on the bottom.

    Bottom-aligned rather than centred because every one of these is an object
    that stands on a tile: a shelter floating half a cell above its own footprint
    reads as a bug in the game long before anyone suspects the art.
    """
    art = image.crop(content_box(image))
    room = size - BOTTOM_MARGIN
    scale = min(size / art.width, room / art.height)
    target = (max(1, round(art.width * scale)), max(1, round(art.height * scale)))
    small = _resize_rgba(art, target)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((size - target[0]) // 2, size - BOTTOM_MARGIN - target[1]))
    return canvas


def _resize_rgba(art: Image.Image, target: tuple[int, int]) -> Image.Image:
    """LANCZOS with the alpha carried properly.

    Pillow resizes the colour channels without regard to alpha, so the colour
    sitting under a transparent pixel is averaged into its neighbours and the
    subject grows a halo of whatever the matting left there. Multiplying the
    colour by alpha first makes transparent pixels contribute nothing, and
    dividing it back out afterwards restores the colour of what survived.
    """
    r, g, b, a = art.split()
    premultiplied = Image.merge("RGBA", (
        ImageChops.multiply(r, a), ImageChops.multiply(g, a), ImageChops.multiply(b, a), a))
    small = premultiplied.resize(target, Image.LANCZOS)
    sr, sg, sb, sa = small.split()
    return Image.merge("RGBA", (
        _unpremultiply(sr, sa), _unpremultiply(sg, sa), _unpremultiply(sb, sa), sa))


def _unpremultiply(channel: Image.Image, alpha: Image.Image) -> Image.Image:
    colour = list(channel.getdata())
    weight = list(alpha.getdata())
    restored = [0 if not w else min(255, round(c * 255 / w)) for c, w in zip(colour, weight)]
    out = Image.new("L", channel.size)
    out.putdata(restored)
    return out


def checker(size: tuple[int, int], step: int = 8) -> Image.Image:
    """A neutral ground for the sheet, so transparency is visible as transparency."""
    tile = Image.new("RGBA", size, (58, 62, 72, 255))
    draw = ImageDraw.Draw(tile)
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                draw.rectangle([x, y, x + step - 1, y + step - 1], (68, 73, 84, 255))
    return tile


def sheet(name: str, members: list[tuple[str, Image.Image, Image.Image]]) -> Image.Image:
    """One subject, its candidates side by side, each at 128 and at 64.

    Both sizes on purpose. The 128 is what a pixel pass would be traced from and
    the 64 is closer to what the game will actually show, and a design that reads
    at 128 and turns to mush at 64 is exactly what this sheet is for.
    """
    column, pad, title = 300, 16, 44
    big, small = 256, 128
    height = title + big + 26 + small + 30
    canvas = Image.new("RGBA", (column * len(members) + pad, height), (30, 32, 38, 255))
    draw = ImageDraw.Draw(canvas)
    head = ImageFont.truetype(FONT_BOLD, 22)
    label = ImageFont.truetype(FONT, 15)
    draw.text((pad, 12), name, font=head, fill=(236, 214, 168))

    for index, (member, art128, art64) in enumerate(members):
        x = pad + index * column
        for art, box, top in ((art128, big, title), (art64, small, title + big + 26)):
            ground = checker((box, box))
            ground.alpha_composite(art.resize((box, box), Image.NEAREST))
            canvas.alpha_composite(ground, (x, top))
            draw.rectangle([x, top, x + box - 1, top + box - 1], outline=(90, 96, 108))
        draw.text((x, title + big + 6), member, font=label, fill=(240, 240, 240))
        draw.text((x + small + 12, title + big + 26 + small - 18), "64",
                  font=label, fill=(150, 156, 168))
        draw.text((x + big - 24, title + 6), "128", font=label, fill=(150, 156, 168))
    return canvas


def main() -> int:
    OBJECTS.mkdir(parents=True, exist_ok=True)
    PROPOSALS.mkdir(parents=True, exist_ok=True)

    incoming = sorted(path for path in INBOX.glob("*.png") if INCOMING.match(path.stem))
    for source in incoming:
        subject_name, number, _ = INCOMING.match(source.stem).groups()
        target = OBJECTS / f"{subject_name}{number}.png"
        shutil.move(str(source), target)
        print("옮김: %s -> %s" % (source.name, target.relative_to(REPO)))
    if not incoming:
        print("새 파일 없음 -- 기존 원본으로 다시 그립니다")

    # Everything in objects/, not only what arrived today. A subject that gained
    # three new candidates needs its sheet redrawn with all six on it, and a run
    # that only knows about the new ones would quietly publish a sheet missing
    # half its options.
    groups: dict[str, list[tuple[str, Image.Image, Image.Image]]] = {}
    for path in sorted(OBJECTS.glob("*.png")):
        match = INCOMING.match(path.stem)
        if match is None:
            print("건너뜀 (이름 규칙 밖): %s" % path.name)
            continue
        art = clean(Image.open(path))
        renders = {size: fit(art, size) for size in SIZES}
        for size, image in renders.items():
            image.save(PROPOSALS / f"{path.stem}-{size}.png")
        groups.setdefault(match.group(1), []).append((path.stem, renders[128], renders[64]))

    for subject, members in sorted(groups.items()):
        members.sort(key=lambda item: int(INCOMING.match(item[0]).group(2)))
        sheet(subject, members).convert("RGB").save(PROPOSALS / f"_{subject}.png")
        print("시트: graphic/proposals/_%s.png (%d개: %s)"
              % (subject, len(members), ", ".join(name for name, _, _ in members)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
