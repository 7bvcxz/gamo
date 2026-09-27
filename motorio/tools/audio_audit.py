#!/usr/bin/env python3
"""Measures every sound the game ships and warns about the technical faults.

    python3 tools/audio_audit.py               # table + warnings, exit 1 on a fault
    python3 tools/audio_audit.py --markdown    # the same table as Markdown

It does not judge whether a sound is good. It catches the three things that
made the plateau tiring to listen to before 2026-09-27, all of which a number
can see and none of which a test that plays the file can:

  * an ambience whose energy lives below 150 Hz. The old wind bed had all of it
    there -- 60% below 100 Hz -- and under a twelve-minute day that is not wind,
    it is a drone pressing on the ear ("브금이라기보다 굉음").
  * a loop that does not close: the jump between its last sample and its first,
    which is a click every time round.
  * a peak above -1 dBFS, which clips once a mixer adds anything to it.

Standard library only, like build_sfx.py. WAV is read directly; OGG needs
`ffmpeg` on the PATH to decode, and is skipped with a note when it is not there.
The low-frequency share is measured with a second-order low-pass (an RBJ biquad)
rather than an FFT, which is all this needs and costs one pass over the samples.
"""

import argparse
import math
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
AUDIO_DIRS = [ROOT / "assets" / "sfx"]
RATE = 22050

# What each file is for. The category decides which rules apply: an ambience is
# judged on its low end and its seam, a one-shot on its length. Files not listed
# here are reported as "?" -- a sound nobody has placed is a finding in itself.
CATEGORY = {
    # Beds and loops.
    "wind": "ambient", "wind_air": "ambient", "wind_gust": "ambient",
    "cold": "ambient", "hearth": "ambient", "factory": "ambient", "purr": "ambient",
    # The one note the music is played from.
    "note": "music", "bell": "music",
    # Interface.
    "select": "ui", "confirm": "ui", "deny": "ui", "tick": "ui",
    # World events.
    "build": "sfx", "remove": "sfx", "deliver": "sfx", "alloy": "sfx",
    "alarm": "sfx", "finish": "sfx", "pop": "sfx", "chime": "sfx",
    "step": "sfx", "step_run": "sfx", "pick": "sfx", "nibble": "sfx",
    "meow": "sfx", "breath": "sfx", "frost": "sfx", "whoomp": "sfx", "level": "sfx",
    # Weather one-shots: judged on their low end like the beds, but they are
    # seconds long by design.
    "gust": "weather",
    # Recorded (CC0) and the machine loop.
    "cat": "sfx", "clink": "sfx", "latch": "sfx", "creak": "sfx", "rustle": "sfx",
    "hum": "loop",
    # The opening's cues and other single events: low end allowed -- an impact
    # is the one place it belongs -- and no length limit.
    "cue": "event",
}
LOOPS = {"wind", "wind_air", "cold", "hearth", "factory", "hum", "purr"}

# Limits. Loose on purpose: these are alarms for faults, not a style guide.
PEAK_LIMIT_DB = -1.0
AMBIENT_LOW_SHARE = 0.35       # of the energy below 150 Hz
AMBIENT_SUB_SHARE = 0.15       # of the energy below 100 Hz
SEAM_LIMIT = 0.08              # a jump this large (of full scale) clicks
ONE_SHOT_LONGEST = 1.6         # seconds; longer than this is not a one-shot


def category_of(path: Path) -> str:
    stem = path.stem
    if stem in CATEGORY:
        return CATEGORY[stem]
    # Variations are named <sound>_<n>: pick_1, pick_2 ...
    base = stem.rsplit("_", 1)[0]
    if stem.rsplit("_", 1)[-1].isdigit() and base in CATEGORY:
        return CATEGORY[base]
    if stem.split("_", 1)[0] in CATEGORY:
        return CATEGORY[stem.split("_", 1)[0]]
    if base.rsplit("_", 1)[-1].isdigit():
        return CATEGORY.get(base.rsplit("_", 1)[0], "?")
    return "?"


