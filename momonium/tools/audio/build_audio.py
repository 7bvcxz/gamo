#!/usr/bin/env python3
"""Builds every sound Momonium plays, from the numbers below.

    python3 momonium/tools/audio/build_audio.py           # write assets/audio/*.ogg
    python3 momonium/tools/audio/build_audio.py --check   # print length/peak of what is there

Everything is synthesised here -- no recordings, no third-party samples, so
there is nothing to license -- and encoded to Ogg Vorbis with ffmpeg (small
enough for phones; Godot plays Ogg natively, also offline). The .ogg files are
committed: a fresh clone runs without ffmpeg; this script is how they are made
again or adjusted.

Loops are made to loop: notes that ring past the end wrap round to the start,
and noise beds fade their last half second into their first, so no seam clicks.
Standard library only.
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

RATE = 22050
HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / "assets" / "audio"


def note(name: str) -> float:
    """'C5' -> Hz (A4 = 440)."""
    steps = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    return 440.0 * 2 ** ((steps[name[0]] + 12 * (int(name[-1]) - 4)) / 12.0)


def empty(seconds: float) -> list:
    return [0.0] * int(round(seconds * RATE))


def add(buf: list, start: float, samples: list, wrap: bool = False) -> None:
    i0 = int(round(start * RATE))
    n = len(buf)
    for i, s in enumerate(samples):
        j = i0 + i
        if j >= n:
            if not wrap:
                break
            j %= n
        buf[j] += s


def tone(freq: float, seconds: float, amp: float, attack: float = 0.01, decay: float = 4.0,
         partials=((1.0, 1.0),), vibrato: float = 0.0) -> list:
    out = []
    n = int(seconds * RATE)
    phase = [0.0] * len(partials)
    for i in range(n):
        t = i / RATE
        env = min(t / attack, 1.0) * math.exp(-decay * t)
        f = freq * (1.0 + vibrato * math.sin(2 * math.pi * 5.5 * t))
        v = 0.0
        for k, (mult, gain) in enumerate(partials):
            phase[k] += 2 * math.pi * f * mult / RATE
            v += gain * math.sin(phase[k])
        out.append(amp * env * v)
    return out


def glide(f0: float, f1: float, seconds: float, amp: float, decay: float = 6.0) -> list:
    out = []
    n = int(seconds * RATE)
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * (t / seconds)
        ph += 2 * math.pi * f / RATE
        out.append(amp * min(t / 0.005, 1.0) * math.exp(-decay * t) * math.sin(ph))
    return out


def noise(seconds: float, amp: float, rng: random.Random, lowpass: float = 0.1, decay: float = 0.0) -> list:
    out = []
    y = 0.0
    for i in range(int(seconds * RATE)):
        y += lowpass * (rng.uniform(-1, 1) - y)
        out.append(amp * y * math.exp(-decay * i / RATE))
    return out


def crossfade_loop(buf: list, fade: float = 0.5) -> list:
    """A bed made `fade` s longer than its loop: its tail is faded into its head."""
    f = int(fade * RATE)
    body = buf[:-f]
    for i in range(f):
        k = i / f
        body[i] = body[i] * k + buf[len(buf) - f + i] * (1.0 - k)
    return body


def normalise(buf: list, peak: float) -> list:
    m = max(1e-9, max(abs(x) for x in buf))
    return [x * peak / m for x in buf]


# --- music ------------------------------------------------------------------------

def music() -> list:
    """Calm: 72 bpm, eight bars of C - Am - F - G, a soft pad, a round bass, and
    pentatonic plucks chosen by a seeded hand. 26.7 s, loops seamlessly."""
    rng = random.Random(7)
    beat = 60.0 / 72.0
    bars = 8
    buf = empty(bars * 4 * beat)
    chords = [["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"]]
    roots = ["C3", "A2", "F2", "G2"]
    scale = ["C5", "D5", "E5", "G5", "A5", "C6"]
    for bar in range(bars):
        t0 = bar * 4 * beat
        chord = chords[bar % 4]
        for n in chord:
            add(buf, t0, tone(note(n), 4 * beat + 1.5, 0.05, attack=0.6, decay=0.6, partials=((1, 1), (2, 0.25))), wrap=True)
        for b in (0, 2):
            add(buf, t0 + b * beat, tone(note(roots[bar % 4]), 1.6, 0.12, attack=0.02, decay=2.2, partials=((1, 1), (2, 0.15))), wrap=True)
        for s in range(8):
            if rng.random() < 0.55:
                n = rng.choice(scale)
                add(buf, t0 + s * beat / 2, tone(note(n), 1.4, 0.06, attack=0.004, decay=3.5, partials=((1, 1), (2, 0.35), (3, 0.1))), wrap=True)
    return normalise(buf, 0.6)


# --- ambience beds ------------------------------------------------------------------

def ocean() -> list:
    rng = random.Random(11)
    seconds = 12.0
    raw = noise(seconds + 0.5, 1.0, rng, lowpass=0.06)
    out = []
    for i, x in enumerate(raw):
        t = i / RATE
        swell = 0.55 + 0.45 * math.sin(2 * math.pi * t / 6.0) ** 2
        out.append(x * swell)
    return normalise(crossfade_loop(out), 0.55)


def wind() -> list:
    rng = random.Random(13)
    seconds = 15.0
    raw = noise(seconds + 0.5, 1.0, rng, lowpass=0.02)
    hp = 0.0
    out = []
    for i, x in enumerate(raw):
        t = i / RATE
        hp = x - 0.995 * hp
        gust = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 7.5)) * (0.5 + 0.5 * math.sin(2 * math.pi * t / 5.0 + 1.0))
        out.append(x * gust)
    return normalise(crossfade_loop(out), 0.45)


def crickets() -> list:
    rng = random.Random(17)
    buf = empty(8.0)
    for voice, (freq, gap) in enumerate([(4600.0, 0.93), (4100.0, 1.27)]):
        t = rng.uniform(0, 0.4)
        while t < 8.0:
            for p in range(3):
                add(buf, t + p * 0.045, tone(freq, 0.03, 0.12, attack=0.003, decay=60.0), wrap=True)
            t += gap + rng.uniform(-0.08, 0.08)
    return normalise(buf, 0.35)


def industry() -> list:
    rng = random.Random(19)
    seconds = 6.0
    buf = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        buf.append(0.08 * math.sin(2 * math.pi * 55 * t) + 0.05 * math.sin(2 * math.pi * 110 * t) * (0.8 + 0.2 * math.sin(2 * math.pi * t / 3.0)))
    for k in range(4):
        add(buf, k * 1.5 + rng.uniform(0, 0.2), tone(880, 0.35, 0.12, attack=0.002, decay=12.0, partials=((1, 1), (1.52, 0.6), (2.7, 0.3))), wrap=True)
    return normalise(buf, 0.4)


# --- one-shots ----------------------------------------------------------------------

def sfx() -> dict:
    rng = random.Random(23)
    bell = ((1, 1), (2, 0.4), (3, 0.15))
    out = {}
    out["click"] = tone(1800, 0.05, 0.4, attack=0.001, decay=90.0)
    b = empty(0.35)
    for t in (0.0, 0.14):
        add(b, t, tone(170, 0.18, 0.6, attack=0.002, decay=22.0, partials=((1, 1), (2.3, 0.3))))
        add(b, t, noise(0.06, 0.25, rng, lowpass=0.3, decay=40.0))
    out["build"] = b
    d = empty(0.9)
    add(d, 0.0, tone(note("G5"), 0.8, 0.35, attack=0.004, decay=5.0, partials=bell))
    add(d, 0.12, tone(note("C6"), 0.75, 0.35, attack=0.004, decay=5.0, partials=bell))
    out["built"] = d
    h = empty(0.5)
    add(h, 0.0, glide(300, 720, 0.08, 0.5, decay=10.0))
    for k, f in enumerate((2200, 2800, 3300)):
        add(h, 0.06 + k * 0.05, tone(f, 0.25, 0.12, attack=0.002, decay=14.0))
    out["harvest"] = h
    r = empty(1.0)
    for k, n in enumerate(("C6", "E6", "G6")):
        add(r, k * 0.11, tone(note(n), 0.8, 0.3, attack=0.003, decay=4.5, partials=bell))
    out["research"] = r
    l = empty(0.7)
    swish = noise(0.18, 0.4, rng, lowpass=0.5, decay=14.0)
    add(l, 0.0, swish)
    add(l, 0.12, tone(note("E6"), 0.5, 0.25, attack=0.004, decay=6.0, partials=bell))
    out["letter"] = l
    out["momo"] = glide(620, 1150, 0.14, 0.45, decay=12.0)
    c = empty(0.35)
    add(c, 0.0, tone(note("B5"), 0.12, 0.3, attack=0.002, decay=18.0, partials=((1, 1), (3, 0.2))))
    add(c, 0.07, tone(note("E6"), 0.25, 0.3, attack=0.002, decay=10.0, partials=((1, 1), (3, 0.2))))
    out["coin"] = c
    w = empty(0.8)
    add(w, 0.0, noise(0.5, 0.5, rng, lowpass=0.08, decay=6.0))
    add(w, 0.1, glide(400, 900, 0.4, 0.2, decay=6.0))
    out["land"] = w
    f = empty(1.4)
    for k, n in enumerate(("C5", "E5", "G5", "C6")):
        add(f, k * 0.13, tone(note(n), 1.0 if k == 3 else 0.4, 0.3, attack=0.004, decay=3.0 if k == 3 else 8.0, partials=bell))
    out["promote"] = f
    dm = empty(0.6)
    add(dm, 0.0, tone(90, 0.3, 0.6, attack=0.003, decay=14.0))
    add(dm, 0.02, noise(0.5, 0.3, rng, lowpass=0.15, decay=8.0))
    out["demolish"] = dm
    out["refuse"] = glide(330, 220, 0.16, 0.35, decay=14.0)
    # Step 68: the light taps of work in progress, one on each strike of a
    # Momo's tool (played quietly, a few a second at most), and the THUNK
    # that ends a job: a low drop, a soft thud and a small bell over it.
    tp = empty(0.1)
    add(tp, 0.0, tone(2600, 0.08, 0.5, attack=0.0008, decay=48.0, partials=((1, 1), (2.7, 0.35), (4.1, 0.15))))
    add(tp, 0.0, noise(0.02, 0.35, rng, lowpass=0.6, decay=120.0))
    out["tap_pick"] = tp
    tw = empty(0.12)
    add(tw, 0.0, tone(420, 0.1, 0.6, attack=0.001, decay=38.0, partials=((1, 1), (2.2, 0.4))))
    add(tw, 0.0, noise(0.05, 0.4, rng, lowpass=0.25, decay=60.0))
    out["tap_wood"] = tw
    tm = empty(0.22)
    add(tm, 0.0, tone(3150, 0.2, 0.45, attack=0.0008, decay=22.0, partials=((1, 1), (1.48, 0.5), (2.9, 0.2))))
    add(tm, 0.0, noise(0.015, 0.3, rng, lowpass=0.7, decay=150.0))
    out["tap_metal"] = tm
    ta = empty(0.24)
    add(ta, 0.0, noise(0.22, 0.4, rng, lowpass=0.3, decay=12.0))
    for k in range(4):
        add(ta, 0.02 + k * 0.045, tone(1500 + rng.random() * 1100, 0.05, 0.12, attack=0.002, decay=60.0))
    out["tap_water"] = ta
    out["tap_soft"] = noise(0.09, 0.5, rng, lowpass=0.18, decay=30.0)
    th = empty(0.45)
    add(th, 0.0, glide(150, 62, 0.22, 0.8, decay=9.0))
    add(th, 0.0, noise(0.06, 0.45, rng, lowpass=0.12, decay=45.0))
    add(th, 0.05, tone(note("C6"), 0.35, 0.16, attack=0.003, decay=10.0, partials=bell))
    out["thunk"] = th
    return {k: normalise(v, 0.5) for k, v in out.items()}


def write_ogg(name: str, samples: list, quality: int) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / (name + ".wav")
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
        dst = OUT / (name + ".ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", str(quality), "-map_metadata", "-1", str(dst)], check=True)
    return dst


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--only", default="", help="comma-separated names to (re)write, e.g. sfx_thunk,sfx_tap_pick")
    args = ap.parse_args()
    only = set(n for n in args.only.split(",") if n)
    if args.check:
        for p in sorted(OUT.glob("*.ogg")):
            print(f"{p.name:24s} {p.stat().st_size / 1024:7.1f} KB")
        return 0
    tracks = {"music_calm": (music(), 3), "amb_ocean": (ocean(), 2), "amb_wind": (wind(), 2), "amb_crickets": (crickets(), 2), "amb_industry": (industry(), 2)}
    for name, (buf, q) in tracks.items():
        if only and name not in only:
            continue
        p = write_ogg(name, buf, q)
        print(f"{p.name:24s} {len(buf) / RATE:6.2f} s  {p.stat().st_size / 1024:7.1f} KB")
    for name, buf in sfx().items():
        if only and "sfx_" + name not in only:
            continue
        p = write_ogg("sfx_" + name, buf, 3)
        print(f"{p.name:24s} {len(buf) / RATE:6.2f} s  {p.stat().st_size / 1024:7.1f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
