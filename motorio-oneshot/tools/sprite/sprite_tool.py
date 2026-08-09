#!/usr/bin/env python3
"""Turns raw generated frames into sprites this game will accept, and refuses the
ones it should not.

    python3 tools/sprite/sprite_tool.py normalize <in_dir> <out_dir> --cell character
    python3 tools/sprite/sprite_tool.py validate  <dir>  --cell character
    python3 tools/sprite/sprite_tool.py sheet     <dir>  <out.png>
    python3 tools/sprite/sprite_tool.py inspect   <image>

Why this exists rather than doing it by hand or by eye.

Twice now this repository has shipped a character that wobbled, and both times
the diagnosis in AGENTS.md was the same shape: the frames were each fine on
their own and wrong as a sequence. The first fix aligned the numbers and the
character still changed silhouette; the second found that the generated poses
simply were not continuous. Neither was visible in a still, and both cost a
round of "looks right to me".

So the pipeline's job is not to make frames. It is to *measure* them and throw
away the ones that do not form a sequence, before anyone looks at them. The
generator is interchangeable -- video model, hand-drawn, anything that emits
PNGs -- and this file is the part that decides whether the result is usable.

Everything reads spec.json. Nothing here has a number of its own.
"""

import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image

SPEC_PATH = Path(__file__).with_name("spec.json")


def load_spec() -> dict:
    with SPEC_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def hex_to_rgb(value: str) -> tuple:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


# --- measurement --------------------------------------------------------------
# Everything below works on the alpha channel only. The silhouette is what a
# player reads at 64 pixels, and it is also the thing that was moving when the
# character looked wrong, so it is what gets measured.

def opaque_pixels(image: Image.Image, threshold: int) -> list:
    """(x, y) of every pixel solid enough to count as part of the sprite."""
    alpha = image.getchannel("A")
    width, height = image.size
    data = alpha.load()
    return [(x, y) for y in range(height) for x in range(width) if data[x, y] >= threshold]


def silhouette(image: Image.Image, threshold: int) -> dict:
    """Bounds, area and centroid of the sprite, or None if the frame is empty.

    An empty frame is not an error here -- a video model will happily hand back
    a frame where the character walked out of shot -- but it is something the
    validator has to be able to say out loud rather than silently averaging.
    """
    pixels = opaque_pixels(image, threshold)
    if not pixels:
        return {"empty": True}
    xs = [p[0] for p in pixels]
    ys = [p[1] for p in pixels]
    return {
        "empty": False,
        "area": len(pixels),
        "bounds": (min(xs), min(ys), max(xs) + 1, max(ys) + 1),
        "centroid": (sum(xs) / len(pixels), sum(ys) / len(pixels)),
        # The foot is the horizontal middle of the lowest row that has any
        # sprite in it. Not the centroid, and not the bounding box centre: a
        # raised arm moves both of those and does not move where the character
        # is standing.
        "foot": _foot(pixels),
    }


def _foot(pixels: list) -> tuple:
    """Where the character stands, in edge coordinates.

    Both numbers name a point on the pixel grid rather than a pixel: the y is the
    bottom edge of the lowest occupied row, and the x is the mean of the occupied
    pixels' centres, which is x + 0.5 for a pixel at index x.

    The half matters and its absence was a bug. With plain indices the two axes
    used different conventions, so a sprite placed at the anchor x=64 of a
    128-wide cell was actually half a pixel right of the cell's true centre,
    63.5. Reflecting about the centre then landed the foot at 63 and the
    character stepped sideways the moment it turned -- which is the bug this
    repository already recorded once, from the other end, when a flip was applied
    to the drawing but not to the anchor arithmetic. In edge coordinates a
    reflection maps x to width - x, so a foot on the centre maps onto itself and
    a foot half a pixel off maps to half a pixel off the other way, which is
    correct rather than merely tolerable.
    """
    bottom = max(p[1] for p in pixels)
    row = [p[0] for p in pixels if p[1] == bottom]
    return (sum(x + 0.5 for x in row) / len(row), bottom + 1)


# --- normalisation ------------------------------------------------------------

