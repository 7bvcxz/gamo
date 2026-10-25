#!/usr/bin/env python3
"""Installs only the Android export templates Godot needs, without the 1.3 GB
archive: reads the official export-templates .tpz (a zip) on GitHub with HTTP
range requests and extracts just the files asked for into Godot's template
folder.

    python3 momonium/tools/android/fetch_templates.py [--version 4.7-stable] [--dir 4.7.stable] [files...]

Default files: templates/android_debug.apk, templates/android_release.apk.
"""
import io
import os
import sys
import urllib.request
import zipfile


class RangeFile(io.RawIOBase):
    """A seekable read-only file over HTTP range requests."""

    def __init__(self, url):
        self.url = url
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req) as r:
            self.url = r.geturl()
            self.size = int(r.headers["Content-Length"])
        self.pos = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        self.pos = {0: offset, 1: self.pos + offset, 2: self.size + offset}[whence]
        return self.pos

    def read(self, n=-1):
        if n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req) as r:
            data = r.read()
        self.pos += len(data)
        return data

    def readinto(self, b):
        data = self.read(len(b))
        b[:len(data)] = data
        return len(data)


def main(argv):
    version, folder = "4.7-stable", "4.7.stable"
    files = []
    i = 0
    while i < len(argv):
        if argv[i] == "--version":
            version = argv[i + 1]; i += 2
        elif argv[i] == "--dir":
            folder = argv[i + 1]; i += 2
        else:
            files.append(argv[i]); i += 1
    files = files or ["templates/android_debug.apk", "templates/android_release.apk"]
    url = f"https://github.com/godotengine/godot/releases/download/{version}/Godot_v{version}_export_templates.tpz"
    dest = os.path.expanduser(f"~/.local/share/godot/export_templates/{folder}")
    os.makedirs(dest, exist_ok=True)
    remote = io.BufferedReader(RangeFile(url), buffer_size=4 * 1024 * 1024)
    with zipfile.ZipFile(remote) as z:
        for name in files:
            info = z.getinfo(name)
            out = os.path.join(dest, os.path.basename(name))
            print(f"{name}: {info.file_size:,} bytes -> {out}")
            with z.open(info) as src, open(out, "wb") as dst:
                while True:
                    chunk = src.read(4 * 1024 * 1024)
                    if not chunk:
                        break
                    dst.write(chunk)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
