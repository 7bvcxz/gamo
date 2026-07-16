#!/usr/bin/env bash
# gamo의 모든 Godot 게임을 웹(단일스레드)으로 export 하여 docs/<게임명>/ 에 배포.
# GitHub Pages(main /docs)로 서빙 → https://7bvcxz.github.io/gamo/<게임명>/
#
# 사용: ./deploy-web.sh            (전체 게임)
#       ./deploy-web.sh nowhere    (특정 게임만)
#       GODOT=/path/to/godot ./deploy-web.sh   (godot 경로 지정)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-godot}"
OUT="$ROOT/docs"
ONLY="${1:-}"

command -v "$GODOT" >/dev/null 2>&1 || { echo "godot 실행파일을 찾을 수 없습니다 (GODOT 환경변수로 지정)"; exit 1; }

mkdir -p "$OUT"
touch "$OUT/.nojekyll"   # GitHub Pages Jekyll 처리 비활성화(정적 파일 그대로 서빙)

built=()
for proj in "$ROOT"/*/; do
  name="$(basename "$proj")"
  [ -f "${proj}project.godot" ] || continue
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue

  if ! grep -q 'platform="Web"' "${proj}export_presets.cfg" 2>/dev/null; then
    echo "⚠ $name: Web export 프리셋이 없어 건너뜀 (export_presets.cfg에 Web 프리셋 필요)"
    continue
  fi

  echo "▶ export: $name"
  "$GODOT" --headless --path "$proj" --import >/dev/null 2>&1 || true
  mkdir -p "$OUT/$name"
  rm -f "$OUT/$name"/index.* 2>/dev/null || true
  "$GODOT" --headless --path "$proj" --export-release "Web" "$OUT/$name/index.html"
  built+=("$name")
done

echo
echo "✅ 배포 완료: ${built[*]:-(없음)}  → docs/"
echo "   커밋/푸시 후 GitHub Pages(main /docs)가 서빙합니다:"
for n in "${built[@]:-}"; do [ -n "$n" ] && echo "   https://7bvcxz.github.io/gamo/$n/"; done
