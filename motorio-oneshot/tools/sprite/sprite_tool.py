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
    bottom = max(p[1] for p in pixels)
    row = [p[0] for p in pixels if p[1] == bottom]
    return (sum(row) / len(row), bottom + 1)


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


def normalize_frame(image: Image.Image, cell: dict, spec: dict, palette: list,
                    scale: float) -> Image.Image:
    """One raw frame into one conforming sprite, at a scale set by its sequence.

    Order matters and is the whole trick:
      1. cut the background out, so the silhouette is real before anything is
         measured off it;
      2. resize by the shared scale -- never by this frame's own height, see
         sequence_scale;
      3. place it by its foot, so the ground stays put while the pose moves;
      4. quantise last, once the pixel grid is final -- resampling after
         quantising reintroduces colours that are not in the palette.
    """
    image = image.convert("RGBA")
    image = strip_background(image, spec)

    shape = silhouette(image, spec["alpha_threshold"])
    if shape["empty"]:
        return Image.new("RGBA", tuple(cell["size"]), tuple(spec["background"]))

    left, top, right, bottom = shape["bounds"]
    cropped = image.crop((left, top, right, bottom))
    target_w = max(1, round(cropped.width * scale))
    target_h = max(1, round(cropped.height * scale))
    # BOX is an area average: every source pixel contributes. NEAREST here would
    # be the original sin all over again, picking one pixel in ninety.
    cropped = cropped.resize((target_w, target_h), Image.Resampling.BOX)

    canvas = Image.new("RGBA", tuple(cell["size"]), tuple(spec["background"]))
    anchor_x, anchor_y = cell["foot_anchor"]
    shape = silhouette(cropped, spec["alpha_threshold"])
    if shape["empty"]:
        return canvas
    foot_x, foot_y = shape["foot"]
    canvas.alpha_composite(cropped, (round(anchor_x - foot_x), round(anchor_y - foot_y)))

    return _quantise(canvas, palette, spec["alpha_threshold"])


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

def validate(frames: list, cell: dict, spec: dict, palette: list) -> list:
    """Every reason this sequence is not usable. Empty means it is.

    Deliberately returns all of them rather than the first: a candidate that
    fails on four counts and one that fails on one are different situations,
    and the second is worth a second attempt.
    """
    rules = spec["validation"]
    legal = set(palette)
    problems = []
    previous = None

    for index, (name, image) in enumerate(frames):
        if tuple(image.size) != tuple(cell["size"]):
            problems.append(f"{name}: cell is {image.size}, spec says {tuple(cell['size'])}")
            continue
        shape = silhouette(image, spec["alpha_threshold"])
        if shape["empty"]:
            problems.append(f"{name}: no sprite in the frame")
            previous = None
            continue

        foot_x, foot_y = shape["foot"]
        anchor_x, anchor_y = cell["foot_anchor"]
        drift = max(abs(foot_x - anchor_x), abs(foot_y - anchor_y))
        if drift > rules["max_anchor_drift_px"]:
            problems.append(
                f"{name}: foot at ({foot_x:.1f}, {foot_y:.1f}), anchor is "
                f"{tuple(cell['foot_anchor'])} -- drift {drift:.1f}px. The normaliser "
                f"places this, so any drift is a pipeline bug, not a tolerance")

        if rules["require_palette_conformance"]:
            stray = {p[:3] for p in image.getdata() if p[3] >= spec["alpha_threshold"]} - legal
            if stray:
                sample = ", ".join("#%02x%02x%02x" % c for c in list(stray)[:4])
                problems.append(f"{name}: {len(stray)} colours outside the palette ({sample})")

        if previous is not None:
            jump = ((shape["centroid"][0] - previous["centroid"][0]) ** 2
                    + (shape["centroid"][1] - previous["centroid"][1]) ** 2) ** 0.5
            if jump > rules["max_centroid_jump_px"]:
                problems.append(
                    f"{name}: silhouette centre jumped {jump:.1f}px from the previous "
                    f"frame (limit {rules['max_centroid_jump_px']}). This is the frames "
                    f"not belonging to one cycle -- the exact failure that shipped twice")
            ratio = abs(shape["area"] - previous["area"]) / max(previous["area"], 1)
            if ratio > rules["max_area_change_ratio"]:
                problems.append(
                    f"{name}: sprite area changed {ratio:.0%} in one frame "
                    f"(limit {rules['max_area_change_ratio']:.0%}) -- the character is "
                    f"changing size, not moving")
        previous = shape

    if len(frames) < 2:
        problems.append("a sequence needs at least two frames to be checked as one")
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
    scale = sequence_scale([image for _, image in frames], cell, spec)
    for name, image in frames:
        out = normalize_frame(image, cell, spec, palette, scale)
        out.save(args.out_dir / (Path(name).stem + ".png"))
    print(f"SPRITE: normalised {len(frames)} frames at one shared scale "
          f"{scale:.4f} -> {args.out_dir}")
    return 0


def cmd_validate(args, spec, palette) -> int:
    cell = spec["cells"][args.cell]
    frames = load_frames(args.dir)
    problems = validate(frames, cell, spec, palette)
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
PUBLISH_DIR = REPO / "docs" / "sprite-candidates"
MANIFEST = REPO / "web" / "src" / "generated" / "sprites.json"


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
    problems = validate(frames, cell, spec, palette)
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

    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
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
        request["source_video"] = f"/gamo/sprite-candidates/{video_name}"
        print(f"PUBLISH: source {video_name} ({len(video_bytes)} bytes)")

    request["candidates"] = [c for c in request["candidates"] if c["id"] != args.candidate]
    request["candidates"].append({
        "id": args.candidate,
        "sheet": f"/gamo/sprite-candidates/{name}",
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

    p = subs.add_parser("inspect")
    p.add_argument("image", type=Path)
    p.set_defaults(run=cmd_inspect)

    args = parser.parse_args()
    return args.run(args, spec, palette)


if __name__ == "__main__":
    sys.exit(main())
