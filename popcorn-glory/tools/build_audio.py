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


# ---- Step 43: the factory's sound grammar (design/SOUND.md) ---------------------------------
# One sound per meaning. The A/B/C experiments keep the sounds above, as they were compared;
# the factory speaks with these. Loops are seamless: their length holds whole cycles of every
# tone, or their tail is crossfaded into their head.


def seamless(xs, fade_s):
    f = int(fade_s * SR)
    n = len(xs)
    out = xs[: n - f]
    for i in range(f):
        k = i / f
        out[i] = out[i] * k + xs[n - f + i] * (1 - k)
    return out


def bandnoise(dur, seed, hi, lo):
    # Noise between two one-pole filters: lowpass(hi) minus lowpass(lo).
    rng = random.Random(seed)
    xs = [rng.uniform(-1, 1) for _ in range(int(dur * SR))]
    a, b = lowpass(xs, hi), lowpass(xs, lo)
    return [x - y for x, y in zip(a, b)]


def add_at(out, xs, t, g=1.0):
    o = int(t * SR)
    for i, v in enumerate(xs):
        if 0 <= o + i < len(out):
            out[o + i] += v * g


def sines(freqs, dur, gains, trem_hz=0.0, trem=0.0):
    n = int(dur * SR)
    return [sum(g * math.sin(2 * math.pi * f * i / SR) for f, g in zip(freqs, gains)) *
            (1.0 - trem + trem * math.sin(2 * math.pi * trem_hz * i / SR)) for i in range(n)]


def heat_loop():
    # The factory kettle warming: a soft low rush and small bubbles, no bright hiss.
    rng = random.Random(43)
    xs = [v * 0.5 for v in lowpass([rng.uniform(-1, 1) for _ in range(int(2.25 * SR))], 0.06)]
    for _ in range(30):
        add_at(xs, tone(rng.uniform(260, 520), rng.uniform(180, 300), 0.035, 0.002, 3), rng.uniform(0, 2.2), rng.uniform(0.15, 0.35))
    return seamless(xs, 0.25)


def rise_loop():
    # The anticipation pad under the heat; the game raises its pitch with the heat (0.75 -> 1.5).
    # Every tone fits whole cycles in 2 s, the tremolo too.
    return sines([220.0, 275.0, 330.0, 440.0], 2.0, [0.5, 0.25, 0.3, 0.18], trem_hz=3.0, trem=0.25)


def perfect():
    # The hand's Perfect Pop: one file, so one voice -- a sharp click, a bright 'pok', a gold ring.
    return mix(noise(0.004, 31, 0.0005, 2, 0.95), tone(1200, 520, 0.07, 0.001, 3),
               at(mix(bell(1568.0, 0.5), bell(2093.0, 0.45), bell(2637.0, 0.3), gains=[0.6, 0.5, 0.3]), 0.012),
               gains=[0.9, 0.8, 0.5])


def mpop():
    # A machine's own pop: duller and smaller than the hand's.
    return mix(noise(0.04, 33, 0.001, 4, 0.35), tone(600, 300, 0.07, 0.001, 3), gains=[0.6, 0.9])


def bloom():
    xs = crackle(0.8, 35, 24)
    return mix(xs, at(bell(1318.5, 0.6), 0.02), at(bell(1760.0, 0.5), 0.1), gains=[1.0, 0.35, 0.3])


def fountain():
    # The crescendo's top: a low boom, a shower of pops that thickens and thins, a rising shimmer.
    rng = random.Random(37)
    out = [0.0] * int(2.2 * SR)
    for _ in range(70):
        t = 2.0 * (rng.random() ** 0.8) * rng.random() ** 0.3
        add_at(out, pop(rng.randint(0, 10_000), rng.uniform(600, 1300)), t, rng.uniform(0.25, 0.8) * (1 - t / 2.2))
    add_at(out, tone(90, 45, 0.6, 0.003, 2), 0.0, 0.9)
    add_at(out, tone(800, 1600, 1.4, 0.3, 1.5), 0.1, 0.12)
    return out