def sequence_scale(images: list, cell: dict, spec: dict) -> float:
    """One scale factor for a whole sequence, from the median silhouette height.

    This is a sequence-level decision and it took shipping the bug to see why.
    The first version scaled every frame on its own so that each one's bounding
    box came out the target height -- which sounds like exactly what "make them
    the same size" means, and is the opposite of it. A bounding box is not the
    character: in a walk cycle it grows when an arm swings up and shrinks when
    the pose compacts. Normalising it away makes the *character* change size to
    keep the box constant.

    Measured on the first real clip: the generator was consistent to within 4%
    across eight frames, and one frame whose box was 11% taller came out with a
    character 10% smaller than its neighbours. A person spotted it on the
    proposals page immediately. The pipeline had manufactured the exact defect
    it exists to catch.

    Median rather than mean or max: one frame reaching upward should not set the
    scale for the other seven, and with eight frames a single outlier cannot
    move the median at all.
    """
    heights = []
    for image in images:
        keyed = strip_background(image.convert("RGBA"), spec)
        span = body_rows(keyed, spec["alpha_threshold"])
        if span is not None:
            heights.append(span[1] - span[0])
    if not heights:
        return 1.0
    heights.sort()
    median = heights[len(heights) // 2]
    # The middle of the allowed band: aiming at the top of it leaves nothing for
    # a pose that reaches, and aiming at the bottom wastes the resolution this
    # whole exercise is about.
    low, high = cell["body_height"]
    return ((low + high) // 2) / median


def body_rows(image: Image.Image, threshold: int) -> tuple:
    """The longest unbroken run of rows containing sprite, or None.

    Not the full bounding box, because a keyed frame is not always only the
    character. One frame of the first real clip had a twelve-pixel speck stuck
    to the top edge -- a scrap of background the chroma key did not catch -- and
    it made that frame's box eleven percent taller than its neighbours. That fed
    the scale calculation and would have made the character eleven percent
    smaller if the median had not absorbed it. Median survives one bad frame in
    eight; it does not survive a systematic one.

    The longest contiguous run is the cheapest thing that ignores debris without
    needing connected components: a speck at the frame edge is separated from
    the character by empty rows, and the character is always the longer run.
    """
    alpha = image.getchannel("A").load()
    width, height = image.size
    filled = [any(alpha[x, y] >= threshold for x in range(width)) for y in range(height)]
    best = None
    start = None
    for y in range(height + 1):
        if y < height and filled[y]:
            if start is None:
                start = y
        elif start is not None:
            if best is None or y - start > best[1] - best[0]:
                best = (start, y)
            start = None
    return best


def sequence_window(images: list, spec: dict) -> tuple:
    """One crop rectangle, in source pixels, used for every frame.

    This is the alignment, and getting it wrong is what made the character
    shuffle sideways. The first version cropped each frame to its own body and
    then placed it by its own foot -- the horizontal middle of its lowest row.
    In a walk that row belongs to whichever foot is currently down, so the
    reference point swings with the stride. Measured on the four clips: the
    generator held the body centre to within 4-8 pixels of 640 across a whole
    cycle, while the foot midpoint moved 29, 56, 97 and in the cat's case 288.
    Aligning to the steadiest thing available would have been right; aligning to
    the least steady thing produced up to 11.5px of lateral wobble in a 128 cell,
    which is what a person watching it reported.

    So nothing is measured per frame any more. The clips come from a model asked
    for a locked camera and it delivered one, which means the frames are already
    in register with each other -- the only way to keep that is to apply the
    same rectangle to all of them and let whatever moves inside it move.

    The rectangle is the union of the per-frame body bands, so no pose is
    clipped, and it is the same width and height for every frame by
    construction.
    """
    left = top = 10 ** 9
    right = bottom = -1
    for image in images:
        keyed = strip_background(image.convert("RGBA"), spec)
        band = body_rows(keyed, spec["alpha_threshold"])
        if band is None:
            continue
        strip = keyed.crop((0, band[0], keyed.width, band[1]))
        shape = silhouette(strip, spec["alpha_threshold"])
        if shape["empty"]:
            continue
        left = min(left, shape["bounds"][0])
        right = max(right, shape["bounds"][2])
        top = min(top, band[0])
        bottom = max(bottom, band[1])
    if right < 0:
        return None
    return (left, top, right, bottom)


def normalize_frame(image: Image.Image, cell: dict, spec: dict, palette: list,
                    scale: float, window: tuple, offset: tuple) -> Image.Image:
    """One raw frame into one conforming sprite.

    Every number here belongs to the sequence rather than to this frame: the
    scale, the crop rectangle and the placement are all computed once and passed
    in. That is the point -- a frame that decides anything for itself is a frame
    that can disagree with its neighbours, and the eye reads that disagreement as
    the character moving when it should be still.

    Order still matters:
      1. cut the background out, so nothing keyed is carried into the cell;
      2. crop with the shared rectangle -- never this frame's own bounds;
      3. resize by the shared scale;
      4. paste at the shared offset;
      5. quantise last, once the pixel grid is final, because resampling after
         quantising reintroduces colours that are not in the palette.
    """
    image = strip_background(image.convert("RGBA"), spec)
    cropped = image.crop(window)
    target = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    # BOX is an area average: every source pixel contributes. NEAREST here would
    # be the original sin all over again, picking one pixel in ninety.
    cropped = cropped.resize(target, Image.Resampling.BOX)

    canvas = Image.new("RGBA", tuple(cell["size"]), tuple(spec["background"]))
    canvas.alpha_composite(cropped, offset)
    return _quantise(canvas, palette, spec["alpha_threshold"])


def sequence_offset(window: tuple, scale: float, cell: dict) -> tuple:
    """Where the shared crop is pasted, once, for every frame.

    Horizontally the crop's centre goes on the anchor's x, vertically its bottom
    goes on the anchor's y. Both are properties of the rectangle rather than of
    any frame, so the whole sequence moves together or not at all.
    """
    width = max(1, round((window[2] - window[0]) * scale))
    height = max(1, round((window[3] - window[1]) * scale))
    anchor_x, anchor_y = cell["foot_anchor"]
    return (round(anchor_x - width / 2), round(anchor_y - height))


def strip_background(image: Image.Image, spec: dict) -> Image.Image:
    """Remove a flat background by colour, keyed off the corners.

    A video model asked for a character on a solid backdrop gives back a
    backdrop that is *nearly* solid -- compression noise, a soft vignette -- so
    this keys on the median corner colour with a tolerance rather than on an
    exact match. If the image already has real transparency it is left alone.
    """
    if image.getchannel("A").getextrema()[0] < 255:
        return image
    width, height = image.size
    corners = [image.getpixel(p)[:3] for p in
               [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]]
    key = tuple(sorted(c[i] for c in corners)[len(corners) // 2] for i in range(3))
    tolerance = 40
    out = image.copy()
    pixels = out.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2]) <= tolerance:
                pixels[x, y] = (r, g, b, 0)
    return out


def _quantise(image: Image.Image, palette: list, threshold: int) -> Image.Image:
    """Snap every pixel to the nearest legal colour, and every edge to hard.

    Nearest in plain RGB distance. Perceptual distance would be more correct in
    a vacuum and is wrong here: the palette is the game's own colours, and two
    of them being close in RGB is a deliberate choice about shading that a
    perceptual metric would quietly override.
    """
    out = image.copy()
    pixels = out.load()
    width, height = out.size
    cache = {}
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a < threshold:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = min(palette, key=lambda c:
                                 (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)
            snapped = cache[key]
            pixels[x, y] = (snapped[0], snapped[1], snapped[2], 255)
    return out


# --- validation ---------------------------------------------------------------

def validate(frames: list, cell: dict, spec: dict, palette: list,
             motion: str = "") -> list:
    """Every reason this sequence is not usable. Empty means it is.

    Deliberately returns all of them rather than the first: a candidate that
    fails on four counts and one that fails on one are different situations,
    and the second is worth a second attempt.
    """
    rules = spec["validation"]
    # Scaled to the cell, so the rule means the same thing at 64 and at 128.
    body = cell.get("body_height")
    body_mid = sum(body) / 2 if body else cell["size"][1] / 2
    # A motion may raise its own ceiling; see _animation_jump_why in the spec.
    fraction = rules["max_centroid_jump_body"]
    if motion:
        fraction = spec["animations"].get(motion, {}).get("max_centroid_jump_body", fraction)
    jump_limit = fraction * body_mid
    # Area has the same shape of exception: how much of the silhouette may change
    # between frames is a property of the motion. See _animation_area_why.
    area_limit = rules["max_area_change_ratio"]
    if motion:
        area_limit = spec["animations"].get(motion, {}).get("max_area_change_ratio", area_limit)
    legal = set(palette)
    problems = []
    previous = None
    feet = []

    for index, (name, image) in enumerate(frames):
        if tuple(image.size) != tuple(cell["size"]):
            problems.append(f"{name}: cell is {image.size}, spec says {tuple(cell['size'])}")
            continue
        shape = silhouette(image, spec["alpha_threshold"])
        if shape["empty"]:
            problems.append(f"{name}: no sprite in the frame")
            previous = None
            continue

        # No per-frame anchor check any more, and its removal is the fix rather
        # than a relaxation. It used to require every frame's foot -- the middle
        # of its lowest row -- to sit on the anchor, which forced the normaliser
        # to shove each frame sideways to satisfy it. In a walk that row belongs
        # to whichever foot is down, so the requirement was to align to the one
        # measurement in the frame that swings with the stride, and the character
        # visibly shuffled. Placement is now a property of the sequence, checked
        # once below.
        feet.append(shape["foot"])

        # Pixels that are not attached to the body. A chroma speck riding along
        # the top edge passed every check here -- anchor, palette, centroid, area
        # -- because it is small, still, and the right colour, and it only became
        # visible when the same frames were cut at a larger cell. Comparing the
        # full silhouette against the longest unbroken run of body rows names the
        # defect directly, and does not care that a mining swing is legitimately
        # taller than a walk, which any height-spread rule would have to.
        band = body_rows(image, spec["alpha_threshold"])
        if band is not None:
            detached = (band[0] - shape["bounds"][1]) + (shape["bounds"][3] - band[1])
            if detached > 0:
                problems.append(
                    f"{name}: {detached}px of the silhouette is detached from the body "
                    f"(rows {shape['bounds'][1]}-{shape['bounds'][3]}, body "
                    f"{band[0]}-{band[1]}). Keying leftovers, and they stretch this "
                    f"frame so the character reads as a different size")

        if rules["require_palette_conformance"]:
            stray = {p[:3] for p in image.getdata() if p[3] >= spec["alpha_threshold"]} - legal
            if stray:
                sample = ", ".join("#%02x%02x%02x" % c for c in list(stray)[:4])
                problems.append(f"{name}: {len(stray)} colours outside the palette ({sample})")

        if previous is not None:
            jump = ((shape["centroid"][0] - previous["centroid"][0]) ** 2
                    + (shape["centroid"][1] - previous["centroid"][1]) ** 2) ** 0.5
            if jump > jump_limit:
                problems.append(
                    f"{name}: silhouette centre jumped {jump:.1f}px from the previous "
                    f"frame (limit {jump_limit:.1f} = {rules['max_centroid_jump_body']} "
                    f"of a {body_mid:.0f}px body{', ' + motion if motion else ''}). This is the frames not belonging to "
                    f"one cycle -- the exact failure that shipped twice")
            ratio = abs(shape["area"] - previous["area"]) / max(previous["area"], 1)
            if ratio > area_limit:
                problems.append(
                    f"{name}: sprite area changed {ratio:.0%} in one frame (limit "
                    f"{area_limit:.0%}{', ' + motion if motion else ''}) "
                    f"(limit {rules['max_area_change_ratio']:.0%}) -- the character is "
                    f"changing size, not moving")
        previous = shape

    if len(frames) < 2:
        problems.append("a sequence needs at least two frames to be checked as one")
    # The sequence sits where it should. The crop's bottom edge is pasted on the
    # anchor, so the frame that reaches lowest must land exactly there and no
    # frame may go below it. This checks the placement arithmetic without asking
    # any single frame to hold still, which is the distinction that was wrong
    # before.
    if feet:
        anchor_y = cell["foot_anchor"][1]
        lowest = max(y for _, y in feet)
        if abs(lowest - anchor_y) > rules["max_anchor_drift_px"]:
            problems.append(
                f"sequence: lowest foot is at y={lowest}, anchor is {anchor_y}. "
                f"The whole sequence is placed by one offset, so this is the offset "
                f"being wrong, not a frame drifting")

    return problems


# --- commands -----------------------------------------------------------------

def load_frames(directory: Path) -> list:
    paths = sorted(p for p in directory.iterdir()
                   if p.suffix.lower() in {".png", ".webp"})
    return [(p.name, Image.open(p).convert("RGBA")) for p in paths]


def cmd_normalize(args, spec, palette) -> int:
    cell = spec["cells"][args.cell]
    args.out_dir.mkdir(parents=True, exist_ok=True)
    frames = load_frames(args.in_dir)
    if not frames:
        print(f"SPRITE: no frames in {args.in_dir}", file=sys.stderr)
        return 1
    images = [image for _, image in frames]
    scale = sequence_scale(images, cell, spec)
    window = sequence_window(images, spec)
    if window is None:
        print(f"SPRITE: every frame in {args.in_dir} is empty", file=sys.stderr)
        return 1
    offset = sequence_offset(window, scale, cell)
    for name, image in frames:
        out = normalize_frame(image, cell, spec, palette, scale, window, offset)
        out.save(args.out_dir / (Path(name).stem + ".png"))
    print(f"SPRITE: normalised {len(frames)} frames at one shared scale "
          f"{scale:.4f}, one window {window} -> {args.out_dir}")
    return 0


def cmd_validate(args, spec, palette) -> int:
    cell = spec["cells"][args.cell]
    frames = load_frames(args.dir)
    problems = validate(frames, cell, spec, palette, args.motion)
    for problem in problems:
        print(f"SPRITE_FAIL: {problem}")
    if problems:
        print(f"SPRITE: {args.dir.name} rejected on {len(problems)} counts")
        return 1
    print(f"SPRITE: {args.dir.name} passes -- {len(frames)} frames form one sequence")
    return 0


def cmd_sheet(args, spec, palette) -> int:
    frames = load_frames(args.dir)
    if not frames:
        return 1
    width, height = frames[0][1].size
    sheet = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, (_, image) in enumerate(frames):
        sheet.paste(image, (index * width, 0))
    sheet.save(args.out)
    print(f"SPRITE: {len(frames)} frames -> {args.out} ({sheet.width}x{sheet.height})")
    return 0


# The repository root, four levels up from tools/sprite/sprite_tool.py. Counted
# rather than assumed: parents[2] is the game folder, and the first run of
# publish quietly created motorio-oneshot/docs and motorio-oneshot/web instead of
# writing into the real ones.
REPO = Path(__file__).resolve().parents[3]
# Under the site's own public/ rather than docs/, because a candidate is site
# content: it changes several times an hour while a decision is being made, and
# it belongs on whichever host redeploys in seconds. The games stayed in docs/
# for the opposite reason -- 150MB that changes rarely.
PUBLISH_DIR = REPO / "web" / "public" / "sprite-candidates"
# Where the site reads it. This lagged behind the move to Next.js by a day: the
# sheets were being published to the new location while the manifest naming them
# kept going to the old one, so every PNG deployed correctly and the page went on
# asking for the previous build's filenames -- which had just been deleted. The
# symptom was "sheet failed to load" on a site whose files were all present.
MANIFEST = REPO / "web" / "lib" / "generated" / "sprites.json"


def cmd_mirror(args, spec, palette) -> int:
    """A west-facing sequence from an east-facing one, by reflection.

    The game does this at draw time and never ships the flipped frames -- that is
    what mirrored_from_east means, and it is why only five of eight directions
    are ever generated. This command exists to prove the reflection is exact and
    to let a person look at the result before trusting it.

    It is exact because the foot anchor sits on the cell's vertical centre line
    (32 of 64, 64 of 128). Reflect about that line and the anchor maps onto
    itself, so a mirrored frame needs no compensation. An earlier sheet in this
    game had an off-centre anchor, the flip was applied to the drawing but not to
    the anchor arithmetic, and the character jumped sideways the instant it
    turned. Centring the anchor is what removed that whole class of bug; this
    checks the property still holds rather than assuming it.
    """
    cell = spec["cells"][args.cell]
    anchor_x = cell["foot_anchor"][0]
    if anchor_x * 2 != cell["size"][0]:
        print(f"MIRROR: refused -- foot anchor x is {anchor_x} but the cell is "
              f"{cell['size'][0]} wide, so the centre is {cell['size'][0] / 2}. "
              f"Reflection would move the anchor and every frame would step sideways "
              f"on turning.", file=sys.stderr)
        return 1

    frames = load_frames(args.dir)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    flipped = []
    for name, image in frames:
        out = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        out.save(args.out_dir / name)
        flipped.append((name, out))

    problems = validate(flipped, cell, spec, palette, args.motion)
    for problem in problems:
        print(f"SPRITE_FAIL: {problem}")
    if problems:
        return 1
    print(f"MIRROR: {len(flipped)} frames reflected about x={anchor_x} -> {args.out_dir}")
    return 0


def cmd_publish(args, spec, palette) -> int:
    """Put a validated sequence where the proposals page can play it.

    Validation runs again here rather than being trusted from an earlier
    invocation. Publishing is the step that puts something in front of a person
    to choose from, and a candidate that reaches that page has, by being there,
    made a claim about itself. Re-checking costs milliseconds.

    The sheet goes to docs/, which this repository already publishes, so a
    candidate is reachable at a URL the moment it is pushed -- no upload, no
    second host, and the same mechanism that serves the game serves its parts.
    """
    cell = spec["cells"][args.cell]
    frames = load_frames(args.dir)
    problems = validate(frames, cell, spec, palette, args.motion)
    if problems:
        for problem in problems:
            print(f"SPRITE_FAIL: {problem}")
        print("PUBLISH: refused -- a candidate has to pass before anyone is asked about it")
        return 1

    PUBLISH_DIR.mkdir(parents=True, exist_ok=True)
    width, height = frames[0][1].size
    sheet = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, (_, image) in enumerate(frames):
        sheet.paste(image, (index * width, 0))

    # The filename carries a hash of the contents, the same way the game's packs
    # do, and for the same reason. Pages serves these with max-age=600, so a
    # sheet republished under its old name keeps showing the old picture to
    # anyone who already loaded it -- which is exactly what happened the first
    # time a candidate was corrected: the fix was pushed, the page still showed
    # the defect, and the obvious conclusion was that the fix had not worked.
    # A changed sheet is a different URL, so a stale one cannot be served.
    buffer = io.BytesIO()
    sheet.save(buffer, format="PNG")
    digest = hashlib.sha256(buffer.getvalue()).hexdigest()[:12]
    name = f"{args.request}-{args.candidate}-{digest}.png"
    # Older revisions of this same candidate are removed; only the current one
    # is reachable, and nothing accumulates.
    for old in PUBLISH_DIR.glob(f"{args.request}-{args.candidate}-*.png"):
        if old.name != name:
            old.unlink()
    (PUBLISH_DIR / name).write_bytes(buffer.getvalue())

    # Required to exist rather than created. mkdir(parents=True) is what made the
    # path bug silent: when the site moved from Vite to Next and generated/ moved
    # with it, this happily created the old directory again and wrote a manifest
    # nothing imports, while the sheets went to the right place. Everything looked
    # published and the page asked for the previous build's filenames.
    if not MANIFEST.parent.is_dir():
        print(f"PUBLISH: {MANIFEST.parent} does not exist. The site reads the "
              f"manifest from there, so this is the path being stale, not a "
              f"missing directory -- check where the app imports it from.",
              file=sys.stderr)
        return 1
    data = {"requests": []}
    if MANIFEST.exists():
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    request = next((r for r in data["requests"] if r["id"] == args.request), None)
    if request is None:
        request = {"id": args.request, "motion": args.motion, "facing": args.facing,
                   "cell": list(cell["size"]), "candidates": []}
        data["requests"].append(request)
    # The footage the sheet was cut from, published beside it. Eight frames say
    # whether the cycle registers; they cannot say whether the generator gave us
    # a good performance or whether the reduction to the cell is where the
    # quality went. Only the source answers that, and it is 1.4MB -- cheap next
    # to asking for another clip because nobody could tell which step was wrong.
    # Named by content alone, with no request in the name, so one clip cut at two
    # cell sizes is stored once rather than twice. The first version keyed the
    # name to the request and published the identical 1.4MB file under two names.
    if args.source_video:
        video_bytes = args.source_video.read_bytes()
        video_name = "source-" + hashlib.sha256(video_bytes).hexdigest()[:12] + ".mp4"
        (PUBLISH_DIR / video_name).write_bytes(video_bytes)
        request["source_video"] = f"/sprite-candidates/{video_name}"
        print(f"PUBLISH: source {video_name} ({len(video_bytes)} bytes)")

    # Which direction this one covers by reflection. Recorded rather than
    # rendered: the flipped frames are never stored, in the manifest or in the
    # game, because the reflection is exact and a second copy could only ever
    # drift from the first. The page flips the same sheet on its canvas.
    mirror = {"e": "w", "ne": "nw", "se": "sw"}.get(args.facing)
    if mirror and mirror in spec.get("mirrored_from_east", []):
        request["mirrors"] = mirror

    request["candidates"] = [c for c in request["candidates"] if c["id"] != args.candidate]
    request["candidates"].append({
        "id": args.candidate,
        "sheet": f"/sprite-candidates/{name}",
        "frames": len(frames),
        "fps": int(spec["animations"].get(args.motion, {}).get("fps", 10)),
        "closure": round(args.closure, 4),
        "seed": args.seed,
        "note": args.note,
    })
    request["candidates"].sort(key=lambda c: c["id"])
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # Clips no request points at any more. Shared names mean this cannot be
    # decided per request -- only the finished manifest knows what is still in
    # use -- so it is checked here, against the file that was just written.
    referenced = {r.get("source_video", "").rsplit("/", 1)[-1] for r in data["requests"]}
    for stale in PUBLISH_DIR.glob("source-*.mp4"):
        if stale.name not in referenced:
            stale.unlink()
            print(f"PUBLISH: dropped unreferenced {stale.name}")

    print(f"PUBLISH: {args.request}/{args.candidate} -- {len(frames)} frames -> {name}")
    return 0


def cmd_inspect(args, spec, palette) -> int:
    image = Image.open(args.image).convert("RGBA")
    shape = silhouette(image, spec["alpha_threshold"])
    print(f"size {image.size}")
    if shape["empty"]:
        print("empty")
        return 0
    print(f"bounds {shape['bounds']}  area {shape['area']}")
    print(f"centroid ({shape['centroid'][0]:.1f}, {shape['centroid'][1]:.1f})")
    print(f"foot ({shape['foot'][0]:.1f}, {shape['foot'][1]:.1f})")
    colours = {p[:3] for p in image.getdata() if p[3] >= spec["alpha_threshold"]}
    print(f"colours {len(colours)}, outside palette {len(colours - set(palette))}")
    return 0


def main() -> int:
    spec = load_spec()
    palette = [hex_to_rgb(c) for c in spec["palette"]]

    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="command", required=True)

    p = subs.add_parser("normalize")
    p.add_argument("in_dir", type=Path)
    p.add_argument("out_dir", type=Path)
    p.add_argument("--cell", default="character", choices=sorted(spec["cells"]))
    p.set_defaults(run=cmd_normalize)

    p = subs.add_parser("validate")
    p.add_argument("dir", type=Path)
    p.add_argument("--cell", default="character", choices=sorted(spec["cells"]))
    p.add_argument("--motion", default="", choices=[""] + sorted(spec["animations"]),
                   help="lets a motion apply its own centroid tolerance")
    p.set_defaults(run=cmd_validate)

    p = subs.add_parser("sheet")
    p.add_argument("dir", type=Path)
    p.add_argument("out", type=Path)
    p.set_defaults(run=cmd_sheet)

    p = subs.add_parser("publish")
    p.add_argument("dir", type=Path)
    p.add_argument("--request", required=True, help="e.g. mechanic-walk-s")
    p.add_argument("--candidate", required=True, help="e.g. a")
    p.add_argument("--motion", default="walk")
    p.add_argument("--facing", default="s")
    p.add_argument("--closure", type=float, default=0.0)
    p.add_argument("--seed", type=int, default=-1)
    p.add_argument("--note", default="")
    p.add_argument("--cell", default="character", choices=sorted(spec["cells"]))
    p.add_argument("--source-video", type=Path,
                   help="the clip these frames were cut from, published beside the sheet")
    p.set_defaults(run=cmd_publish)

    p = subs.add_parser("mirror")
    p.add_argument("dir", type=Path)
    p.add_argument("out_dir", type=Path)
    p.add_argument("--cell", default="character", choices=sorted(spec["cells"]))
    p.add_argument("--motion", default="", choices=[""] + sorted(spec["animations"]),
                   help="lets a motion apply its own centroid tolerance")
    p.set_defaults(run=cmd_mirror)

    p = subs.add_parser("inspect")
    p.add_argument("image", type=Path)
    p.set_defaults(run=cmd_inspect)

    args = parser.parse_args()
    return args.run(args, spec, palette)


if __name__ == "__main__":
    sys.exit(main())
