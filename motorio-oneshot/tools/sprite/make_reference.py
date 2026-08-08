#!/usr/bin/env python3
"""A character drawing into a reference the video model can use.

    python3 tools/sprite/make_reference.py grim.png ../docs/sprite-ref/grim_front.png

The background colour of a reference decides the background colour of the clip
it produces. The first cat reference was transparent and the model invented a
murky grey-green that the chroma key could not lift, leaving a block of it
wobbling behind the character in every frame -- a whole generation wasted. So a
reference is always RGB on the same pure green as the others.

Naive white-keying would be wrong for this character. Grim has cream fur trim
and silver hair, and replacing every white pixel would eat both. The background
is instead filled from the edges inward, which cannot reach an enclosed white
because the character's outline stands between them.
"""

import sys
from collections import deque
from pathlib import Path

from PIL import Image

CHROMA = (0, 255, 0)
# How far a pixel may sit from pure white and still count as background. Paper
# scans and soft drop shadows are never exactly 255, and the outline is far
# darker than this, so the fill stops where the drawing starts.
TOLERANCE = 26


def is_background(pixel: tuple) -> bool:
    return all(channel >= 255 - TOLERANCE for channel in pixel[:3])


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    source = Image.open(sys.argv[1]).convert("RGB")
    width, height = source.size
    pixels = source.load()

    # Flood fill from every edge pixel. Enclosed white -- fur, hair highlights,
    # the whites of the eyes -- is unreachable and survives untouched.
    seen = [[False] * height for _ in range(width)]
    queue = deque()
    for x in range(width):
        for y in (0, height - 1):
            queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            queue.append((x, y))

    filled = 0
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= width or y >= height or seen[x][y]:
            continue
        seen[x][y] = True
        if not is_background(pixels[x, y]):
            continue
        pixels[x, y] = CHROMA
        filled += 1
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    # Square, so the model is not handed an aspect ratio to reinterpret, and
    # padded rather than cropped so nothing is cut off.
    side = max(width, height)
    out = Image.new("RGB", (side, side), CHROMA)
    out.paste(source, ((side - width) // 2, (side - height) // 2))
    out = out.resize((512, 512), Image.LANCZOS)

    destination = Path(sys.argv[2])
    destination.parent.mkdir(parents=True, exist_ok=True)
    out.save(destination)

    corners = [out.getpixel(p) for p in ((3, 3), (508, 3), (3, 508), (508, 508))]
    print(f"REFERENCE: {destination} 512x512 RGB")
    print(f"REFERENCE: filled {filled} background pixels, corners {corners}")
    if not all(c == CHROMA for c in corners):
        print("REFERENCE: corners are not pure chroma -- the key will fail", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
