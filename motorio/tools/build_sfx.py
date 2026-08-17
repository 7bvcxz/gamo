#!/usr/bin/env python3
"""Builds every sound in the game from the parameters below.

    python3 tools/build_sfx.py                 # write assets/sfx/*.wav
    python3 tools/build_sfx.py --check         # measure what is there, change nothing

The sounds were already procedural -- generated once and committed as WAVs, with
nothing left that could make them again. That is the same failure the font had
before build_font.cjs: an asset in the repository that can be replaced but not
adjusted. Wanting the deny tone a little lower meant finding whatever produced it
in the first place, and there was nothing to find.

So the sounds are defined here, and the WAVs are output. The numbers started as
measurements of the committed files -- duration, peak, the frequency at four
points through each sound, the zero-crossing rate that says whether it is a sine
or something with partials -- so this reproduces what the game already sounded
like rather than replacing it with someone's idea of better. --check prints those
same measurements for whatever is on disk, which is how the two were compared.

Standard library only, on purpose: this repository ships games that must run from
a fresh clone, and a build step that needs numpy is a build step that stops
working on someone else's machine.
"""

import argparse
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 22050
HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "assets" / "sfx"

# One-shots. Every one is a glide from `f0` to `f1` under a decaying envelope,
# which is the whole vocabulary the game speaks in:
#
#   falling  -- something ended, was refused, was taken away
#   rising   -- something was accepted or produced
#   flat     -- a tick that is not an event, just a response to a keypress
#
# `partials` are added above the fundamental (ratio, gain), and `noise` mixes in
# a little hiss. Only the two sounds that measured brighter than a sine can be --
# alarm and finish -- use either, and they are what makes those two read as an
# instrument rather than a beep.
#
# Brightness is set with `noise` rather than by making a partial loud, because
# partial gain is not a usable control near the point where it matters. The
# measure of brightness here is the zero-crossing rate, and a partial quieter
# than the fundamental does not add crossings at all while one louder than it
# adds them all at once: alarm went 269, 269, 544, 812 per second for gains of
# 0.35, 0.62, 1.30, 1.10. It is a step, not a dial, and it steps right across the
# value being aimed at. Noise moves it smoothly.
SOUNDS = {
    # Placing a machine: a low thunk that drops more than an octave. The heaviest
    # sound in the game because it is the one that changes the world.
    "build":   dict(seconds=0.160, f0=196, f1=86,   peak=0.68, decay=1.15),
    # Taking one back. Same shape, shorter and higher -- undoing is lighter than
    # doing.
    "remove":  dict(seconds=0.080, f0=296, f1=184,  peak=0.43, decay=1.10),
    # A menu tick. Quiet and flat: it answers the key, it does not announce
    # anything.
    "select":  dict(seconds=0.050, f0=658, f1=658,  peak=0.20, decay=1.00),
    # Rising, because it means yes.
    "confirm": dict(seconds=0.160, f0=470, f1=700,  peak=0.30, decay=1.10),
    # A delivery landing in the core. Barely rises -- it happens often, so it
    # cannot be a fanfare.
    "deliver": dict(seconds=0.110, f0=884, f1=995,  peak=0.35, decay=1.10),
    # Refusal: low and falling, the opposite of confirm in both.
    "deny":    dict(seconds=0.140, f0=141, f1=105,  peak=0.31, decay=1.15),
    # Smelting finishing. The octave jump partway through is the point: two
    # notes, so it is an event rather than a tone.
    "alloy":   dict(seconds=0.230, f0=760, f1=800,  peak=0.37, decay=1.10,
                    step=0.5),
    # Warmth running out. Long, low, and with a second partial so it carries over
    # the wind instead of sitting underneath it.
    "alarm":   dict(seconds=0.320, f0=146, f1=126,  peak=0.41, decay=1.05,
                    partials=[(2.0, 0.45), (3.0, 0.22)], noise=0.118, seed=5),
    # The day ending. The longest sound in the game, and a chord rather than a
    # note.
    "finish":  dict(seconds=0.600, f0=248, f1=184,  peak=0.44, decay=1.05,
                    partials=[(1.5, 0.50), (2.0, 0.35), (3.0, 0.15)], noise=0.150,
                    seed=11),
    # A boot in snow, twice per walk cycle. The quietest thing in the game and
    # by far the most frequent -- it plays four times a second while she moves,
    # so anything with a pitch in it becomes a tune within seconds. Almost pure
    # noise under a fast decay, which is what packed snow actually is.
    "step":    dict(seconds=0.075, f0=132, f1=74,   peak=0.30, decay=1.55,
                    noise=0.86, seed=57),
    # Running. Shorter and a little brighter, because the difference the player
    # has to hear is the cadence, not the sound -- fourteen frames a second
    # against ten already carries it, and a louder sound would only make the
    # faster one tiring.
    "step_run": dict(seconds=0.065, f0=158, f1=86,  peak=0.34, decay=1.70,
                    noise=0.90, seed=58),
    # Steel on stone, once per swing. Short, low and mostly noise -- a struck
    # rock has almost no pitch in it, and the little that is there falls.
    "pick":    dict(seconds=0.130, f0=230, f1=88,   peak=0.46, decay=1.30,
                    partials=[(2.0, 0.30)], noise=0.55, seed=31),
    # A cat taking a bite. Quiet on purpose: it repeats every half second while
    # a cat eats and there can be several of them at the bowl, so it has to be
    # something heard rather than something listened to.
    "nibble":  dict(seconds=0.045, f0=940, f1=610,  peak=0.13, decay=1.40,
                    noise=0.35, seed=37),
    # Not an effect: the one note the music is played from. Music.gd triggers it
    # at different pitch_scales, which is why there is one sample and not a
    # score's worth. A rendered title theme would have been the largest file in
    # the game by a wide margin -- twenty-four seconds at this rate is a
    # megabyte, against half a megabyte for everything else put together -- and
    # a sampler costs twenty-two kilobytes and can be rewritten by editing a
    # list of numbers.
    #
    # Tuned to A4. Music.gd's semitones are relative to that, so pitch_scale is
    # just 2**(semitone/12) with nothing to look up.
    "note":    dict(seconds=1.000, f0=440, f1=440,  peak=0.50, decay=2.00,
                    partials=[(2.0, 0.32), (3.0, 0.14), (4.0, 0.06)]),
}

