#!/usr/bin/env python3
"""Builds every sound Popcorn & Glory plays, from the numbers below.

    python3 popcorn-glory/tools/build_audio.py           # write assets/audio/*.ogg
    python3 popcorn-glory/tools/build_audio.py --check   # print length/peak of what is there

Everything is synthesised here -- no recordings, no third-party samples,
nothing to license -- and encoded to Ogg Vorbis with ffmpeg (Godot plays Ogg
natively on the web). The .ogg files are committed, so a fresh clone runs
without ffmpeg; this script is how they are made again. Standard library only,
fixed seeds: the same numbers make the same samples (momonium's
tools/audio/build_audio.py is the pattern).
"""
import argparse
import math
import random
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


def env(n, attack, decay_pow=2.0):
    a = max(1, int(attack * SR))
    return [min(1.0, i / a) * (1.0 - i / n) ** decay_pow for i in range(n)]


def lowpass(xs, k):
    out, y = [], 0.0
    for x in xs:
        y += k * (x - y)
        out.append(y)
    return out


def tone(f0, f1, dur, attack=0.004, decay_pow=2.5, shape="sine"):
    n = int(dur * SR)
    e = env(n, attack, decay_pow)
    out, ph = [], 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        ph += 2 * math.pi * f / SR
        v = math.sin(ph) if shape == "sine" else (1.0 if math.sin(ph) > 0 else -1.0) * 0.4
        out.append(v * e[i])
    return out


def noise(dur, seed, attack=0.002, decay_pow=3.0, lp=0.5):
    rng = random.Random(seed)
    n = int(dur * SR)
    e = env(n, attack, decay_pow)
    return [v * e[i] for i, v in enumerate(lowpass([rng.uniform(-1, 1) for _ in range(n)], lp))]


def mix(*parts, gains=None):
    n = max(len(p) for p in parts)
    gains = gains or [1.0] * len(parts)
    return [sum(g * (p[i] if i < len(p) else 0.0) for p, g in zip(parts, gains)) for i in range(n)]


def at(xs, offset):
    return [0.0] * int(offset * SR) + xs


def bell(freq, dur):
    # A bell: a fundamental and two inharmonic partials, each decaying.
    return mix(tone(freq, freq, dur, 0.002, 3), tone(freq * 2.76, freq * 2.76, dur * 0.6, 0.002, 4),
               tone(freq * 5.4, freq * 5.4, dur * 0.3, 0.001, 5), gains=[1.0, 0.35, 0.15])


def normalise(xs, peak):
    m = max(1e-9, max(abs(x) for x in xs))
    return [x * peak / m for x in xs]


def pop(seed, f):
    # A kernel bursting: a click of noise and a quick downward 'pok'.
    return mix(noise(0.05, seed, 0.001, 4, 0.7), tone(f, f * 0.45, 0.09, 0.001, 3), gains=[0.8, 0.9])


def loop_noise(dur, seed, lp, wobble):
    # A seamless loop: the last 0.2 s fades into the first.
    rng = random.Random(seed)
    n = int(dur * SR)
    xs = lowpass([rng.uniform(-1, 1) for _ in range(n)], lp)
    xs = [x * (0.75 + 0.25 * math.sin(2 * math.pi * wobble * i / n)) for i, x in enumerate(xs)]
    f = int(0.2 * SR)
    for i in range(f):
        k = i / f
        xs[i] = xs[i] * k + xs[n - f + i] * (1 - k)
    return xs[: n - f]


def crackle(dur, seed, count):
    rng = random.Random(seed)
    out = [0.0] * int(dur * SR)
    for _ in range(count):
        t = rng.uniform(0, dur - 0.1)
        p = pop(rng.randint(0, 10_000), rng.uniform(500, 1100))
        o = int(t * SR)
        g = rng.uniform(0.3, 1.0) * (1 - t / dur) ** 0.5
        for i, v in enumerate(p):
            if o + i < len(out):
                out[o + i] += v * g
    return out


SOUNDS = {
    "pop_1": lambda: normalise(pop(1, 900), 0.8),
    "pop_2": lambda: normalise(pop(2, 760), 0.8),
    "pop_3": lambda: normalise(pop(3, 1050), 0.8),
    "coin": lambda: normalise(mix(bell(1318.5, 0.12), at(bell(1975.5, 0.18), 0.06)), 0.55),
    "upgrade": lambda: normalise(mix(*[at(bell(f, 0.5), 0.07 * i) for i, f in enumerate([523.3, 659.3, 784.0, 1046.5])]), 0.7),
    "sizzle": lambda: normalise(loop_noise(1.2, 7, 0.35, 3.0), 0.35),
    "ding": lambda: normalise(mix(bell(1046.5, 0.6), bell(1318.5, 0.6), bell(1568.0, 0.6)), 0.75),
    "thud": lambda: normalise(mix(tone(160, 70, 0.16, 0.002, 2.5), noise(0.08, 5, 0.001, 3, 0.15)), 0.7),
    "hiss": lambda: normalise(mix(noise(0.6, 9, 0.02, 1.5, 0.25), tone(110, 90, 0.4, 0.01, 2, "square")), 0.6),
    "clink": lambda: normalise(mix(tone(1800, 1700, 0.07, 0.001, 4), noise(0.02, 11, 0.001, 3, 0.9)), 0.6),
    "boom": lambda: normalise(mix(tone(90, 40, 0.7, 0.003, 2), noise(0.6, 13, 0.002, 2.5, 0.08)), 0.85),
    "crackle": lambda: normalise(crackle(1.4, 17, 38), 0.6),
    # The rare milestone (a new machine look): a rising run and a held chord.
    "fanfare": lambda: normalise(mix(*[at(bell(f, 0.35), 0.06 * i) for i, f in enumerate([523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0])],
                                    at(mix(bell(1046.5, 1.2), bell(1318.5, 1.2), bell(1568.0, 1.2), bell(2093.0, 1.0)), 0.36)), 0.8),
}


def write_ogg(name, xs):
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / f"{name}.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in xs))
        dst = OUT / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4", str(dst)], check=True)
    return dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if args.check:
        for name in SOUNDS:
            p = OUT / f"{name}.ogg"
            out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(p)], capture_output=True, text=True)
            print(f"{name:8s} {out.stdout.strip() or 'MISSING'} s")
        return
    for name, make in SOUNDS.items():
        xs = make()
        dst = write_ogg(name, xs)
        print(f"{name:8s} {len(xs) / SR:.2f} s peak {max(abs(x) for x in xs):.2f} -> {dst.name} ({dst.stat().st_size} bytes)")


if __name__ == "__main__":
    sys.exit(main())