def read_wav(path: Path):
    with wave.open(str(path)) as handle:
        frames = handle.getnframes()
        rate = handle.getframerate()
        channels = handle.getnchannels()
        width = handle.getsampwidth()
        raw = handle.readframes(frames)
    if width != 2:
        raise ValueError(f"{width * 8}-bit PCM")
    data = struct.unpack("<%dh" % (len(raw) // 2), raw)
    if channels > 1:
        data = [sum(data[i:i + channels]) / channels for i in range(0, len(data), channels)]
    return [v / 32768.0 for v in data], rate, channels


def read_ogg(path: Path):
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        return None
    out = subprocess.run([ffmpeg, "-v", "quiet", "-i", str(path), "-f", "s16le",
                          "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True)
    data = struct.unpack("<%dh" % (len(out.stdout) // 2), out.stdout)
    channels = 1
    return [v / 32768.0 for v in data], RATE, channels


def lowpass_share(samples, rate, cutoff):
    """Share of the energy below `cutoff`, through an RBJ low-pass biquad."""
    w0 = 2.0 * math.pi * cutoff / rate
    alpha = math.sin(w0) / (2.0 * 0.7071)
    cos_w0 = math.cos(w0)
    b0 = (1.0 - cos_w0) / 2.0
    b1 = 1.0 - cos_w0
    b2 = b0
    a0 = 1.0 + alpha
    a1 = -2.0 * cos_w0
    a2 = 1.0 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    low = 0.0
    total = 0.0
    for x in samples:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x
        y2, y1 = y1, y
        low += y * y
        total += x * x
    return low / total if total > 0.0 else 0.0


def db(value: float) -> float:
    return 20.0 * math.log10(value) if value > 1e-9 else -180.0


def measure(path: Path):
    if path.suffix == ".wav":
        samples, rate, channels = read_wav(path)
    else:
        decoded = read_ogg(path)
        if decoded is None:
            return None
        samples, rate, channels = decoded
    if not samples:
        return None
    peak = max(abs(v) for v in samples)
    rms = math.sqrt(sum(v * v for v in samples) / len(samples))
    return {
        "name": path.stem,
        "path": str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
        "format": path.suffix[1:],
        "seconds": len(samples) / rate,
        "rate": rate,
        "channels": channels,
        "peak_db": db(peak),
        "rms_db": db(rms),
        "low150": lowpass_share(samples, rate, 150.0),
        "low100": lowpass_share(samples, rate, 100.0),
        "seam": abs(samples[-1] - samples[0]),
        "category": category_of(path),
    }


def faults(row) -> list:
    out = []
    if row["peak_db"] > PEAK_LIMIT_DB:
        out.append(f"peak {row['peak_db']:.1f} dBFS > {PEAK_LIMIT_DB}")
    if row["category"] in ("ambient", "weather"):
        if row["low150"] > AMBIENT_LOW_SHARE:
            out.append(f"ambient low end {row['low150'] * 100:.0f}% below 150 Hz")
        if row["low100"] > AMBIENT_SUB_SHARE:
            out.append(f"ambient sub {row['low100'] * 100:.0f}% below 100 Hz")
    if row["name"] in LOOPS and row["seam"] > SEAM_LIMIT:
        out.append(f"loop seam jump {row['seam']:.3f}")
    if row["category"] in ("sfx", "ui") and row["seconds"] > ONE_SHOT_LONGEST:
        out.append(f"one-shot is {row['seconds']:.2f}s")
    if row["category"] == "?":
        out.append("no category (unplaced sound)")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--markdown", action="store_true", help="print a Markdown table")
    parser.add_argument("paths", nargs="*", help="files to measure (default: every sound)")
    args = parser.parse_args()

    files = [Path(p).resolve() for p in args.paths]
    if not files:
        for folder in AUDIO_DIRS:
            files += sorted(p for p in folder.rglob("*") if p.suffix in (".wav", ".ogg"))
    rows = []
    skipped = []
    for path in files:
        row = measure(path)
        if row is None:
            skipped.append(path)
            continue
        row["faults"] = faults(row)
        rows.append(row)

    if args.markdown:
        print("| file | cat | fmt | s | Hz | ch | peak dBFS | RMS dBFS | <150 Hz | <100 Hz | faults |")
        print("|---|---|---|---|---|---|---|---|---|---|---|")
        for r in rows:
            print(f"| `{r['path']}` | {r['category']} | {r['format']} | {r['seconds']:.2f} | "
                  f"{r['rate']} | {r['channels']} | {r['peak_db']:.1f} | {r['rms_db']:.1f} | "
                  f"{r['low150'] * 100:.0f}% | {r['low100'] * 100:.0f}% | "
                  f"{'; '.join(r['faults']) or '-'} |")
    else:
        for r in rows:
            print(f"{r['path']:44s} {r['category']:8s} {r['seconds']:6.2f}s {r['rate']}Hz "
                  f"peak {r['peak_db']:6.1f} rms {r['rms_db']:6.1f}  "
                  f"<150 {r['low150'] * 100:3.0f}%  <100 {r['low100'] * 100:3.0f}%")
    for path in skipped:
        print(f"AUDIO_AUDIT: skipped {path} (no decoder)", file=sys.stderr)
    bad = [r for r in rows if r["faults"]]
    for r in bad:
        print(f"AUDIO_AUDIT: WARN {r['path']}: {'; '.join(r['faults'])}", file=sys.stderr)
    print(f"AUDIO_AUDIT: {len(rows)} files, {len(bad)} with faults", file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