# The one voice. Everything above is a glide under a decaying envelope, and a
# meow is not that shape: it rises, then falls, and the mouth closes on the way
# down. Three things the vocabulary above cannot say, so it gets its own
# generator rather than a fourth optional key on `one_shot`.
#
#   contour   -- (position, hertz) points, interpolated in ratios like the glides
#   partials  -- (ratio, gain at the start, gain at the end); the vowel closing
#                from "야" to "옹" is those upper gains falling, and it is the
#                whole difference between a voice and a siren
#   vibrato   -- (hertz, depth). Small. A steady tone reads as electronic, and
#                this is the only thing in the game that is supposed to be alive
#
# Tuned to a domestic cat: the fundamental starts near 480, peaks around 760 a
# quarter of the way in and lands at 400. Kittens run higher and read as a bird
# at this length; a lower one reads as a cow.
VOICES = {
    "meow": dict(seconds=0.520, peak=0.44,
                 contour=[(0.0, 470), (0.22, 760), (0.55, 690), (1.0, 395)],
                 partials=[(2.0, 0.55, 0.14), (3.0, 0.34, 0.05), (4.0, 0.17, 0.02)],
                 vibrato=(5.5, 0.022), attack=0.10, release=0.34),
}


# The two looping beds. These are not tones but filtered noise, and they are
# built as a sum of sinusoids whose frequencies are exact multiples of 1/length.
# That makes the result periodic by construction, so the loop point is not a
# seam that has to be hidden with a crossfade -- there is no seam. Random phases
# are what turn a stack of harmonics into noise rather than a buzz.
BEDS = {
    # The plateau. Always there, under everything.
    "wind": dict(seconds=7.5, low=26, high=150, peak=0.33, seed=17,
                 sway=[(0.13, 0.35), (0.31, 0.20)]),
    # The cold, which fades up as warmth falls.
    #
    # It used to be one dense band from 2.1 kHz to 9 kHz, which is broadband hiss
    # sitting exactly where the ear is most sensitive -- so it did not read as
    # cold, it read as a machine that had gone wrong. Playtest words: "컴퓨터가
    # 버그났을 때 소리".
    #
    # Two layers instead. Most of it is a hollow low-mid body, the sound of air
    # in a space too big to heat, and above that a handful of *discrete* high
    # partials rather than a band of them -- nine of them, so they beat against
    # each other and shimmer instead of hissing. The shimmer is quiet: it is what
    # makes the body sound cold rather than merely large.
    "cold": dict(seconds=6.0, peak=0.30, seed=23,
                 sway=[(0.11, 0.34), (0.29, 0.18)],
                 # The body sits above the wind's 26-150 Hz rather than on top
                 # of it, or the two beds are one muddy rumble. The shimmer's
                 # weight is per partial and there are 29 times fewer of them, so
                 # at 0.10 it measured as nothing at all -- random phases add as
                 # sqrt(count), so 1.6 across nine is about a third of the body.
                 layers=[dict(low=260, high=780, count=260, weight=1.0),
                         dict(low=2200, high=4600, count=9, weight=1.6)]),
}


