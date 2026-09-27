#!/usr/bin/env python3
"""Builds the game's recorded sounds from CC0 sources.

    python3 tools/build_cc0_sfx.py            # fetch, check the licence, write assets/sfx/cc0/*.wav
    python3 tools/build_cc0_sfx.py --only pick_1

Everything else the game hears is synthesised by build_sfx.py. A few things
cannot be: a pickaxe on stone, a boot in snow, a small piece of metal. Synthesis
got close enough to name them and not close enough to want to hear them all day
-- the pickaxe was a falling low glide and the playtest called it "벽 때리는
소리". These are recordings, from packs whose licence is checked here, in the
file that ships inside each zip, before a single sample is used.

And they are *processed*, because the recordings are not the game's sound as
they come. Kenney's mining hits put 80-94% of their energy below 150 Hz: used as
they are they would be the same wall. So each source goes through the same
filters build_sfx.py uses (imported from it), is trimmed and faded, and written
as 22050 Hz mono 16-bit WAV like every other sound. The source files are not
kept in the repository -- this script and the URLs are how to get them again,
and assets/sfx/LICENSES.md records what came from where.

Needs `ffmpeg` to decode the OGG sources. Standard library otherwise.
"""

import argparse
import io
import math
import os
import shutil
import struct
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from build_sfx import Biquad, RATE, normalise, write, measure, noise_into, grain_into  # noqa: E402
import random  # noqa: E402

OUT = Path(os.environ.get("CC0_OUT", HERE.parent / "assets" / "sfx" / "cc0"))
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "motorio-cc0"

# The packs. The licence line is what must be in the zip's License.txt -- if it
# is not, nothing from that pack is written.
PACKS = {
    "impact": dict(
        url="https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
        title="Kenney Impact Sounds 1.0", licence="Creative Commons Zero, CC0"),
    "rpg": dict(
        url="https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
        title="Kenney RPG Audio", licence="Creative Commons Zero, CC0"),
}

# What is made, from what, and how.
#
#   pack/src   the pack and the file inside its Audio/ folder
#   hp / lp    high- and low-pass corners in Hz (two poles each, twice: 24 dB/oct)
#   pitch      a resample: 1.7 plays 1.7 times faster and higher
#   start/len  seconds kept, after the pitch change
#   peak       normalised peak, well under full scale -- levels are Audio.gd's job
SOUNDS = {
    # Pickaxe on stone. The thud is filtered out below 260 Hz; what is left is
    # the crack and the grit, which is the part that says "ore" and not "wall".
    # Five takes, one per source recording.
    #
    # With the thud gone the recording is nearly all crack (3-6 kHz) and almost
    # nothing between 300 Hz and 1 kHz, which reads as a tick. So a short knock
    # of stone is laid under it (`body`: noise in a band, 40 ms) and a few specks
    # of grit after it (`grit`) -- pickaxe, ore, small debris, in that order.
    **{f"pick_{n + 1}": dict(pack="impact", src=f"impactMining_00{n}.ogg", hp=260, lp=9000,
                             len=0.42, peak=0.55, body=(700, 1800, 0.045, 3.0),
                             grit=(5, 0.06, 400 + n)) for n in range(5)},
    # A cat at work: the same stone, much smaller -- pitched up and filtered
    # high, so it reads as a tiny pick rather than as hers.
    "cat_tap_1": dict(pack="impact", src="impactMining_000.ogg", hp=700, lp=7500,
                      pitch=1.5, len=0.2, peak=0.5, body=(1300, 2600, 0.025, 1.6)),
    "cat_tap_2": dict(pack="impact", src="impactMining_002.ogg", hp=700, lp=7500,
                      pitch=1.7, len=0.2, peak=0.5, body=(1400, 2800, 0.025, 1.6)),
    "cat_tap_3": dict(pack="impact", src="impactMining_004.ogg", hp=700, lp=7500,
                      pitch=1.4, len=0.2, peak=0.5, body=(1200, 2500, 0.025, 1.6)),
    # A boot in packed snow. Five takes; running uses the same five, a little
    # faster (Audio.gd).
    **{f"step_{n + 1}": dict(pack="impact", src=f"footstep_snow_00{n}.ogg", hp=140, lp=8000,
                             len=0.30, peak=0.5) for n in range(5)},
    # A machine finishing a piece of work: a small, light piece of metal.
    "clink_1": dict(pack="impact", src="impactMetal_light_000.ogg", hp=300, lp=6500, len=0.25, peak=0.45),
    "clink_2": dict(pack="impact", src="impactMetal_light_002.ogg", hp=300, lp=6500, len=0.22, peak=0.45),
    "clink_3": dict(pack="impact", src="impactMetal_light_004.ogg", hp=300, lp=6500, len=0.2, peak=0.45),
    # Something arriving at the core: a soft tap of tin, not a beep.
    "deliver_1": dict(pack="impact", src="impactTin_medium_000.ogg", hp=280, lp=7000, len=0.16, peak=0.45),
    "deliver_2": dict(pack="impact", src="impactTin_medium_001.ogg", hp=280, lp=7000, len=0.16, peak=0.45),
    "deliver_3": dict(pack="impact", src="impactTin_medium_002.ogg", hp=280, lp=7000, len=0.13, peak=0.45),
    # The case unfolding into a base: a latch, then a creak of hinges.
    "latch": dict(pack="rpg", src="metalLatch.ogg", hp=220, lp=9000, len=0.26, peak=0.5),
    "creak": dict(pack="rpg", src="creak3.ogg", hp=200, lp=8000, len=0.34, peak=0.4),
    # Cloth: her getting up out of the snow, and out of bed.
    "rustle_1": dict(pack="rpg", src="cloth2.ogg", hp=250, lp=7000, len=0.42, peak=0.45),
    "rustle_2": dict(pack="rpg", src="cloth4.ogg", hp=250, lp=7000, len=0.38, peak=0.45),
}


