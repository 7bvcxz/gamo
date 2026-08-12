"""Object art: cutouts in, square candidates out, published for the proposals page.

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

Writes web/public/object-candidates/ and web/lib/generated/objects.json, which
is what /motorio-oneshot/graphic/proposals reads.
"""
from __future__ import annotations

import hashlib
import io
import json
import re
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops

REPO = Path(__file__).resolve().parents[3]
INBOX = Path.home() / "Workspace" / "Download"
# Beside refs/ and tiles/, which hold the other two kinds of source art. Inside
# tools/, so the originals stay in the repository without riding along in a Web
# export.
OBJECTS = REPO / "motorio-oneshot" / "tools" / "sprite" / "objects"
# Published beside the sprite candidates, because that is where the page that
# shows them reads from. The first version of this wrote a graphic/proposals/
# directory at the repository root, which nothing serves -- the name refers to
# the page at /motorio-oneshot/graphic/proposals, not to a folder.
PUBLISH_DIR = REPO / "web" / "public" / "object-candidates"
MANIFEST = REPO / "web" / "lib" / "generated" / "objects.json"

## The candidates that were chosen, and the size the game draws each at.
##
## Written down here rather than by copying a file into assets/ by hand, so the
## decision is recorded next to the thing that acts on it and a re-run cannot
## quietly disagree with what shipped.
##
## Exported at twice the drawn size, which is the convention the ground already
## follows: the snow atlas is stored at 64 and drawn at 32. The project filters
## textures with NEAREST, so an asset stored much larger than it is drawn throws
## most of its pixels away at a hard edge; twice leaves headroom for the zoom
## keys without turning the art to noise.
ADOPTED = {
    "core": ("base6", 64),
    "shelter": ("home6", 48),
    "food_bin": ("feedbox5", 36),
    "miner": ("miner5", 36),
}
GAME_ART = REPO / "motorio-oneshot" / "assets" / "objects"

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


def publish(image: Image.Image, name: str) -> str:
    """One content-hashed copy, returning the path the page asks for.

    Hashed for the same reason every other generated file here is: republishing
    under the old name keeps showing the old picture to anyone who already loaded
    it, and the candidate sheets learned that the hard way -- a corrected sheet
    sat behind a ten minute cache while the report said the fix had not landed.
    """
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    payload = buffer.getvalue()
    filename = f"{name}-{hashlib.sha256(payload).hexdigest()[:12]}.png"
    for old in PUBLISH_DIR.glob(f"{name}-*.png"):
        if old.name != filename:
            old.unlink()
    (PUBLISH_DIR / filename).write_bytes(payload)
    return "/object-candidates/" + filename


def main() -> int:
    OBJECTS.mkdir(parents=True, exist_ok=True)
    PUBLISH_DIR.mkdir(parents=True, exist_ok=True)
    if not MANIFEST.parent.is_dir():
        print(f"{MANIFEST.parent}가 없습니다. 사이트가 매니페스트를 읽는 곳이므로 "
              f"디렉터리를 만들 것이 아니라 경로가 낡은 것입니다.", file=sys.stderr)
        return 1

    incoming = sorted(path for path in INBOX.glob("*.png") if INCOMING.match(path.stem))
    for source in incoming:
        subject_name, number, _ = INCOMING.match(source.stem).groups()
        target = OBJECTS / f"{subject_name}{number}.png"
        shutil.move(str(source), target)
        print("옮김: %s -> %s" % (source.name, target.relative_to(REPO)))
    if not incoming:
        print("새 파일 없음 -- 기존 원본으로 다시 그립니다")

    # Everything in objects/, not only what arrived today. A subject that gained
    # three new candidates needs its entry rewritten with all six, and a run that
    # only knew about the new ones would publish a list missing half its options.
    subjects: dict[str, list[dict]] = {}
    for path in sorted(OBJECTS.glob("*.png")):
        match = INCOMING.match(path.stem)
        if match is None:
            print("건너뜀 (이름 규칙 밖): %s" % path.name)
            continue
        art = clean(Image.open(path))
        box = content_box(art)
        subjects.setdefault(match.group(1), []).append({
            "id": path.stem,
            "number": int(match.group(2)),
            "sizes": {str(size): publish(fit(art, size), f"{path.stem}-{size}")
                      for size in SIZES},
            "source": [box[2] - box[0], box[3] - box[1]],
        })

    manifest = {"subjects": []}
    for subject, members in sorted(subjects.items()):
        members.sort(key=lambda item: item["number"])
        manifest["subjects"].append({"id": subject, "candidates": members})
        print("%-8s %d개: %s" % (subject, len(members),
                                 ", ".join(m["id"] for m in members)))
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n",
                        encoding="utf-8")

    # Files no candidate points at any more, so a retired subject does not leave
    # its renders published and unreachable.
    referenced = {url.rsplit("/", 1)[-1]
                  for entry in manifest["subjects"]
                  for candidate in entry["candidates"]
                  for url in candidate["sizes"].values()}
    for stale in PUBLISH_DIR.glob("*.png"):
        if stale.name not in referenced:
            stale.unlink()
            print("정리: %s" % stale.name)
    print("매니페스트: %s" % MANIFEST.relative_to(REPO))

    # And the ones that were chosen, into the game.
    GAME_ART.mkdir(parents=True, exist_ok=True)
    for role, (candidate, draw) in sorted(ADOPTED.items()):
        source = OBJECTS / f"{candidate}.png"
        if not source.exists():
            print("채택본 없음: %s -> %s" % (role, source.name), file=sys.stderr)
            return 1
        fit(clean(Image.open(source)), draw * 2).save(GAME_ART / f"{role}.png")
        print("게임: %-9s <- %-9s %dpx (그릴 크기 %d)" % (role, candidate, draw * 2, draw))
    return 0


if __name__ == "__main__":
    sys.exit(main())