def envelope(index: int, total: int, decay: float) -> float:
    """Short attack, then a decay close to linear.

    Measured off the committed sounds: across four equal windows the loudness
    came out roughly 1, 0.7, 0.4, 0.13 of the first, which is (1-u) rather than
    the (1-u)^2 that a decaying beep usually is. The attack is 4ms -- long enough
    that the speaker is not asked for a step, short enough that nothing sounds
    soft.
    """
    attack = max(1, int(RATE * 0.004))
    if index < attack:
        return index / attack
    u = (index - attack) / max(1, total - attack)
    return max(0.0, 1.0 - u) ** decay


def one_shot(name: str, spec: dict) -> list:
    total = int(RATE * spec["seconds"])
    f0, f1 = float(spec["f0"]), float(spec["f1"])
    partials = spec.get("partials", [])
    step = spec.get("step")
    hiss = float(spec.get("noise", 0.0))
    rng = random.Random(spec.get("seed", 0))
    out = []
    phase = 0.0
    phases = [0.0] * len(partials)
    for i in range(total):
        u = i / total
        # Exponential glide, so the interval sounds even rather than the
        # frequency changing evenly -- pitch is heard in ratios.
        frequency = f0 * (f1 / f0) ** u
        if step is not None and u >= step:
            frequency = f0 * (f1 / f0) ** ((u - step) / (1.0 - step))
            frequency *= 2.0
        phase += 2.0 * math.pi * frequency / RATE
        value = math.sin(phase)
        for index, (ratio, gain) in enumerate(partials):
            phases[index] += 2.0 * math.pi * frequency * ratio / RATE
            value += gain * math.sin(phases[index])
        if hiss:
            value += hiss * rng.uniform(-1.0, 1.0)
        out.append(value * envelope(i, total, spec["decay"]))
    return normalise(out, spec["peak"])


def voice(name: str, spec: dict) -> list:
    """A meow: a pitch that rises and falls, over a mouth that closes."""
    total = int(RATE * spec["seconds"])
    points = spec["contour"]
    out = []
    phase = 0.0
    phases = [0.0] * len(spec["partials"])
    for i in range(total):
        u = i / total
        # Between the two contour points that bracket u, in ratios rather than
        # in hertz, for the same reason the glides are exponential: pitch is
        # heard as intervals.
        left, right = points[0], points[-1]
        for a, b in zip(points, points[1:]):
            if a[0] <= u <= b[0]:
                left, right = a, b
                break
        span = max(1e-6, right[0] - left[0])
        frequency = left[1] * (right[1] / left[1]) ** ((u - left[0]) / span)
        frequency *= 1.0 + spec["vibrato"][1] * math.sin(
            2.0 * math.pi * spec["vibrato"][0] * i / RATE)
        phase += 2.0 * math.pi * frequency / RATE
        value = math.sin(phase)
        for index, (ratio, start, end) in enumerate(spec["partials"]):
            phases[index] += 2.0 * math.pi * frequency * ratio / RATE
            value += (start + (end - start) * u) * math.sin(phases[index])
        # An open attack and a long release. The 4ms attack the effects use is
        # what makes them read as struck; a voice is blown.
        if u < spec["attack"]:
            gain = u / spec["attack"]
        elif u > 1.0 - spec["release"]:
            gain = (1.0 - u) / spec["release"]
        else:
            gain = 1.0
        out.append(value * gain)
    return normalise(out, spec["peak"])