def belt_loop():
    # Belt rollers: a low rumble and sixteen soft clacks a loop, accents alternating.
    rng = random.Random(39)
    xs = [v * 0.55 for v in lowpass([rng.uniform(-1, 1) for _ in range(int(2.0 * SR))], 0.05)]
    for i in range(16):
        g = (1.0 if i % 2 == 0 else 0.6) * rng.uniform(0.85, 1.0)
        add_at(xs, mix(noise(0.004, 100 + i, 0.0005, 3, 0.6), tone(900, 700, 0.012, 0.001, 3)), i * 0.125, g * 0.6)
    return seamless(xs + xs[: int(0.2 * SR)], 0.2)


def hum_loop():
    # The kitchen's machines: a warm motor hum (whole cycles in 4 s) and a slow breath.
    rng = random.Random(41)
    h = sines([110.0, 220.0, 330.0, 55.0], 4.0, [0.5, 0.25, 0.12, 0.3], trem_hz=0.5, trem=0.2)
    bub = lowpass([rng.uniform(-1, 1) for _ in range(len(h) + int(0.3 * SR))], 0.04)
    bub = seamless(bub, 0.3)
    return [a + 0.35 * b for a, b in zip(h, bub)]


def chug_loop():
    # The industrial rhythm, at 100 a minute: a thump on one and three, a 'chk' on two and four,
    # light ticks between (2.4 s = four beats, so it loops on the beat).
    out = [0.0] * int(2.4 * SR)
    for b in range(4):
        t = b * 0.6
        if b % 2 == 0:
            add_at(out, tone(120, 60, 0.14, 0.002, 2.5), t, 0.9)
        else:
            add_at(out, noise(0.06, 200 + b, 0.001, 2.5, 0.5), t, 0.5)
        add_at(out, noise(0.015, 300 + b, 0.0005, 3, 0.8), t + 0.3, 0.18)
    return out


def murmur_loop():
    # A small-town shop: six voices of band-limited noise talking in syllables, never words.
    rng = random.Random(45)
    dur = 6.4
    out = [0.0] * int(dur * SR)
    for v in range(6):
        hi, lo = rng.uniform(0.12, 0.2), rng.uniform(0.02, 0.04)
        src = bandnoise(dur, 500 + v, hi, lo)
        t = rng.uniform(0, 0.8)
        env_ = [0.0] * len(out)
        while t < dur - 0.4:
            d = rng.uniform(0.1, 0.28)
            n = int(d * SR)
            o = int(t * SR)
            g = rng.uniform(0.4, 1.0)
            for i in range(n):
                if o + i < len(env_):
                    env_[o + i] = g * math.sin(math.pi * i / n)
            t += d + (rng.uniform(0.03, 0.12) if rng.random() < 0.75 else rng.uniform(0.4, 1.2))
        for i in range(len(out)):
            out[i] += src[i] * env_[i]
    return seamless(out, 0.4)


def patter():
    # A kernel landing in the bag: a tick and a little paper body (60 ms).
    return mix(noise(0.02, 51, 0.0005, 3, 0.5), tone(2200, 1800, 0.02, 0.001, 3), noise(0.06, 52, 0.002, 2.5, 0.15), gains=[0.6, 0.4, 0.35])


def coat():
    # A swish: noise through a filter that opens and closes.
    rng = random.Random(53)
    n = int(0.5 * SR)
    out, y = [], 0.0
    for i in range(n):
        t = i / n
        k = 0.04 + 0.36 * math.sin(math.pi * t) ** 2
        y += k * (rng.uniform(-1, 1) - y)
        out.append(y * math.sin(math.pi * min(1.0, t * 1.4)) ** 1.5)
    return out


def seal():
    rng = random.Random(55)
    out = [0.0] * int(0.28 * SR)
    for _ in range(8):
        add_at(out, noise(0.006, rng.randint(0, 9999), 0.0005, 3, 0.8), rng.uniform(0, 0.11), rng.uniform(0.3, 0.7))
    add_at(out, tone(200, 120, 0.08, 0.002, 2.5), 0.12, 0.9)
    return out


def serve():
    return mix(bell(2093.0, 0.8), bell(2637.0, 0.5), gains=[1.0, 0.4])


def door():
    return mix(bell(1760.0, 0.4), at(bell(1318.5, 0.5), 0.09), gains=[0.8, 0.8])


def cash():
    # The sale: the drawer's click, then two coins.
    return mix(tone(300, 200, 0.03, 0.001, 3), noise(0.02, 57, 0.0005, 3, 0.4), at(bell(2637.0, 0.16), 0.05), at(bell(3136.0, 0.22), 0.11),
               gains=[0.5, 0.4, 0.8, 0.8])


