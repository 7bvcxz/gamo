#!/usr/bin/env bash
# Builds the site and makes it live on this machine.
#
#   ./deploy/publish.sh            # build the web bundle, then publish
#   ./deploy/publish.sh --no-build # publish what is already in docs/
#
# Publishing is a copy and a compress. There is no build service to wait for and
# no cache to outlast: the files are in place when this script returns.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVE="${GAMO_SERVE_ROOT:-$HOME/srv/gamo}"

if [[ "${1:-}" != "--no-build" ]]; then
  echo "── build"
  # The Pages-shaped build: base /gamo, output copied into docs/ beside the
  # games. This host serves the same files GitHub Pages does, which is what lets
  # either be switched off without a rebuild.
  (cd "$REPO/web" && npm run build:pages >/dev/null)
fi

echo "── copy"
mkdir -p "$SERVE"
# --delete so a file removed from docs/ stops being served. Without it the old
# packs pruned last week would still be answering 200 from this machine.
rsync -a --delete --exclude='*.gz' "$REPO/docs/" "$SERVE/"

echo "── compress"
# Once per deploy rather than once per request. Only the types a browser will
# accept compressed, and only where it is worth the bytes: the engine wasm goes
# 37.7MB -> ~10MB, which is the difference between this host and Pages being the
# same speed or not. -k keeps the original for clients that do not send
# Accept-Encoding, which nginx needs both of.
count=0
while IFS= read -r -d '' file; do
  gzip -9 -kf "$file"
  count=$((count + 1))
done < <(find "$SERVE" -type f \
  \( -name '*.wasm' -o -name '*.pck' -o -name '*.js' -o -name '*.css' \
     -o -name '*.html' -o -name '*.json' -o -name '*.svg' \) \
  -size +1k -print0)
echo "   $count files"

echo "── verify"
# Against the running container, not the filesystem: a file that exists and a
# file that is served are different claims, and only the second one matters.
for path in /gamo/ /gamo/motorio-oneshot/ /gamo/motorio-oneshot/graphic/proposals/; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://127.0.0.1:8090$path")
  printf '   %-45s %s\n' "$path" "$code"
  [[ "$code" == "200" ]] || { echo "   FAILED"; exit 1; }
done

engine=$(find "$SERVE" -name 'engine-*.wasm' | head -1)
if [[ -n "$engine" ]]; then
  rel="/gamo/${engine#"$SERVE"/}"
  read -r enc len < <(curl -sI -H 'Accept-Encoding: gzip' --max-time 10 "http://127.0.0.1:8090$rel" \
    | awk 'BEGIN{IGNORECASE=1} /^content-encoding/{e=$2} /^content-length/{l=$2} END{print e, l}' | tr -d '\r')
  printf '   engine wasm: %s %s bytes\n' "${enc:-none}" "${len:-?}"
fi

du -sh "$SERVE" | awk '{print "   served: " $1}'
echo "done"