def bed(name: str, spec: dict) -> list:
    total = int(RATE * spec["seconds"])
    rng = random.Random(spec["seed"])
    base = 1.0 / spec["seconds"]
    # Either one band, or several with their own densities.
    #
    # The density is the whole character. Hundreds of partials across a band is
    # noise; nine of them is a shimmer, because you hear the individual tones
    # beating rather than the average of all of them. Same generator, and the
    # difference between "wind" and "something is wrong with the speakers" is the
    # count.
    layers = spec.get("layers") or [dict(low=spec["low"], high=spec["high"],
                                         count=400, weight=1.0)]
    harmonics = []
    for layer in layers:
        lowest = max(1, int(layer["low"] / base))
        highest = int(layer["high"] / base)
        stride = max(1, (highest - lowest) // max(1, layer["count"]))
        weight = float(layer.get("weight", 1.0))
        # Every partial an exact multiple of 1/length, so the loop still closes
        # on itself with no seam to hide.
        for k in range(lowest, highest, stride):
            harmonics.append((k * base, rng.uniform(0, 2 * math.pi), weight))
    out = []
    for i in range(total):
        t = i / RATE
        value = 0.0
        for frequency, offset, weight in harmonics:
            value += weight * math.sin(2.0 * math.pi * frequency * t + offset)
        # Slow swells, also at exact multiples of the loop length so they come
        # back round with everything else.
        gain = 1.0
        for rate, depth in spec["sway"]:
            cycles = max(1, round(rate * spec["seconds"]))
            gain *= 1.0 + depth * math.sin(2.0 * math.pi * cycles * t / spec["seconds"])
        out.append(value * gain)
    return normalise(out, spec["peak"])


def normalise(samples: list, peak: float) -> list:
    loudest = max(abs(v) for v in samples) or 1.0
    return [v * peak / loudest for v in samples]


def write(path: Path, samples: list) -> None:
    handle = wave.open(str(path), "w")
    handle.setnchannels(1)
    handle.setsampwidth(2)
    handle.setframerate(RATE)
    handle.writeframes(b"".join(
        struct.pack("<h", max(-32768, min(32767, int(v * 32767)))) for v in samples))
    handle.close()


## What each bed must still sound like when someone edits the recipe.
##
## The cold used to be one dense band from 2.1 kHz to 9 kHz, which is broadband
## hiss sitting exactly where the ear is most sensitive: it did not read as cold,
## it read as a machine that had gone wrong. A playtest called it "컴퓨터가
## 버그났을 때 소리".
##
## Zero crossings per second separates the two cases by an order of magnitude --
## hiss centred at 5 kHz crosses ten thousand times a second, a low body under a
## thin shimmer crosses a couple of thousand. Checked here rather than in the
## game's tests because the imported wav is ADPCM and a test that decodes it as
## raw PCM is measuring its own decoder, not the sound. (It did, and reported
## 10,636 for a file this script had just measured at 2,104.)
BED_ZCR = {"wind": (60, 600), "cold": (600, 6000)}


def check(name: str, path: Path) -> None:
    if name not in BED_ZCR:
        return
    handle = wave.open(str(path))
    frames, rate = handle.getnframes(), handle.getframerate()
    data = struct.unpack("<%dh" % frames, handle.readframes(frames))
    handle.close()
    crossings = sum(1 for i in range(1, len(data))
                    if (data[i] < 0) != (data[i - 1] < 0))
    per_second = crossings * rate / max(1, len(data))
    low, high = BED_ZCR[name]
    if not (low <= per_second <= high):
        raise SystemExit(
            f"SFX_CHECK: {name} 의 초당 영교차 {per_second:.0f}회가 "
            f"{low}~{high} 밖입니다 — 소리의 성격이 바뀌었습니다")


def measure(path: Path) -> str:
    handle = wave.open(str(path))
    frames, rate = handle.getnframes(), handle.getframerate()
    data = struct.unpack("<%dh" % frames, handle.readframes(frames))
    samples = [v / 32768.0 for v in data]
    peak = max(abs(v) for v in samples) if samples else 0.0
    crossings = sum(1 for i in range(1, len(samples))
                    if (samples[i - 1] < 0) != (samples[i] < 0))
    return (f"{frames / rate:6.3f}s  {rate}Hz  peak {peak:.2f}  "
            f"ZCR {crossings / (frames / rate):6.0f}/s")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true",
                        help="measure the files already in assets/sfx and stop")
    parser.add_argument("--only", default="", help="build one sound by name")
    args = parser.parse_args()

    if args.check:
        for path in sorted(OUT.glob("*.wav")):
            print(f"{path.name:12s} {measure(path)}")
        return 0

    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in SOUNDS.items():
        if args.only and args.only != name:
            continue
        write(OUT / f"{name}.wav", one_shot(name, spec))
        print(f"{name:12s} {measure(OUT / f'{name}.wav')}")
    for name, spec in VOICES.items():
        if args.only and args.only != name:
            continue
        write(OUT / f"{name}.wav", voice(name, spec))
        print(f"{name:12s} {measure(OUT / f'{name}.wav')}")
    for name, spec in BEDS.items():
        if args.only and args.only != name:
            continue
        write(OUT / f"{name}.wav", bed(name, spec))
        check(name, OUT / f"{name}.wav")
        print(f"{name:12s} {measure(OUT / f'{name}.wav')}  (loop)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
