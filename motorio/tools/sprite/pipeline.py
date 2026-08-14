#!/usr/bin/env python3
"""One clip to one published candidate, in a single command.

    python3 tools/sprite/pipeline.py <clip.mp4> --request mechanic-run-s \\
        --motion run --facing s --cell character128

Every stage already existed and was being driven by hand, which was fine for one
clip and stopped being fine at four: the walk was processed through five separate
invocations plus a throwaway script to copy the chosen frames, and repeating that
per motion is how the frames of one request end up normalised with the settings
of another. The stages are unchanged -- this only removes the chance to run them
in the wrong order or with mismatched arguments.

It stops at the first stage that fails and says which one. A candidate that never
reaches the proposals page is the pipeline working; the whole point is to reject
sequences before a person is asked to judge them.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

import loopfind
import sprite_tool

HERE = Path(__file__).resolve().parent
# Playwright lives in a scratch install rather than in this repository: it is a
# 400MB browser used by the frame extractor and by the browser tests, and it has
# no business in a game repo. The extractor cannot run without it.
NODE_PATH = os.environ.get("SPRITE_NODE_PATH", "")


def cycle_period(signatures: list) -> int:
    """How many source frames one repetition of the motion takes.

    Found by asking, for each candidate lag, how similar every frame is to the
    frame that many later -- and then taking the most *prominent* dip rather than
    the lowest value. The distinction is the whole function.

    On a side walk the true period is an obvious well: lag 10 scores 0.0135 with
    neighbours at 0.022 and 0.016. On the same walk seen from behind, where the
    arms are hidden and the silhouette barely changes, the curve slopes gently
    upward from the shortest lag allowed -- 0.0119 at four, 0.0120 at five --
    and the real period is a shallow dip at ten. Taking the minimum picked four,
    which is not a period at all; sampling eight frames across it produced
    duplicates.

    Prominence is how far a dip sits below the ridges on either side of it, which
    is small for noise on a slope and large for a genuine repeat.
    """
    # Up to half the clip. A third was not enough and the back-facing mining clip
    # is the proof: three full swings in 48 frames put its repeat at lag 20, the
    # search stopped at 16, and the prominence scan skips the endpoints -- so the
    # right answer was not merely missed, it could not be returned. What came
    # back was 4, the shortest lag allowed, and eight frames sampled across four
    # source frames are the same picture eight times. The clip was fine; a person
    # watching the sheet said Grim was standing still, and she was.
    #
    # Half is the ceiling that means anything: at lag n the score averages only
    # len-n pairs, so beyond half the clip the measurement thins out faster than
    # it informs.
    lags = list(range(4, max(6, len(signatures) // 2 + 1)))
    scores = {}
    for lag in lags:
        pairs = [loopfind.distance(signatures[i], signatures[i + lag])
                 for i in range(len(signatures) - lag)]
        scores[lag] = sum(pairs) / len(pairs)

    best_lag = lags[0]
    best_prominence = -1.0
    for index in range(1, len(lags) - 1):
        lag = lags[index]
        if scores[lag] > scores[lag - 1] or scores[lag] > scores[lag + 1]:
            continue
        # The ridge each way: how far the curve climbs before it turns back down.
        left = max(scores[l] for l in lags[:index + 1])
        right = max(scores[l] for l in lags[index:])
        prominence = min(left, right) - scores[lag]
        if prominence > best_prominence:
            best_prominence, best_lag = prominence, lag
    return best_lag


def signal_period(series: list) -> int:
    """The period of a one-dimensional oscillation, by autocorrelation.

    Used for motions where the whole silhouette barely changes and only one
    measurement carries the rhythm -- an idle, where the head rises and falls
    with the breath while everything else holds still.
    """
    mean = sum(series) / len(series)
    centred = [v - mean for v in series]
    best_lag = 0
    best_score = None
    for lag in range(4, max(5, len(series) // 2 + 1)):
        pairs = [centred[i] * centred[i + lag] for i in range(len(series) - lag)]
        score = sum(pairs) / len(pairs)
        if best_score is None or score > best_score:
            best_score, best_lag = score, lag
    return best_lag


def cycle_window(paths: list, want: int, spec: dict, planted: bool) -> dict:
    """`want` frames spread evenly across exactly one repetition.

    Evenly across the period, not consecutively: the period rarely divides by the
    frame count -- ten frames into eight -- so the samples land on fractional
    positions and get rounded. That is correct. Taking consecutive frames instead
    covers only part of the cycle and drops the rest.

    Because the result is a whole cycle, it loops on its own. An earlier fix
    played the idle out and back to hide the fact that its frames were a one-way
    slice; with a full period there is nothing to hide and the playback is a
    plain loop again for every motion.
    """
    signatures = [loopfind.signature(Image.open(p), spec) for p in paths]
    threshold = spec["alpha_threshold"]
    keyed = [sprite_tool.strip_background(Image.open(p).convert("RGBA"), spec) for p in paths]
    shapes = [sprite_tool.silhouette(k, threshold) for k in keyed]

    if planted:
        # A standing clip has no cycle for the image comparison to find: every
        # lag looks equally good, so it returns the smallest one it is allowed
        # and the samples come out duplicated. What repeats in an idle is the
        # breath, and the breath is visible as the top of the head rising and
        # falling -- a one-dimensional signal with a clear period where the whole
        # frame has none.
        bob = [float(s["bounds"][1]) if not s["empty"] else 0.0 for s in shapes]
        period = signal_period(bob)
        print(f"   breathing period {period} frames ({period / 12:.2f}s)")
    else:
        period = cycle_period(signatures)
        print(f"   period {period} frames ({period / 12:.2f}s), sampling {want} across it")
    def sample(start: int) -> list:
        return [(start + round(i * period / want)) % len(paths) for i in range(want)]

    # Frames carrying pixels detached from the body. Chroma keying leaves specks
    # -- an eleven-pixel dot above her head in one mining frame -- and the
    # validator rejects any sequence containing one, correctly. The pipeline
    # knows that rule, so it should not hand over a window it can already tell
    # will fail: on the front mining clip 19 of 48 frames had debris and 29 did
    # not, and the first attempt picked one of the 19.
    dirty = set()
    for index, (image, shape) in enumerate(zip(keyed, shapes)):
        if shape["empty"]:
            dirty.add(index)
            continue
        band = sprite_tool.body_rows(image, threshold)
        if band is None:
            dirty.add(index)
            continue
        if (band[0] - shape["bounds"][1]) + (shape["bounds"][3] - band[1]) > 0:
            dirty.add(index)
    if len(dirty) == len(paths):
        print("   every frame has keying debris; picking on cost alone")
        dirty = set()
    else:
        print(f"   {len(dirty)}/{len(paths)} frames carry keying debris and are avoided")

    starts = range(len(paths))
    if planted:
        # An idle is defined by the feet not moving, which the closure score
        # cannot see: a weight shift closes a loop perfectly well. Pick the start
        # whose sampled frames keep the boots in one place.
        stance = []
        for image, shape in zip(keyed, shapes):
            if shape["empty"]:
                stance.append(None)
                continue
            left, top, right, bottom = shape["bounds"]
            band = image.crop((0, bottom - max(1, (bottom - top) // 8), image.width, bottom))
            feet = sprite_tool.silhouette(band, threshold)
            stance.append(None if feet["empty"] else (feet["bounds"][0], feet["bounds"][2]))

        def cost(start: int) -> float:
            window = [stance[i] for i in sample(start)]
            if any(v is None for v in window):
                return 1e9
            return float(max(max(v[0] for v in window) - min(v[0] for v in window),
                             max(v[1] for v in window) - min(v[1] for v in window)))
    else:
        def cost(start: int) -> float:
            # How well the last sampled frame leads back into the first.
            window = sample(start)
            return loopfind.distance(signatures[window[-1]], signatures[window[0]])

    # A window containing a frame the validator will reject is not a candidate,
    # whatever it scores.
    def penalised(start: int) -> float:
        return cost(start) + (1e6 if any(i in dirty for i in sample(start)) else 0.0)

    best = min(starts, key=penalised)
    if any(i in dirty for i in sample(best)):
        print("   no window avoids the debris; the validator will have the last word")
    chosen = sample(best)
    print(f"   start {best}, frames {chosen}, cost {cost(best):.4f}")
    return {"start": best, "stride": 0, "closure": 0.0, "repeat": 0.0,
            "frames": [paths[i] if isinstance(paths[i], str) else str(paths[i])
                       for i in chosen]}


def run(label: str, command: list, **kwargs) -> None:
    print(f"\n── {label}")
    result = subprocess.run(command, **kwargs)
    if result.returncode != 0:
        raise SystemExit(f"PIPELINE: {label} failed ({result.returncode})")


def main() -> int:
    spec = sprite_tool.load_spec()
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("clip", type=Path)
    parser.add_argument("--request", required=True, help="e.g. mechanic-run-s")
    parser.add_argument("--candidate", default="a")
    parser.add_argument("--motion", default="walk", choices=sorted(spec["animations"]))
    parser.add_argument("--facing", default="s", choices=spec["directions"])
    parser.add_argument("--cell", default="character128", choices=sorted(spec["cells"]))
    parser.add_argument("--work", type=Path, required=True,
                        help="scratch directory for extracted and normalised frames")
    parser.add_argument("--fps", type=int, default=12,
                        help="extraction rate; the cycle finder needs more frames than "
                             "the animation keeps, so this is deliberately above it")
    parser.add_argument("--seed", type=int, default=-1)
    parser.add_argument("--note", default="")
    parser.add_argument("--subject-height", default="",
                        help="a name from spec.subjects, or a number. The character's "
                             "height in source pixels. Used instead of measuring this "
                             "clip, but only for motions the spec marks carries_tool -- "
                             "elsewhere the clip's own measurement is the better number "
                             "and this is ignored.")
    args = parser.parse_args()

    want = int(spec["animations"][args.motion]["frames"])
    dense = args.work / "dense"
    cycle = args.work / "cycle"
    normal = args.work / "normal"
    for directory in (dense, cycle, normal):
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir(parents=True)

    env = dict(os.environ)
    if NODE_PATH:
        env["NODE_PATH"] = NODE_PATH
    run("extract", ["node", str(HERE / "extract_frames.cjs"), str(args.clip), str(dense),
                    "--fps", str(args.fps)], env=env)

    paths = sorted(dense.glob("*.png"))
    print(f"\n── cycle: {len(paths)} frames in, looking for {want}")
    best = cycle_window(paths, want, spec,
                        bool(spec["animations"][args.motion].get("feet_planted")))
    if not best:
        raise SystemExit("PIPELINE: no cycle found -- the clip does not loop")
    for index, source in enumerate(best["frames"]):
        shutil.copy(source, cycle / f"f{index:02d}.png")

    # Only for motions that put a tool in the silhouette. See spec.subjects.
    source_body = 0.0
    if args.subject_height and spec["animations"][args.motion].get("carries_tool"):
        subjects = spec.get("subjects", {})
        if args.subject_height in subjects:
            source_body = float(subjects[args.subject_height]["source_body"])
        else:
            source_body = float(args.subject_height)
    run("normalize", [sys.executable, str(HERE / "sprite_tool.py"), "normalize",
                      str(cycle), str(normal), "--cell", args.cell,
                      "--source-body", str(source_body)])
    # --motion matters: a motion may raise its own centroid tolerance, and mining
    # does because a pickaxe crossing the silhouette moves its centre several
    # pixels a frame. Without it the validator used the default and rejected a
    # correct swing, reporting a limit the spec does not set for mining.
    run("validate", [sys.executable, str(HERE / "sprite_tool.py"), "validate",
                     str(normal), "--cell", args.cell, "--motion", args.motion])
    run("publish", [sys.executable, str(HERE / "sprite_tool.py"), "publish", str(normal),
                    "--request", args.request, "--candidate", args.candidate,
                    "--motion", args.motion, "--facing", args.facing,
                    "--cell", args.cell, "--closure", f"{best['closure']:.4f}",
                    "--seed", str(args.seed), "--note", args.note,
                    "--source-video", str(args.clip)])

    print(f"\nPIPELINE: {args.request}/{args.candidate} published")
    return 0


if __name__ == "__main__":
    sys.exit(main())
