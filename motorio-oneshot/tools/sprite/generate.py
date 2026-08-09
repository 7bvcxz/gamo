#!/usr/bin/env python3
"""Asks Atlas Cloud for a clip, waits for it, downloads it.

    set -a; . ~/.config/gamo/secrets.env; set +a
    python3 tools/sprite/generate.py --ref docs/sprite-ref/mechanic_front.png \\
        --motion walk --out incoming/walk_s.mp4 --dry-run

Every call costs real money, so:

  * --dry-run prints the exact payload and the price and calls nothing. Run it
    first. Always.
  * The defaults are the cheapest configuration that can still work: the
    shortest duration the API allows, the lowest resolution, and audio off.
    Audio is on by default at the API and is billed; this game has no use for
    it whatsoever.
  * Resolution is deliberately the floor. The output is going to be crushed to a
    64-pixel sprite, so every pixel above that is paid for and then thrown away.
    Detail is not what decides whether this works -- the silhouette holding
    still between frames is, and that is not something more pixels fix.

The prompt matters more than any parameter here, so it is assembled from parts
rather than left to the caller. Everything in MOTION_PROMPTS is there because
its absence breaks the pipeline downstream: a camera that drifts becomes a
character that drifts, a character that walks out of frame becomes an empty
frame the validator rejects, and a missing foot makes the foot anchor -- the
thing every frame is aligned to -- unmeasurable.
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://api.atlascloud.ai"
PRICE_PER_SECOND = 0.056
# The API sits behind Cloudflare, which rejects urllib's default User-Agent with
# a 403 and error code 1010 -- browser-signature banned. It never reaches the
# API, so nothing is billed, but nothing works either. A real UA string is not a
# trick here; it is the difference between the request being served and not.
USER_AGENT = "gamo-sprite-pipeline/1.0 (+https://github.com/7bvcxz/gamo)"

# Held for every motion. The generator is being asked for a sprite reference,
# not a shot, and these are the differences between the two.
STAGING = (
    "The camera is completely locked: no panning, no zooming, no dolly, no shake. "
    # "walking on the spot" was in here, applied to every motion, which meant the
    # idle prompt said do not walk and then this said walk on the spot. The model
    # obeyed the last instruction and produced four seconds of stepping. Shared
    # staging has to be neutral about what the motion is; it only says the
    # character does not leave the frame.
    "The character stays exactly the same size in frame for the whole clip and "
    "stays centred, staying in one spot rather than travelling across the frame. "
    "Full body always visible including both feet, feet never cropped. "
    "Flat solid chroma green background, one uniform colour, no gradient, no "
    "shadow on the ground, no scenery, no props, no other characters. "
    "Consistent flat lighting throughout, no lighting changes."
)

MOTION_PROMPTS = {
    "walk": "The character from image 1 walks in place, facing the viewer, a simple looping walk cycle at a steady pace.",
    # What separates a run from a fast walk is not speed, and asking for speed
    # does not produce one: "runs in place, leaning slightly forward" came back
    # as brisk walking with no lean worth measuring. A run is a specific set of
    # shapes -- the torso pitched forward, the knee driven up in front, the elbows
    # bent and pumping, and above all a moment where neither foot is touching the
    # ground. That flight phase is the whole tell; a walk always has a foot down.
    # So they are named, and the lean is given a number rather than "slightly".
    #
    # Kept deliberately light: this is a small round character in a heavy coat,
    # and a sprinter's form would look wrong on her. Bouncy rather than driving.
    "run": (
        "The character from image 1 runs in place at a happy bouncy pace, facing "
        "the viewer. The whole body leans forward about ten degrees and stays "
        "leaning for the entire clip. Each stride: one knee lifts high in front so "
        "the thigh comes up toward the chest, then that foot drives down as the "
        "other knee lifts, and at the fastest part of each stride BOTH feet are "
        "off the ground at the same time with the body lifted slightly higher. "
        "The arms are bent at the elbow and pump forward and back, opposite to the "
        "legs. Four complete strides across the clip. Light and cute and springy, "
        "not a heavy or aggressive sprint -- she is small and bundled in a coat."
    ),
    # Spelled out as a full arc with a count, because the short version did not
    # work. "Swings a pickaxe downward and back up in a steady repeating rhythm"
    # produced four seconds of a character holding a pickaxe and shifting it
    # about with no strike in it at all -- no cycle to find, and the clip was
    # unusable. A swing has to be described as travel between two named
    # extremes, and asking for a specific number of repetitions is what makes
    # the period short enough that a cycle fits inside the clip.
    "mine": "The character from image 1 mines with a pickaxe: raises it high above the head with both hands, then swings it down hard to strike the ground in front of the feet, then lifts it back overhead, repeating this complete swing three times at a steady rhythm. The swing is large and obvious, the pickaxe travelling all the way from above the head to the ground and back on every repetition. Facing the viewer, feet planted, the body staying in place.",
    # Spelled out as an absence, because the short version did not work. "Stands
    # still and breathes ... only a small idle sway" produced four seconds of
    # walking on the spot: the boots stepped, the gap between them opened and
    # closed, and the coat hem swung. Every frame of it was a walk pose, so no
    # choice of frames could make an idle out of it -- the best window was just a
    # walk held still, which is what a person watching it said.
    #
    # What a model will not infer is that the motion it should produce is nearly
    # none. So the things that must not happen are listed, the one thing that
    # should is bounded as a percentage, and the number of breaths is given for
    # the same reason the mining prompt gives a number of swings: it fixes how
    # much can happen inside four seconds.
    "idle": (
        "The character from image 1 stands completely still and does NOT walk. "
        "Both feet stay flat on the ground in exactly the same spot for the whole "
        "clip -- they never lift, never step, never slide apart or together. No "
        "weight shifting from one leg to the other, no swaying side to side, no "
        "turning, no leaning. The arms hang still. The ONLY movement is quiet "
        "breathing: the chest and shoulders rise and fall by about two percent of "
        "the body height, roughly three slow breaths across the clip, and the hair "
        "settles very slightly with it. Facing the viewer, a calm standing pose."
    ),
}


def data_uri(path: Path) -> str:
    """A local image as a base64 data URI.

    The API takes URLs or base64. Base64 avoids having to publish the reference
    and wait for a CDN before every single generation, which for a one-off test
    is most of the wall-clock time.
    """
    suffix = path.suffix.lower().lstrip(".")
    mime = "jpeg" if suffix in ("jpg", "jpeg") else suffix
    return f"data:image/{mime};base64," + base64.b64encode(path.read_bytes()).decode()


def unwrap(payload: dict) -> dict:
    """The prediction out of the envelope the API actually returns.

    The published OpenAPI schema says the response *is* a PredictionResponse.
    The service wraps it: {"code": 200, "message": "", "data": {...}}. Read the
    schema, wrote the parser against it, and the first real call reported "no id"
    for a request that had been accepted and was already being billed. Schemas
    describe intent; this reads what arrives.
    """
    inner = payload.get("data")
    return inner if isinstance(inner, dict) else payload


def post(path: str, body: dict, key: str) -> dict:
    request = urllib.request.Request(
        BASE + path, method="POST",
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                 "User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return unwrap(json.loads(response.read()))


def get(path: str, key: str) -> dict:
    request = urllib.request.Request(
        BASE + path, headers={"Authorization": f"Bearer {key}",
                              "User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return unwrap(json.loads(response.read()))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", type=Path, action="append", default=[],
                        help="local reference image, sent as base64; repeat for up to 9")
    parser.add_argument("--ref-url", action="append", default=[],
                        help="reference image already published at a public URL. Preferred: "
                             "the payload stays small and the API fetches it directly")
    parser.add_argument("--motion", default="walk", choices=sorted(MOTION_PROMPTS))
    parser.add_argument("--facing", default="toward the viewer",
                        help="which way the character faces, e.g. 'to the right'")
    parser.add_argument("--subject", default="The character from image 1",
                        help="who is moving, e.g. 'The bipedal cat character from image 1'")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--duration", type=int, default=4, help="seconds; 4 is the API minimum")
    parser.add_argument("--resolution", default="480p")
    parser.add_argument("--ratio", default="1:1")
    parser.add_argument("--seed", type=int, default=-1,
                        help="fix this to keep separate directions of one character consistent")
    parser.add_argument("--model", default="bytedance/seedance-2.0-mini/reference-to-video")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if not args.ref and not args.ref_url:
        parser.error("give at least one --ref or --ref-url")

    # The subject is swapped rather than kept generic. "The character from image 1"
    # is enough when image 1 is a person, but the cat is a bipedal animal in
    # clothes, and naming that is the difference between it walking upright as it
    # does in the game and it dropping onto four legs.
    prompt = (MOTION_PROMPTS[args.motion]
              .replace("The character from image 1", args.subject)
              .replace("facing the viewer", f"facing {args.facing}")
              + " " + STAGING)
    payload = {
        "model": args.model,
        "prompt": prompt,
        "reference_images": list(args.ref_url) + [data_uri(p) for p in args.ref],
        "duration": args.duration,
        "resolution": args.resolution,
        "ratio": args.ratio,
        # Off, and worth stating why: it defaults to on at the API, it is billed,
        # and a sprite sheet has nowhere to put a soundtrack.
        "generate_audio": False,
        "watermark": False,
        "return_last_frame": False,
        "bitrate_mode": "standard",
        "seed": args.seed,
    }

    cost = args.duration * PRICE_PER_SECOND
    printable = dict(payload)
    printable["reference_images"] = list(args.ref_url) + [
        f"<{p.name}, {p.stat().st_size} bytes, base64>" for p in args.ref]
    print(json.dumps(printable, ensure_ascii=False, indent=2))
    print(f"\nGENERATE: {args.duration}s x ${PRICE_PER_SECOND}/s = ${cost:.3f}")
    if args.dry_run:
        print("GENERATE: dry run, nothing was called")
        return 0

    key = os.environ.get("ATLAS_API_KEY")
    if not key:
        print("GENERATE: ATLAS_API_KEY is not set", file=sys.stderr)
        return 1

    try:
        started = post("/api/v1/model/generateVideo", payload, key)
    except urllib.error.HTTPError as error:
        print(f"GENERATE_FAIL: HTTP {error.code} {error.read()[:400].decode(errors='replace')}",
              file=sys.stderr)
        return 1
    request_id = started.get("id")
    print(f"GENERATE: submitted {request_id}, status {started.get('status')}")
    if not request_id:
        print(f"GENERATE_FAIL: no id in {json.dumps(started)[:300]}", file=sys.stderr)
        return 1

    deadline = time.time() + 900
    while time.time() < deadline:
        time.sleep(10)
        state = get(f"/api/v1/model/prediction/{request_id}", key)
        status = state.get("status")
        print(f"  {status}")
        if status == "completed":
            urls = state.get("outputs") or []
            if not urls:
                print("GENERATE_FAIL: completed with no outputs", file=sys.stderr)
                return 1
            args.out.parent.mkdir(parents=True, exist_ok=True)
            download = urllib.request.Request(urls[0], headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(download, timeout=300) as response:
                args.out.write_bytes(response.read())
            print(f"GENERATE: {urls[0]}\nGENERATE: saved {args.out} "
                  f"({args.out.stat().st_size} bytes)")
            return 0
        if status in ("failed", "timeout"):
            print(f"GENERATE_FAIL: {json.dumps(state)[:400]}", file=sys.stderr)
            return 1
    print("GENERATE_FAIL: still not finished after 15 minutes", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
