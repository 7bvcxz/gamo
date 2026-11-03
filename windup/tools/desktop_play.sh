#!/usr/bin/env bash
# Plays the REAL desktop window (not the browser, not headless): Xvfb at the
# given size, the game in a native window, OS-level clicks and keys through
# XTEST (tools/xinput.py), the screen recorded with ffmpeg x11grab, the game's
# event log written by the game itself (--trace-out).
#
#   windup/tools/desktop_play.sh <out-dir> [WxH] [steps-file] [seconds]
#
# Defaults: 1920x1080, a built-in 60 s pattern (clicks, a 10 s hold, Space).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(cd "${1:?out dir}" && pwd)"
SIZE="${2:-1920x1080}"
STEPS="${3:-}"
SECONDS_TOTAL="${4:-70}"
W="${SIZE%x*}"; H="${SIZE#*x}"
DISP=":$((90 + RANDOM % 9))"
GODOT="${GODOT:-godot}"
# The key's screen position: the design rectangle (1280x720) scaled to fit,
# centred; the key is at (640, 380) in it.
read KX KY < <(python3 -c "w,h=$W,$H; s=min(w/1280,h/720); ox=(w-1280*s)/2; oy=(h-720*s)/2; print(int(ox+640*s), int(oy+380*s))")
if [[ -z "$STEPS" ]]; then
  STEPS="$OUT/steps.txt"
  { echo "sleep 3"; for i in $(seq 1 6); do echo "click $KX $KY"; echo "sleep 0.4"; done
    echo "down $KX $KY"; echo "sleep 10"; echo "up"; echo "sleep 1"
    for i in $(seq 1 20); do echo "key space"; echo "sleep 0.3"; done
    echo "down $KX $KY"; echo "sleep 30"; echo "up"; echo "sleep 3"; } > "$STEPS"
fi
Xvfb "$DISP" -screen 0 "${W}x${H}x24" -nolisten tcp >/dev/null 2>&1 &
XPID=$!
trap 'kill $GPID $FPID $XPID 2>/dev/null || true' EXIT
sleep 1.5
DISPLAY="$DISP" "$GODOT" --path "$HERE" --audio-driver Dummy --resolution "${W}x${H}" --position 0,0 -- --fresh --trace-out "$OUT/trace.jsonl" > "$OUT/game.log" 2>&1 &
GPID=$!
sleep 3
ffmpeg -hide_banner -loglevel error -y -f x11grab -video_size "${W}x${H}" -framerate 15 -i "$DISP" -t "$SECONDS_TOTAL" -vf "scale=960:-2" -c:v libx264 -pix_fmt yuv420p -preset veryfast -crf 30 "$OUT/desktop.mp4" &
FPID=$!
DISPLAY="$DISP" python3 "$HERE/tools/xinput.py" script "$STEPS"
wait $FPID || true
sleep 2.5
kill $GPID 2>/dev/null || true
wait $GPID 2>/dev/null || true
echo "key at $KX,$KY on ${W}x${H}; video $OUT/desktop.mp4; trace $(wc -l < "$OUT/trace.jsonl") events"
errors="$(grep -cE 'SCRIPT ERROR|ERROR:' "$OUT/game.log" || true)"
echo "engine errors: $errors"
[[ "$errors" == "0" && -s "$OUT/trace.jsonl" ]]
