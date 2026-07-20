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
RUNNER_PAGE="runner-v2.html"

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

  # GitHub Pages applies browser caching headers that this repository cannot
  # override. Give every executable and game pack a content-addressed URL, then
  # leave a tiny stable loader at index.html that discovers the latest build.
  engine_hash="$(sha256sum "$OUT/$name/index.wasm" | cut -c1-12)"
  pack_hash="$(sha256sum "$OUT/$name/index.pck" | cut -c1-12)"
  engine_base="engine-${engine_hash}"
  pack_name="game-${pack_hash}.pck"
  page_name="game-${pack_hash}.html"

  mv "$OUT/$name/index.js" "$OUT/$name/${engine_base}.js"
  mv "$OUT/$name/index.wasm" "$OUT/$name/${engine_base}.wasm"
  mv "$OUT/$name/index.audio.worklet.js" "$OUT/$name/${engine_base}.audio.worklet.js"
  mv "$OUT/$name/index.audio.position.worklet.js" "$OUT/$name/${engine_base}.audio.position.worklet.js"
  mv "$OUT/$name/index.pck" "$OUT/$name/$pack_name"
  mv "$OUT/$name/index.html" "$OUT/$name/$page_name"

  sed -i \
    -e "s|src=\"index.js\"|src=\"${engine_base}.js\"|" \
    -e "s|\"args\":\[\]|\"args\":[],\"mainPack\":\"${pack_name}\"|" \
    -e "s|\"executable\":\"index\"|\"executable\":\"${engine_base}\"|" \
    -e "s|\"index.pck\":|\"${pack_name}\":|" \
    -e "s|\"index.wasm\":|\"${engine_base}.wasm\":|" \
    "$OUT/$name/$page_name"

  # The runner is stable and may be cached. It reads the requested content-
  # hashed PCK name from its query string and downloads that unique file
  # directly from the repository, avoiding the GitHub Pages deployment delay.
  cp "$OUT/$name/$page_name" "$OUT/$name/$RUNNER_PAGE"
  sed -i \
    -e "/const engine = new Engine/i\\
const RUNNER_PARAMS = new URLSearchParams(location.search);\\
const REQUESTED_PACK = RUNNER_PARAMS.get('pack') || GODOT_CONFIG.mainPack;\\
const REQUESTED_PACK_SIZE = Number(RUNNER_PARAMS.get('size')) || GODOT_CONFIG.fileSizes[GODOT_CONFIG.mainPack];\\
const REMOTE_PACK = \`https://raw.githubusercontent.com/7bvcxz/gamo/main/docs/${name}/\${REQUESTED_PACK}\`;\\
GODOT_CONFIG.fileSizes[REMOTE_PACK] = REQUESTED_PACK_SIZE;\\
    GODOT_CONFIG.args = ['--main-pack', REQUESTED_PACK].concat(GODOT_CONFIG.args);" \
    -e "s|engine.startGame({|engine.init(GODOT_CONFIG.executable).then(() => engine.preloadFile(REMOTE_PACK, REQUESTED_PACK)).then(() => engine.start({|" \
    -e "/engine.init(GODOT_CONFIG.executable)/,/setStatusMode('hidden')/ s|^[[:space:]]*}).then(() => {$|\t\t})).then(() => {|" \
    "$OUT/$name/$RUNNER_PAGE"

  cp "$ROOT/web-index-loader.html" "$OUT/$name/index.html"
  cp "$ROOT/web-version.json" "$OUT/$name/version.json"
  pack_size="$(stat -c%s "$OUT/$name/$pack_name")"
  sed -i \
    -e "s|__RUNNER_PAGE__|${RUNNER_PAGE}|" \
    -e "s|__PACK_NAME__|${pack_name}|" \
    -e "s|__PACK_SIZE__|${pack_size}|" \
    "$OUT/$name/version.json"
  built+=("$name")
done

echo
echo "✅ 배포 완료: ${built[*]:-(없음)}  → docs/"
echo "   커밋/푸시 후 GitHub Pages(main /docs)가 서빙합니다:"
for n in "${built[@]:-}"; do [ -n "$n" ] && echo "   https://7bvcxz.github.io/gamo/$n/"; done
