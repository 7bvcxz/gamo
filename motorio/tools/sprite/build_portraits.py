#!/usr/bin/env python3
"""Cuts the grade portraits the gacha result window draws.

    python3 tools/sprite/build_portraits.py

The output is committed. Re-run it when a grade is reassigned in art.py.

Still images, and that is the right picture for where they are used: the result
window is a card. The world is a different question -- there a cat walks in
three directions, eats and works, which is six generated clips per grade -- and
this tool does not pretend to answer it.

192 pixels, because the largest a portrait is ever drawn is the single-pull tile
on a phone, about 208 device pixels, and the art is soft enough that the last
8% is not worth carrying. Quantised to 96 colours with the alpha split off
first: quantising RGBA keeps one fully transparent index and turns every soft
edge into a hard cut.
"""

from pathlib import Path

from PIL import Image

from art import GRADE_ARTWORK

GAME = Path(__file__).resolve().parent.parent.parent
REFS = GAME / "tools" / "sprite" / "refs"
OUTPUT = GAME / "assets" / "portraits"
CELL = 192
COLOURS = 96


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for grade, source, _note in GRADE_ARTWORK:
        image = Image.open(REFS / (source + ".png")).convert("RGBA")
        box = image.getbbox()
        if box is None:
            raise SystemExit("%s is empty" % source)
        image = image.crop(box)
        fit = min((CELL - 8) / image.size[0], (CELL - 8) / image.size[1])
        image = image.resize((max(1, round(image.size[0] * fit)),
                              max(1, round(image.size[1] * fit))), Image.LANCZOS)
        # Centred across, standing on the floor of the cell: these are animals on
        # their feet, and centring vertically leaves the tall ones hovering.
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        cell.alpha_composite(image, ((CELL - image.size[0]) // 2, CELL - 4 - image.size[1]))
        alpha = cell.getchannel("A")
        body = cell.convert("RGB").quantize(colors=COLOURS, method=Image.MEDIANCUT,
                                            dither=Image.NONE).convert("RGB")
        out = Image.merge("RGBA", (*body.split(), alpha))
        path = OUTPUT / (grade + ".png")
        out.save(path, optimize=True)
        print("PORTRAIT: %-4s <- %-10s %d bytes" % (grade.upper(), source, path.stat().st_size))


if __name__ == "__main__":
    main()
