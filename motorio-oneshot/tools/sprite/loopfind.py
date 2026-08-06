"""Finds the best cycle inside a dense dump of frames.

A generated clip does not contain exactly one walk cycle. It contains some
number of cycles at some phase, bracketed by a settle at the start and whatever
the model was doing when the clip ran out. Slicing N frames evenly out of that
gives an animation that jumps at the loop point, and a jump at the loop point is
the single most obvious way an animation reads as broken -- it happens every
cycle, forever, in the player's peripheral vision.

So the frames are searched rather than sliced. Every (start, stride) window is
scored on two things:

  closure -- how alike the first frame and the frame *after* the last one are.
             This is the seam the player will actually see, once per loop.
  repeat  -- whether any two frames in the window are the same pose. A window
             that alternates between two drawings closes perfectly, so without
             this it wins.

There was a third term, evenness of motion, and it was wrong. Pixel-art
animation is a cycle of distinct drawings, not interpolated movement: measured
on a real four-pose cycle the steps came out 0.028, 0.042, 0.031, 0.003 -- wildly
uneven, and correct. Scoring evenness actively penalised the true cycle and
preferred a coarser sampling that happened to land on equal spacing. It is kept
only as a reported number, because it is useful to see and useless to optimise.

Both are measured on the silhouette, downsampled to a small grid. Not on colour:
the thing that reads as wrong at 64 pixels is the shape changing, and colour
distance would let a re-lit frame outvote a mis-posed one.
"""

from PIL import Image

import sprite_tool

GRID = 24
"""Silhouette comparison resolution.

Coarse on purpose. At full resolution two frames of the same pose differ by
compression noise around the edges and the score stops discriminating; at this
size the number tracks what a person means by "the same pose".
"""


def signature(image: Image.Image, spec: dict) -> list:
    """A frame reduced to coverage per cell of a small grid.

    The background is keyed out first, through the same function the normaliser
    uses. A raw extracted frame is an opaque rectangle -- the character sits on
    whatever flat colour the generator was asked for -- so its alpha channel is
    255 everywhere and every frame has an identical silhouette. The first run of
    this finder rejected all 47 frames of a known-good clip for exactly that
    reason. Sharing the function also means the shape this scores is the shape
    that will actually be cut out, rather than a second opinion about it.
    """
    image = sprite_tool.strip_background(image.convert("RGBA"), spec)
    alpha = image.getchannel("A")
    small = alpha.resize((GRID, GRID), Image.Resampling.BOX)
    return [v / 255.0 for v in small.getdata()]


def distance(a: list, b: list) -> float:
    """Mean absolute difference between two signatures, 0 identical to 1 opposite."""
    return sum(abs(x - y) for x, y in zip(a, b)) / len(a)


def find_cycle(signatures: list, want: int, max_stride: int = 4) -> dict:
    """The best window of `want` frames, as {start, stride, closure, flow, score}.

    Stride exists because the clip's frame rate and the animation's are unrelated:
    a walk cycle that takes twelve extracted frames has to become an eight-frame
    animation, and taking every other frame is how. Strides above four start
    aliasing the motion rather than sampling it, so the search stops there.
    """
    candidates = []
    frames = len(signatures)
    for stride in range(1, max_stride + 1):
        span = want * stride
        if span >= frames:
            continue
        for start in range(0, frames - span):
            window = [signatures[start + i * stride] for i in range(want)]
            # The seam: the frame that would follow the last one if the sequence
            # looped, against the one it would actually be followed by.
            closure = distance(window[0], signatures[start + span])
            steps = [distance(window[i], window[i + 1]) for i in range(want - 1)]
            average = sum(steps) / len(steps) if steps else 0.0
            # Flow is the spread of the step sizes, not their size. A cycle is
            # allowed to be fast; it is not allowed to be uneven.
            flow = max(steps) - min(steps) if steps else 0.0
            # A window where nothing moves would score perfectly on both, so it
            # is disqualified rather than ranked: a still sequence is not an
            # animation, and a generator that produced one has failed.
            if average < 0.004:
                continue
            # Distinctness. A window that alternates between two poses closes
            # perfectly and steps perfectly evenly, so both terms above actively
            # *prefer* it -- on a test clip whose true cycle was four poses long
            # this finder's first answer was two poses sampled twice, scoring a
            # flawless zero. Any pair of frames closer together than one step is
            # the same pose appearing twice, and that is what disqualifies it.
            pairs = [distance(window[i], window[j])
                     for i in range(want) for j in range(i + 1, want)]
            repeat = max(0.0, average - min(pairs)) if pairs else 0.0
            score = closure * 3.0 + repeat * 3.0
            candidates.append({"start": start, "stride": stride, "closure": closure,
                               "flow": flow, "motion": average, "repeat": repeat,
                               "score": score})
    if not candidates:
        return None
    # Among everything close to the best, take the smallest stride.
    #
    # Not a tiebreak fudge -- a correctness rule. Stride 1 is the only sampling
    # that preserves the clip's own frame order. With a cycle of period P, a
    # stride that does not divide P advances the phase by (stride mod P) each
    # step, so stride 3 on a four-pose cycle walks the phase backwards and the
    # animation plays in reverse. Invisible on an idle, moonwalking on a walk.
    #
    # A larger stride is only ever needed when the generator produced more frames
    # per cycle than the animation wants, and in that case stride 1 cannot span a
    # cycle and loses on closure by a wide margin rather than a narrow one. So a
    # near-tie always means stride 1 is right: measured on a four-pose test clip,
    # stride 1 scored 0.0558 and stride 3 scored 0.0548, and stride 3 was the
    # reversed reading of the same cycle.
    floor = min(c["score"] for c in candidates)
    close_enough = [c for c in candidates if c["score"] <= floor * 1.15 + 0.002]
    return min(close_enough, key=lambda c: (c["stride"], c["score"]))


def pick(paths: list, want: int, spec: dict, max_stride: int = 4) -> dict:
    """find_cycle over image paths. Returns the result with `frames` filled in."""
    signatures = [signature(Image.open(p), spec) for p in paths]
    best = find_cycle(signatures, want, max_stride)
    if best is None:
        return {}
    best["frames"] = [paths[best["start"] + i * best["stride"]] for i in range(want)]
    return best