def fetch(pack: str) -> zipfile.ZipFile:
    spec = PACKS[pack]
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / Path(spec["url"]).name
    if not path.exists():
        with urllib.request.urlopen(spec["url"], timeout=60) as response:
            path.write_bytes(response.read())
    archive = zipfile.ZipFile(path)
    licence = next((n for n in archive.namelist() if n.lower().endswith("license.txt")), None)
    if licence is None or spec["licence"] not in archive.read(licence).decode("utf-8", "replace"):
        raise SystemExit(f"CC0_SFX: {spec['title']} 의 라이선스를 확인할 수 없습니다 — 쓰지 않습니다")
    return archive


def decode(archive: zipfile.ZipFile, name: str) -> list:
    member = next(n for n in archive.namelist() if n.endswith("/" + name) or n == name)
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise SystemExit("CC0_SFX: ffmpeg 가 필요합니다 (OGG 디코딩)")
    out = subprocess.run([ffmpeg, "-v", "quiet", "-i", "pipe:0", "-f", "s16le", "-ac", "1",
                          "-ar", str(RATE), "pipe:1"], input=archive.read(member),
                         capture_output=True, check=True).stdout
    return [v / 32768.0 for v in struct.unpack("<%dh" % (len(out) // 2), out)]


def resample(samples: list, factor: float) -> list:
    """Plays `factor` times faster: higher and shorter, like a tape."""
    length = int(len(samples) / factor)
    out = []
    for i in range(length):
        x = i * factor
        a = int(x)
        b = min(a + 1, len(samples) - 1)
        t = x - a
        out.append(samples[a] * (1.0 - t) + samples[b] * t)
    return out


def process(samples: list, spec: dict) -> list:
    if spec.get("pitch"):
        samples = resample(samples, spec["pitch"])
    filters = [Biquad("hp", spec["hp"]), Biquad("hp", spec["hp"]),
               Biquad("lp", spec["lp"]), Biquad("lp", spec["lp"])]
    out = []
    for v in samples:
        for f in filters:
            v = f(v)
        out.append(v)
    # Start at the hit, not at the silence before it.
    threshold = max(abs(v) for v in out) * 0.05
    first = next((i for i, v in enumerate(out) if abs(v) > threshold), 0)
    first = max(0, first - int(RATE * 0.004))
    out = out[first:first + int(RATE * spec["len"])]
    # A short fade in (no click) and a fade out over the last third.
    fade_in = int(RATE * 0.003)
    fade_out = max(1, len(out) // 3)
    for i in range(len(out)):
        gain = min(1.0, i / fade_in)
        left = len(out) - i
        if left < fade_out:
            gain *= (left / fade_out) ** 1.5
        out[i] *= gain
    # Layers laid over the recording, each against its own peak.
    out = normalise(out, 1.0)
    rng = random.Random(spec.get("grit", (0, 0, 7))[2] if spec.get("grit") else 7)
    if spec.get("body"):
        low, high, decay, gain = spec["body"]
        noise_into(out, 0.0, min(len(out) / RATE, decay * 6.0), low, high, gain, rng,
                   attack=0.001, decay=decay)
    if spec.get("grit"):
        count, gain, _seed = spec["grit"]
        for _ in range(count):
            grain_into(out, rng.uniform(0.05, len(out) / RATE * 0.7), 0.012, 2200.0,
                       gain * rng.uniform(0.5, 1.0), rng)
    return normalise(out, spec["peak"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", default="", help="build one sound by name")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    archives = {}
    for name, spec in SOUNDS.items():
        if args.only and args.only != name:
            continue
        if spec["pack"] not in archives:
            archives[spec["pack"]] = fetch(spec["pack"])
        samples = process(decode(archives[spec["pack"]], spec["src"]), spec)
        write(OUT / f"{name}.wav", samples)
        print(f"{name:12s} {measure(OUT / f'{name}.wav')}  <- {spec['src']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
