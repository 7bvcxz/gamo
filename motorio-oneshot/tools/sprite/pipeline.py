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

import loopfind
import sprite_tool

HERE = Path(__file__).resolve().parent
# Playwright lives in a scratch install rather than in this repository: it is a
# 400MB browser used by the frame extractor and by the browser tests, and it has
# no business in a game repo. The extractor cannot run without it.
NODE_PATH = os.environ.get("SPRITE_NODE_PATH", "")


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
    best = loopfind.pick([str(p) for p in paths], want, spec)
    if not best:
        raise SystemExit("PIPELINE: no cycle found -- the clip does not loop")
    print(f"   start {best['start']} stride {best['stride']} "
          f"closure {best['closure']:.4f} repeat {best['repeat']:.4f}")
    for index, source in enumerate(best["frames"]):
        shutil.copy(source, cycle / f"f{index:02d}.png")

    run("normalize", [sys.executable, str(HERE / "sprite_tool.py"), "normalize",
                      str(cycle), str(normal), "--cell", args.cell])
    run("validate", [sys.executable, str(HERE / "sprite_tool.py"), "validate",
                     str(normal), "--cell", args.cell])
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
