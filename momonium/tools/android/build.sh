#!/usr/bin/env bash
# Android builds of Momonium (Step 44).
#
#   momonium/tools/android/build.sh debug     # APK signed with the editor's debug keystore
#   momonium/tools/android/build.sh release   # APK signed with the release key from the environment
#
# The release key never enters the repository. Godot reads it from
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# (a CI secret, or a file the person releasing keeps elsewhere). Without them a
# release build stops here. The Play Store bundle (AAB) needs Godot's Gradle
# build: design/ANDROID.md.
#
# version/name is empty in the preset, so the app takes config/version; the
# version code is derived from it here -- 0.43.1 -> 4301 -- and written into
# the preset only for the export, then put back.
set -euo pipefail
mode="${1:-debug}"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$HERE"
[[ "$mode" == debug || "$mode" == release ]] || { echo "usage: build.sh debug|release"; exit 2; }
if [[ "$mode" == release ]]; then
  for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
    [[ -n "${!v:-}" ]] || { echo "release signing needs $v (never commit it)"; exit 3; }
  done
fi
version="$(sed -nE 's/^config\/version="([^"]+)"/\1/p' project.godot)"
IFS=. read -r major minor patch <<<"$version"
code=$(( major * 10000 + minor * 100 + patch ))
backup="$(mktemp)"
cp export_presets.cfg "$backup"
trap 'cp "$backup" export_presets.cfg; rm -f "$backup"' EXIT
sed -i -E "s/^version\/code=.*/version\/code=$code/" export_presets.cfg
mkdir -p build/android
touch build/.gdignore
out="build/android/momonium-$version-$mode.apk"
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . "--export-$mode" Android "$out" 2>&1 | grep -E 'ERROR|error:' && { echo "export failed"; exit 1; }
[[ -f "$out" ]] || { echo "no APK produced"; exit 1; }
tools="$(ls -d "${ANDROID_HOME:-$HOME/Android/Sdk}"/build-tools/* | sort -V | tail -n 1)"
"$tools/aapt2" dump badging "$out" | grep -E "^package:|^sdkVersion|^targetSdkVersion|^application-label:" || true
"$tools/apksigner" verify --print-certs "$out" | grep -E "certificate (DN|SHA-256)" || { echo "not signed"; exit 1; }
echo "apk: $out ($(stat -c%s "$out") bytes, version $version, code $code)"