def news():
    def soft(f, dur):
        n = int(dur * SR)
        return [math.sin(2 * math.pi * f * i / SR + 0.02 * math.sin(2 * math.pi * 6 * i / SR)) * min(1.0, i / (0.01 * SR)) * (1 - i / n) ** 2 for i in range(n)]
    return mix(soft(1318.5, 0.22), at(soft(1760.0, 0.33), 0.12))


def reveal():
    run = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3, 2637.0]
    notes = mix(*[at(bell(f, 0.3), 0.05 * i) for i, f in enumerate(run)])
    n = int(1.4 * SR)
    pad = [sum(math.sin(2 * math.pi * f * i / SR) for f in (523.3, 659.3, 784.0)) / 3 * min(1.0, i / (0.3 * SR)) * (1 - i / n) ** 1.5 for i in range(n)]
    return mix(notes, at(pad, 0.2), gains=[0.6, 0.6])


def win():
    # A small brass band: a pickup run and a held chord with vibrato, a soft cymbal swell.
    def brass(f, dur, vib=0.0):
        n = int(dur * SR)
        out, ph = [], 0.0
        for i in range(n):
            ph += 2 * math.pi * f * (1 + vib * math.sin(2 * math.pi * 5.5 * i / SR)) / SR
            v = sum(math.sin(ph * h) / h for h in range(1, 7))
            out.append(v * min(1.0, i / (0.02 * SR)) * (1 - i / n) ** 1.2)
        return lowpass(out, 0.3)
    run = mix(*[at(brass(f, 0.16), 0.13 * i) for i, f in enumerate([392.0, 523.3, 659.3, 784.0])])
    chord = mix(brass(523.3, 1.2, 0.006), brass(659.3, 1.2, 0.006), brass(784.0, 1.2, 0.006))
    swell = noise(1.0, 59, 0.6, 1.5, 0.9)
    return mix(run, at(chord, 0.52), at(swell, 0.3), gains=[0.8, 0.6, 0.12])


GRAMMAR = {
    "heat": lambda: normalise(heat_loop(), 0.35),
    "rise": lambda: normalise(rise_loop(), 0.3),
    "perfect": lambda: normalise(perfect(), 0.85),
    "mpop": lambda: normalise(mpop(), 0.6),
    "bloom": lambda: normalise(bloom(), 0.75),
    "fountain": lambda: normalise(fountain(), 0.8),
    "belt": lambda: normalise(belt_loop(), 0.4),
    "hum": lambda: normalise(hum_loop(), 0.35),
    "chug": lambda: normalise(chug_loop(), 0.45),
    "murmur": lambda: normalise(murmur_loop(), 0.35),
    "patter": lambda: normalise(patter(), 0.45),
    "coat": lambda: normalise(coat(), 0.5),
    "seal": lambda: normalise(seal(), 0.55),
    "serve": lambda: normalise(serve(), 0.6),
    "door": lambda: normalise(door(), 0.45),
    "cash": lambda: normalise(cash(), 0.6),
    "news": lambda: normalise(news(), 0.55),
    "reveal": lambda: normalise(reveal(), 0.75),
    "win": lambda: normalise(win(), 0.8),
}
SOUNDS.update(GRAMMAR)


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
    ap.add_argument("--names", default="", help="comma-separated: write only these (the A/B/C files are kept byte for byte)")
    ap.add_argument("--wav", default="", help="also write each sound as a WAV into this folder (for listening and spectra)")
    args = ap.parse_args()
    if args.check:
        for name in SOUNDS:
            p = OUT / f"{name}.ogg"
            out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(p)], capture_output=True, text=True)
            print(f"{name:8s} {out.stdout.strip() or 'MISSING'} s")
        return
    only = [n for n in args.names.split(",") if n]
    for name, make in SOUNDS.items():
        if only and name not in only:
            continue
        xs = make()
        if args.wav:
            Path(args.wav).mkdir(parents=True, exist_ok=True)
            with wave.open(str(Path(args.wav) / f"{name}.wav"), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in xs))
        dst = write_ogg(name, xs)
        print(f"{name:8s} {len(xs) / SR:.2f} s peak {max(abs(x) for x in xs):.2f} -> {dst.name} ({dst.stat().st_size} bytes)")


if __name__ == "__main__":
    sys.exit(main())
