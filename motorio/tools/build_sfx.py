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
    # The fire at work, once a second while it makes something (1.0.42). A
    # tick, not a clank: high, very short and quiet, with a little hiss so it
    # reads as a mechanism rather than a beep. It repeats, so it must be
    # something heard rather than listened to.
    "tick":    dict(seconds=0.040, f0=1320, f1=1240, peak=0.16, decay=1.45,
                    noise=0.25, seed=71),
    # The make finishing and the thing popping out of the fire: a short rising
    # bubble. Rising, because something was produced.
    "pop":     dict(seconds=0.090, f0=540, f1=1020,  peak=0.34, decay=1.25),
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


# The looping beds (Quality Pass 01, 2026-09-27).
#
# Both used to be sums of sinusoids at exact multiples of 1/length -- periodic by
# construction, so no seam -- and both failed in playtests:
#
#   wind  26-150 Hz. 84% of its energy below 150 Hz and 62% below 100: not wind,
#         a drone pressing on the ear for the whole day ("브금이라기보다 굉음이
#         계속 반복된다, 귀가 아프다"). And the partials were evenly spaced, so the
#         sum had an envelope that repeated every 1/spacing seconds -- twice in a
#         7.5 second loop. The loop was audible inside itself.
#   cold  first a 2.1-9 kHz hiss ("컴퓨터가 버그났을 때 소리"), then a body with
#         nine discrete partials beating over it ("얼어붙을 때 반복되는 괴음").
#         Both were a *separate sound* for cold, and both read as a fault.
#
# Now they are filtered noise -- real noise through band filters, which has no
# spacing to repeat -- and the loop is closed by crossfading the tail into the
# head (equal power, so the level does not dip at the join). The swells are sine
# envelopes at whole cycles per loop, evaluated on the loop's own clock, so the
# crossfaded tail swells exactly as the head does. The two loops are 16 and 12.2
# seconds: they do not divide, so the pair only lines up again after minutes, and
# the gusts on top (`GUSTS`) arrive at random.
#
# And cold is no longer its own sound. It is *more wind* -- a gustier layer in the
# mid-range that rises with exposure -- plus her breath and one small crackle of
# ice when it gets worse (`BREATHS`, `SOUNDS["frost"]`). The direction document
# (design/AUDIO_DIRECTION.md) has why.
BEDS = {
    # The plateau. A body of moving air above 170 Hz and a thinner layer over
    # it; nothing below, so the whole of it is wind and none of it is rumble.
    "wind": dict(seconds=16.0, xfade=1.5, peak=0.50, seed=17,
                 layers=[dict(low=170, high=650, weight=1.0,
                              sway=[(2, 0.35), (3, 0.25), (7, 0.10)]),
                         dict(low=650, high=2200, weight=0.35,
                              sway=[(3, 0.45), (5, 0.25)])]),
    # The cold: the wind picking up. Mid-range and gusty, and quieter than the
    # wind at its loudest -- it adds to the weather rather than replacing it.
    "cold": dict(seconds=12.2, xfade=1.2, peak=0.45, seed=23,
                 layers=[dict(low=450, high=1500, weight=1.0,
                              sway=[(2, 0.50), (3, 0.30), (5, 0.15)])]),
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


class Biquad:
    """An RBJ biquad: low-pass, high-pass or constant-peak band-pass.

    Enough filter for wind, breath and fire, in the standard library. `set` can
    be called while running -- a gust sweeps its band by resetting the centre
    every few dozen samples, and the state carries across.
    """

    def __init__(self, kind: str, frequency: float, q: float = 0.7071):
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self.set(kind, frequency, q)

    def set(self, kind: str, frequency: float, q: float = 0.7071) -> None:
        w0 = 2.0 * math.pi * min(frequency, RATE * 0.45) / RATE
        c, sn = math.cos(w0), math.sin(w0)
        alpha = sn / (2.0 * q)
        if kind == "lp":
            b0, b1, b2 = (1.0 - c) / 2.0, 1.0 - c, (1.0 - c) / 2.0
        elif kind == "hp":
            b0, b1, b2 = (1.0 + c) / 2.0, -(1.0 + c), (1.0 + c) / 2.0
        else:
            b0, b1, b2 = alpha, 0.0, -alpha
        a0 = 1.0 + alpha
        self.b0, self.b1, self.b2 = b0 / a0, b1 / a0, b2 / a0
        self.a1, self.a2 = -2.0 * c / a0, (1.0 - alpha) / a0

    def __call__(self, x: float) -> float:
        y = (self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2
             - self.a1 * self.y1 - self.a2 * self.y2)
        self.x2, self.x1 = self.x1, x
        self.y2, self.y1 = self.y1, y
        return y


def band(low: float, high: float) -> list:
    """Four poles each side: 24 dB an octave, so 'above 170 Hz' means it."""
    return [Biquad("hp", low), Biquad("hp", low), Biquad("lp", high), Biquad("lp", high)]


def rms(samples: list) -> float:
    return math.sqrt(sum(v * v for v in samples) / max(1, len(samples))) or 1.0


def bed(name: str, spec: dict) -> list:
    """Filtered noise, crossfaded into a loop with no seam."""
    total = int(RATE * spec["seconds"])
    fade = int(RATE * spec["xfade"])
    mixed = [0.0] * (total + fade)
    for number, layer in enumerate(spec["layers"]):
        rng = random.Random(spec["seed"] * 31 + number)
        filters = band(layer["low"], layer["high"])
        # Pre-roll, so the filters have settled before the first kept sample.
        for _ in range(4096):
            v = rng.uniform(-1.0, 1.0)
            for f in filters:
                v = f(v)
        phases = [rng.uniform(0.0, 2.0 * math.pi) for _ in layer["sway"]]
        raw = []
        for i in range(total + fade):
            v = rng.uniform(-1.0, 1.0)
            for f in filters:
                v = f(v)
            # The swell on the loop's clock: the tail past `total` swells as the
            # head does, which is what lets the crossfade be invisible.
            t = (i % total) / total
            gain = 1.0
            for (cycles, depth), phase in zip(layer["sway"], phases):
                gain *= 1.0 + depth * math.sin(2.0 * math.pi * cycles * t + phase)
            raw.append(v * gain)
        # Layers are weighed by loudness, not by whatever their bandwidth made
        # them -- a band twice as wide is not meant to be twice as loud.
        scale = layer["weight"] / rms(raw)
        for i, v in enumerate(raw):
            mixed[i] += v * scale
    out = mixed[:total]
    for i in range(fade):
        a = i / fade
        out[i] = mixed[i] * math.sqrt(a) + mixed[total + i] * math.sqrt(1.0 - a)
    return normalise(out, spec["peak"])


# One-shot weather and breath. Longer than the effects and not in the effect
# bank: Audio.gd plays them from its own schedulers, at random intervals, so the
# plateau never has two gusts in the same place of the same loop.
GUSTS = {
    # A gust: the band rises as it swells and falls as it passes. Three takes
    # with different lengths, sweeps and seeds.
    "gust_1": dict(seconds=3.2, sweep=(260, 780, 330), q=0.9, attack=0.40, peak=0.55, seed=101),
    "gust_2": dict(seconds=4.1, sweep=(220, 620, 300), q=1.1, attack=0.33, peak=0.55, seed=102),
    "gust_3": dict(seconds=2.6, sweep=(320, 980, 420), q=0.8, attack=0.45, peak=0.55, seed=103),
}
BREATHS = {
    # Her breath in the cold: a soft exhale through the mouth, with a formant so
    # it is a breath and not a hiss. Quiet and not often -- see Audio.gd.
    "breath_1": dict(seconds=0.72, formant=1150, peak=0.45, seed=201),
    "breath_2": dict(seconds=0.75, formant=980, peak=0.45, seed=202),
    "breath_3": dict(seconds=0.68, formant=1300, peak=0.45, seed=203),
}


def gust(name: str, spec: dict) -> list:
    total = int(RATE * spec["seconds"])
    rng = random.Random(spec["seed"])
    f0, f1, f2 = spec["sweep"]
    attack = spec["attack"]
    sweep = Biquad("bp", f0, spec["q"])
    floor = [Biquad("hp", 160.0), Biquad("hp", 160.0), Biquad("lp", 2600.0)]
    air = Biquad("hp", 1600.0)
    out = []
    for i in range(total):
        u = i / total
        if u < attack:
            centre = f0 * (f1 / f0) ** (u / attack)
            env = math.sin(0.5 * math.pi * u / attack) ** 2
        else:
            centre = f1 * (f2 / f1) ** ((u - attack) / (1.0 - attack))
            env = math.cos(0.5 * math.pi * (u - attack) / (1.0 - attack)) ** 2
        if i % 32 == 0:
            sweep.set("bp", centre, spec["q"])
        v = rng.uniform(-1.0, 1.0)
        # A breath of top so it is air and not a filtered tone -- a breath only:
        # at 0.12 the top was a sixth of the gust and it hissed.
        value = sweep(v) + 0.03 * air(v)
        for f in floor:
            value = f(value)
        out.append(value * env)
    return normalise(out, spec["peak"])


def breath(name: str, spec: dict) -> list:
    total = int(RATE * spec["seconds"])
    rng = random.Random(spec["seed"])
    floor = [Biquad("hp", 380.0), Biquad("hp", 380.0)]
    mouth = Biquad("bp", spec["formant"], 1.3)
    teeth = Biquad("bp", spec["formant"] * 2.3, 2.2)
    # No sibilance: a tired breath in the cold is 'hhh', not 'sss'.
    soft = [Biquad("lp", 3000.0), Biquad("lp", 3000.0)]
    out = []
    for i in range(total):
        u = i / total
        # In quickly, out slowly, a little uneven in the middle.
        if u < 0.14:
            env = math.sin(0.5 * math.pi * u / 0.14) ** 2
        else:
            env = math.cos(0.5 * math.pi * (u - 0.14) / 0.86) ** 1.6
        env *= 1.0 + 0.06 * math.sin(2.0 * math.pi * 5.0 * i / RATE)
        v = rng.uniform(-1.0, 1.0)
        for f in floor:
            v = f(v)
        value = mouth(v) + 0.12 * teeth(v)
        for f in soft:
            value = f(value)
        out.append(value * env)
    return normalise(out, spec["peak"])


# Struck, ringing things: the music's one sample, the chime when something
# important reaches her, the fire growing. A bell rather than the glide the
# effects use -- each partial decays on its own clock, the high ones first, which
# is what makes a struck tone sound warm instead of electronic.
#
#   partials  (ratio, gain, decay multiplier); the multiplier shortens that
#             partial's ring, so 4.2 is a bright tine that is gone in a moment
BELL = [(1.0, 1.0, 1.0), (2.0, 0.22, 1.7), (3.0, 0.07, 2.6), (4.2, 0.06, 5.0)]


def bell_into(out: list, start: float, frequency: float, gain: float, ring: float,
              partials: list = BELL, attack: float = 0.005) -> None:
    first = int(RATE * start)
    length = min(len(out) - first, int(RATE * ring * 5.0))
    for index, (ratio, weight, speed) in enumerate(partials):
        f = frequency * ratio
        if f >= RATE * 0.45:
            continue
        tau = ring / speed
        step = 2.0 * math.pi * f / RATE
        for i in range(max(0, length)):
            t = i / RATE
            env = math.exp(-t / tau) * min(1.0, t / attack)
            out[first + i] += gain * weight * env * math.sin(step * i)


def grain_into(out: list, start: float, seconds: float, low: float, gain: float,
               rng: random.Random) -> None:
    """A speck of noise above `low` -- ice, grit, a spark."""
    first = int(RATE * start)
    length = int(RATE * seconds)
    filters = [Biquad("hp", low), Biquad("hp", low)]
    for i in range(min(length, len(out) - first)):
        v = rng.uniform(-1.0, 1.0)
        for f in filters:
            v = f(v)
        out[first + i] += gain * v * math.exp(-5.0 * i / max(1, length))


def thump_into(out: list, start: float, f0: float, f1: float, seconds: float,
               gain: float) -> None:
    """A short low impact. The only low end the game allows: an event, and brief."""
    first = int(RATE * start)
    length = int(RATE * seconds)
    phase = 0.0
    for i in range(min(length, len(out) - first)):
        u = i / length
        phase += 2.0 * math.pi * (f0 * (f1 / f0) ** u) / RATE
        out[first + i] += gain * math.sin(phase) * math.exp(-4.5 * u) * min(1.0, i / 40.0)


def noise_into(out: list, start: float, seconds: float, low: float, high: float,
               gain: float, rng: random.Random, attack: float = 0.01,
               decay: float = 0.3) -> None:
    """A band of noise that strikes and decays: a whoosh, a crunch, a burst."""
    first = int(RATE * start)
    length = int(RATE * seconds)
    filters = band(low, high)
    for i in range(min(length, len(out) - first)):
        t = i / RATE
        v = rng.uniform(-1.0, 1.0)
        for f in filters:
            v = f(v)
        env = min(1.0, t / max(attack, 1e-4)) * math.exp(-t / decay)
        out[first + i] += gain * v * env


def swell_into(out: list, start: float, seconds: float, sweep: tuple, q: float,
               gain: float, rng: random.Random) -> None:
    """Noise rising and falling while its band moves: a gust, a rocket, a breath of air."""
    first = int(RATE * start)
    length = int(RATE * seconds)
    f0, f1 = sweep
    bp = Biquad("bp", f0, q)
    floor = Biquad("hp", 160.0)
    for i in range(min(length, len(out) - first)):
        u = i / length
        if i % 32 == 0:
            bp.set("bp", f0 * (f1 / f0) ** u, q)
        env = math.sin(math.pi * u) ** 2
        out[first + i] += gain * floor(bp(rng.uniform(-1.0, 1.0))) * env


def blank(seconds: float) -> list:
    return [0.0] * int(RATE * seconds)


# Composed sounds. Each is a small recipe over the helpers above, written as a
# function so the numbers sit next to what they do.
def made_note() -> list:
    # The music's one sample, A4. A bell now: the old note was a plucked tone the
    # title theme struck two octaves down at full weight every four seconds.
    out = blank(1.6)
    bell_into(out, 0.0, 440.0, 1.0, 0.9)
    return normalise(out, 0.5)


def made_chime() -> list:
    # Something important reaching her hands: three notes climbing a C major
    # triad close together, and a few sparks above them. Small and bright.
    out = blank(0.62)
    rng = random.Random(301)
    for index, frequency in enumerate((1046.5, 1318.5, 1568.0)):
        bell_into(out, index * 0.07, frequency, 0.8 + 0.1 * index, 0.22)
    for _ in range(6):
        grain_into(out, rng.uniform(0.12, 0.45), 0.015, 3500.0, 0.10, rng)
    return normalise(out, 0.42)


def made_reward() -> list:
    # A milestone: a warm rising arpeggio, a little lower and longer than the
    # chime. Replaces a chord that *fell* -- the old 'finish' went down for
    # every good thing.
    out = blank(0.66)
    for index, frequency in enumerate((784.0, 988.0, 1175.0)):
        bell_into(out, index * 0.06, frequency, 0.7 + 0.1 * index, 0.30)
    return normalise(out, 0.42)


def made_warning() -> list:
    # Dusk, and warmth running out. Two notes stepping down, soft -- a reminder,
    # not an alarm. The old one was a buzz at 146 Hz with noise in it.
    out = blank(0.62)
    bell_into(out, 0.0, 587.3, 0.8, 0.28)
    bell_into(out, 0.16, 440.0, 0.7, 0.32)
    return normalise(out, 0.40)


def made_frost() -> list:
    # Ice closing in: a few tiny crackles, once, when the cold gets worse.
    out = blank(0.28)
    rng = random.Random(401)
    for _ in range(7):
        grain_into(out, rng.uniform(0.0, 0.2), 0.012, 2000.0, rng.uniform(0.4, 1.0), rng)
    return normalise(out, 0.30)


def made_whoomp() -> list:
    # Fuel catching in the fire: a soft rush of air through the middle, quick in
    # and slow out. Warm because it has no top and no bottom.
    out = blank(0.6)
    rng = random.Random(501)
    swell_into(out, 0.0, 0.6, (320.0, 900.0), 0.9, 1.0, rng)
    noise_into(out, 0.0, 0.25, 250.0, 1400.0, 0.5, rng, attack=0.02, decay=0.09)
    return normalise(out, 0.45)


def made_level() -> list:
    # The fire growing a size: the whoomp, and two warm notes rising out of it.
    out = blank(0.74)
    rng = random.Random(502)
    swell_into(out, 0.0, 0.55, (300.0, 1000.0), 0.9, 0.9, rng)
    bell_into(out, 0.14, 784.0, 0.55, 0.30)
    bell_into(out, 0.26, 1046.5, 0.6, 0.34)
    return normalise(out, 0.45)


def cue_tension() -> list:
    # The sky going dark. Air moving somewhere far, and two quiet high tones a
    # semitone apart -- the only thing wrong is how close they are.
    out = blank(3.8)
    rng = random.Random(601)
    swell_into(out, 0.0, 3.8, (500.0, 1100.0), 0.8, 0.6, rng)
    for frequency in (739.99, 783.99):
        for i in range(len(out)):
            u = i / len(out)
            out[i] += 0.06 * math.sin(2.0 * math.pi * frequency * i / RATE) * math.sin(math.pi * u) ** 2
    return normalise(out, 0.40)


def cue_impact() -> list:
    # The fleet passing over a city: one short blow and what falls after it.
    out = blank(1.3)
    rng = random.Random(602)
    thump_into(out, 0.0, 80.0, 45.0, 0.35, 1.0)
    noise_into(out, 0.0, 0.9, 250.0, 2500.0, 0.7, rng, decay=0.22)
    for _ in range(10):
        grain_into(out, rng.uniform(0.12, 1.0), 0.02, 1500.0, rng.uniform(0.1, 0.25), rng)
    return normalise(out, 0.60)


def cue_rise() -> list:
    # The last rocket lifting: air climbing, and four notes climbing with it.
    out = blank(3.3)
    rng = random.Random(603)
    swell_into(out, 0.0, 3.3, (300.0, 1600.0), 1.0, 0.55, rng)
    for index, frequency in enumerate((440.0, 523.25, 659.25, 880.0)):
        bell_into(out, 0.6 + index * 0.6, frequency, 0.45, 0.8)
    return normalise(out, 0.50)


def cue_blast() -> list:
    # The planet going, seen through a window: one muffled blow, short, and then
    # almost nothing -- the line under it says there was no sound.
    out = blank(2.4)
    rng = random.Random(604)
    thump_into(out, 0.0, 55.0, 35.0, 0.45, 0.8)
    noise_into(out, 0.0, 1.4, 60.0, 420.0, 1.0, rng, attack=0.02, decay=0.45)
    return normalise(out, 0.60)


def cue_alarm() -> list:
    # The cockpit waking her: three soft pairs of beeps, each quieter than the
    # last. The ice planet is what comes after them -- nearly silence.
    out = blank(2.6)
    for start, gain in ((0.0, 1.0), (0.9, 0.7), (1.8, 0.45)):
        for offset in (0.0, 0.18):
            first = int(RATE * (start + offset))
            length = int(RATE * 0.09)
            for i in range(length):
                u = i / length
                out[first + i] += gain * math.sin(2.0 * math.pi * 987.8 * i / RATE) * math.sin(math.pi * u)
    return normalise(out, 0.35)


def cue_crash() -> list:
    # Breaking apart in the ice cloud: a crunch, a blow under it, and ice falling.
    out = blank(2.0)
    rng = random.Random(605)
    thump_into(out, 0.0, 90.0, 50.0, 0.3, 0.7)
    noise_into(out, 0.0, 1.2, 400.0, 2800.0, 0.9, rng, decay=0.3)
    for _ in range(14):
        bell_into(out, rng.uniform(0.15, 1.6), rng.uniform(2000.0, 3800.0),
                  rng.uniform(0.15, 0.3), 0.06, partials=[(1.0, 1.0, 1.0)])
    return normalise(out, 0.60)


MADE = {
    "note": made_note, "chime": made_chime, "finish": made_reward,
    "alarm": made_warning, "frost": made_frost, "whoomp": made_whoomp,
    "level": made_level,
}
CUES = {
    "cue_tension": cue_tension, "cue_impact": cue_impact, "cue_rise": cue_rise,
    "cue_blast": cue_blast, "cue_alarm": cue_alarm, "cue_crash": cue_crash,
}


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
# Quality Pass 01: the wind is air above 170 Hz now and the cold is a gustier
# mid-range layer of it, so both cross hundreds to a few thousand times a second.
# The bounds still catch the two failures this check was written for -- a drone
# (under 250) and a hiss centred in the top octaves (over 4000).
BED_ZCR = {"wind": (250, 2500), "cold": (600, 4000)}


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
    for table, make in ((GUSTS, gust), (BREATHS, breath)):
        for name, spec in table.items():
            if args.only and args.only != name:
                continue
            write(OUT / f"{name}.wav", make(name, spec))
            print(f"{name:12s} {measure(OUT / f'{name}.wav')}")
    for table in (MADE, CUES):
        for name, make in table.items():
            if args.only and args.only != name:
                continue
            write(OUT / f"{name}.wav", make())
            print(f"{name:12s} {measure(OUT / f'{name}.wav')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
