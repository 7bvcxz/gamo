#!/usr/bin/env python3
"""Puts the source artwork on the graphics page.

    python3 tools/sprite/publish_art.py

Everything in tiles/ and every cat in refs/, downscaled for the web, written to
web/public/art/ with a manifest the page reads. The output is committed.

Why this exists: the repository holds about 39 MB of bought artwork that is not
in the game, and until now the only way to see it was to open the files locally.
Deciding what to use next is a looking problem, and the graphics page is where
looking happens.

Two things it refuses to do by hand. The captions come from art.py, which is
also what the portrait builder reads, so a grade cannot be reassigned in one
place and stay wrong in the other. And the list is the directory rather than a
written-out set of names -- a hand-kept list of files always ends up missing
the one that was added last.

Downscaled to 512 on the long edge and quantised, because eighteen originals is
39 MB and a gallery nobody can load is a gallery nobody looks at. The source
resolution is in the manifest, so the page can say what was cut.
"""

import hashlib
import io
import json
from pathlib import Path

from PIL import Image

from art import CAT_NOTES, TILE_SHEETS, grade_of

GAME = Path(__file__).resolve().parent.parent.parent
REPO = GAME.parent
TILES = GAME / "tools" / "sprite" / "tiles"
REFS = GAME / "tools" / "sprite" / "refs"
PUBLISH_DIR = REPO / "web" / "public" / "art"
MANIFEST = REPO / "web" / "lib" / "generated" / "art.json"

LONG_EDGE = 512
COLOURS = 128


def publish(image: Image.Image, name: str) -> str:
    """Writes one downscaled copy under a content-hashed name, returns its path."""
    fit = min(1.0, LONG_EDGE / max(image.size))
    if fit < 1.0:
        image = image.resize((max(1, round(image.size[0] * fit)),
                              max(1, round(image.size[1] * fit))), Image.LANCZOS)
    if image.mode == "RGBA":
        alpha = image.getchannel("A")
        body = image.convert("RGB").quantize(colors=COLOURS, method=Image.MEDIANCUT,
                                             dither=Image.NONE).convert("RGB")
        image = Image.merge("RGBA", (*body.split(), alpha))
    else:
        image = image.convert("RGB").quantize(colors=COLOURS, method=Image.MEDIANCUT,
                                              dither=Image.NONE).convert("RGB")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    payload = buffer.getvalue()
    # Content hash, for the same reason the sprite sheets carry one: a file
    # republished under its old name keeps showing the old picture to anyone who
    # already loaded it.
    digest = hashlib.sha256(payload).hexdigest()[:12]
    filename = f"{name}-{digest}.png"
    for old in PUBLISH_DIR.glob(f"{name}-*.png"):
        if old.name != filename:
            old.unlink()
    (PUBLISH_DIR / filename).write_bytes(payload)
    return "/art/" + filename


def main() -> None:
    PUBLISH_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    notes = {name: (label, note) for name, label, note in
             [(n, l, t) for n, l, t in TILE_SHEETS]}

    tiles = []
    for path in sorted(TILES.glob("*.png")):
        name = path.stem
        source = Image.open(path)
        label, note = notes.get(name, (name, ""))
        tiles.append({
            "id": name,
            "label": label,
            "note": note,
            "source": list(source.size),
            "bytes": path.stat().st_size,
            "image": publish(source, name),
        })
    # Directory order is alphabetical; the sheet the game actually uses goes
    # first, because "which one is the ground" is the first question.
    order = [name for name, _label, _note in TILE_SHEETS]
    tiles.sort(key=lambda t: order.index(t["id"]) if t["id"] in order else 99)

    cats = []
    for path in sorted(REFS.glob("cat*.png")):
        name = path.stem
        # The chroma-green references are generator input, not artwork: they are
        # the same cat on a keying background and showing them twice says nothing.
        if name.endswith("_front"):
            continue
        source = Image.open(path)
        cats.append({
            "id": name,
            "grade": grade_of(name),
            "note": CAT_NOTES.get(name, ""),
            "source": list(source.size),
            "bytes": path.stat().st_size,
            "image": publish(source, name),
        })
    cats.sort(key=lambda c: (c["grade"] == "", c["id"]))

    MANIFEST.write_text(json.dumps({"tiles": tiles, "cats": cats}, ensure_ascii=False, indent=1)
                        + "\n", encoding="utf-8")
    published = sum((PUBLISH_DIR / Path(item["image"]).name).stat().st_size
                    for item in tiles + cats)
    original = sum(item["bytes"] for item in tiles + cats)
    print("ART: %d tiles + %d cats -> %s  (%.1f MB -> %.1f MB)"
          % (len(tiles), len(cats), PUBLISH_DIR.relative_to(REPO),
             original / 1e6, published / 1e6))


if __name__ == "__main__":
    main()
