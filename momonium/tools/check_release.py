#!/usr/bin/env python3
"""What a Momonium web build ships, checked before anyone plays it.

    python3 momonium/tools/check_release.py PACK [--site DIR] [--budget-mb 20] [--version X.Y.Z]

Reads the pack's own directory (Godot 4 PCK) instead of grepping it, so the
answer is a list, not a guess:

- nothing that is not the game: tests/, tools/, design/ never ship;
- everything the game loads: the data tables, all four languages, the sprite
  atlas, the fonts, the sounds, the main scene;
- under the size budget.

With --site (the published folder, docs/momonium): the stable index and
version.json name this pack, the pack's name is its content hash, its size is
the one the loader announces, the runner and the game page are there, the
engine files the game page asks for exist in ../engine, and the launch page is
there. With --version: version.json says that version.

Prints a summary (files and bytes per top folder) and exits 1 on any problem.
"""
import hashlib
import json
import os
import re
import struct
import sys
from collections import Counter

FORBIDDEN = ("tests/", "tools/", "design/", "web/", ".github/")
REQUIRED = [
    "project.binary",
    "data/balance.json", "data/buildings.json", "data/items.json", "data/letters.json",
    "data/research.json", "data/recipes.json", "data/art.json",
    "data/i18n/ui.en.translation", "data/i18n/ui.ko.translation",
    "data/i18n/ui.ja.translation", "data/i18n/ui.zh_CN.translation",
]
# Imported resources ship under .godot/imported with their source's name.
REQUIRED_IMPORTED = [r"assets/atlas/", r"ui_ko\.otf", r"ui_ja\.otf", r"ui_zh\.otf", r"\.ogg"]
MIN_SOUNDS = 17


def read_pack(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"GDPC":
        raise ValueError("not a Godot pack")
    fmt, major, minor, patch, flags = struct.unpack("<IIIII", data[4:24])
    if fmt >= 3:
        _base, dir_at = struct.unpack("<QQ", data[24:40])
    else:
        dir_at = 24 + 8 + 16 * 4
    count = struct.unpack("<I", data[dir_at:dir_at + 4])[0]
    p = dir_at + 4
    files = []
    for _ in range(count):
        n = struct.unpack("<I", data[p:p + 4])[0]
        p += 4
        name = data[p:p + n].rstrip(b"\0").decode()
        p += n
        _off, size = struct.unpack("<QQ", data[p:p + 16])
        p += 16 + 16 + 4
        files.append((name.removeprefix("res://"), size))
    return {"godot": f"{major}.{minor}.{patch}", "format": fmt, "files": files, "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def main(argv):
    args = {"budget-mb": "20"}
    rest = []
    i = 0
    while i < len(argv):
        if argv[i].startswith("--"):
            args[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    if not rest:
        print(__doc__)
        return 2
    problems = []
    pack = read_pack(rest[0])
    names = [n for n, _ in pack["files"]]
    print(f"pack {os.path.basename(rest[0])}: {pack['bytes']:,} bytes, {len(names)} files, Godot {pack['godot']} (format {pack['format']}), sha256 {pack['sha256'][:12]}")
    by = Counter()
    size_by = Counter()
    for n, s in pack["files"]:
        top = n.split("/")[0] if "/" in n else "(root)"
        by[top] += 1
        size_by[top] += s
    for top, c in by.most_common():
        print(f"  {top:<10} {c:4d} files {size_by[top]:>11,} bytes")
    for n in names:
        if n.startswith(FORBIDDEN):
            problems.append(f"not part of the game, but shipped: {n}")
    for r in REQUIRED:
        if r not in names:
            problems.append(f"missing: {r}")
    for r in REQUIRED_IMPORTED:
        if not any(re.search(r, n) for n in names):
            problems.append(f"missing anything matching {r}")
    sounds = {re.sub(r"-[0-9a-f]{32}.*$", "", n.split("/")[-1]) for n in names if n.startswith(".godot/imported/") and ".ogg-" in n}
    print(f"  sounds {len(sounds)}, scenes {sum(1 for n in names if n.startswith('scenes/'))}")
    if len(sounds) < MIN_SOUNDS:
        problems.append(f"only {len(sounds)} sounds (expected {MIN_SOUNDS})")
    budget = int(float(args["budget-mb"]) * 1024 * 1024)
    if pack["bytes"] > budget:
        problems.append(f"{pack['bytes']:,} bytes is over the {args['budget-mb']} MB budget")

    site = args.get("site")
    if site:
        name = os.path.basename(rest[0])
        version = json.load(open(os.path.join(site, "version.json")))
        if version.get("pack") != name:
            problems.append(f"version.json names {version.get('pack')}, not {name}")
        if int(version.get("packSize", -1)) != pack["bytes"]:
            problems.append(f"version.json says {version.get('packSize')} bytes, the pack is {pack['bytes']}")
        if not name.startswith("game-") or name[5:-4] != pack["sha256"][:len(name) - 9]:
            problems.append(f"{name} is not named by its content hash ({pack['sha256'][:12]})")
        index = open(os.path.join(site, "index.html")).read()
        if name not in index:
            problems.append("index.html does not send players to this pack")
        page = version.get("page", "runner-v2.html")
        if not os.path.exists(os.path.join(site, page)):
            problems.append(f"the runner {page} is missing")
        game_page = os.path.join(site, name[:-4] + ".html")
        if not os.path.exists(game_page):
            problems.append(f"the game page {os.path.basename(game_page)} is missing")
        else:
            for ref in set(re.findall(r"\.\./engine/(engine-[0-9a-f]+)", open(game_page).read())):
                for ext in (".js", ".wasm"):
                    if not os.path.exists(os.path.join(site, "..", "engine", ref + ext)):
                        problems.append(f"the engine file {ref}{ext} is missing")
        if not os.path.exists(os.path.join(site, "launch.html")):
            problems.append("the launch page is missing")
        want = args.get("version")
        if want and version.get("version") != want:
            problems.append(f"version.json says {version.get('version')}, expected {want}")
        print(f"site: version {version.get('version', '-')}, Godot {version.get('godot', '-')}, source {version.get('source', '-')}")

    for p in problems:
        print("PROBLEM:", p)
    print("check_release:", "OK" if not problems else f"{len(problems)} problem(s)")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
