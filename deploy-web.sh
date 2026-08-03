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
  # hashed PCK name from its query string and downloads that unique file.
  #
  # Pages first, the repository second. Pages serves the pack gzipped from a CDN
  # edge, while raw.githubusercontent sends it uncompressed from a third host
  # that costs another DNS lookup and TLS handshake -- expensive on a phone. The
  # repository copy still has to exist as a fallback, because for the first few
  # minutes after a deploy Pages has not published the new hash yet and answers
  # 404 (and caches that 404, which is why this probes rather than assumes).
  #
  # The probe is started before engine.init and awaited after it, so it overlaps
  # the ten-megabyte wasm download and costs no wall-clock time at all.
  #
  # After the query string has been read into constants the runner rewrites the
  # address back to the game directory, so players keep one shareable URL
  # (/gamo/<game>/) instead of seeing a hashed runner link. Both documents live
  # in the same directory, so relative engine/wasm requests resolve identically.
  cp "$OUT/$name/$page_name" "$OUT/$name/$RUNNER_PAGE"
  sed -i \
    -e "/const engine = new Engine/i\\
const RUNNER_PARAMS = new URLSearchParams(location.search);\\
const REQUESTED_PACK = RUNNER_PARAMS.get('pack') || GODOT_CONFIG.mainPack;\\
const REQUESTED_PACK_SIZE = Number(RUNNER_PARAMS.get('size')) || GODOT_CONFIG.fileSizes[GODOT_CONFIG.mainPack];\\
const REMOTE_BASE = 'https://raw.githubusercontent.com/7bvcxz/gamo/main/docs/${name}/';\\
const VERSION_API = 'https://api.github.com/repos/7bvcxz/gamo/contents/docs/${name}/version.json?ref=main';\\
try { history.replaceState(null, '', './'); } catch (e) { console.warn('URL tidy skipped', e); }\\
    GODOT_CONFIG.args = ['--main-pack', REQUESTED_PACK].concat(GODOT_CONFIG.args);\\
const PHASE = document.createElement('div');\\
PHASE.style.cssText = 'position:absolute;bottom:15%;left:0;right:0;text-align:center;font:13px sans-serif;color:#dce9df;text-shadow:0 1px 3px #000;z-index:2';\\
document.body.appendChild(PHASE);\\
const PHASE_LOG = [];\\
let phaseStart = Date.now();\\
function setPhase(label) {\\
  if (PHASE_LOG.length) { PHASE.textContent = PHASE_LOG.join(' · ') + ' · ' + label; } else { PHASE.textContent = label; }\\
  phaseStart = Date.now();\\
  PHASE.dataset.current = label;\\
}\\
function endPhase(name) {\\
  PHASE_LOG.push(name + ' ' + ((Date.now() - phaseStart) / 1000).toFixed(1) + '초');\\
}\\
/* A pack the client asked for may no longer exist: the runner is cached for\\
   longer than an old build is kept, so a stale query string outlives its file.\\
   Try the CDN, then the repository, then ask what the current build is -- a\\
   loader that dies on a stale bookmark is worse than one extra request. */\\
async function resolvePack() {\\
  const candidates = [new URL(REQUESTED_PACK, location.href).href, REMOTE_BASE + REQUESTED_PACK];\\
  for (const url of candidates) {\\
    try { if ((await fetch(url, { method: 'HEAD' })).ok) { return { url: url, name: REQUESTED_PACK }; } } catch (e) { /* try the next one */ }\\
  }\\
  const current = await (await fetch(VERSION_API, { cache: 'no-store', headers: { Accept: 'application/vnd.github.raw+json' } })).json();\\
  console.warn('pack', REQUESTED_PACK, 'is gone; falling back to', current.pack);\\
  return { url: new URL(current.pack, location.href).href, name: current.pack };\\
}\\
/* Drop the --main-pack pair the line above just added: start() supplies its own\\
   and passing both would leave the engine picking between two pack names. */\\
const BASE_ARGS = GODOT_CONFIG.args.slice(2);\\
let RESOLVED_PACK = REQUESTED_PACK;\\
const PACK_SOURCE = resolvePack().then((pack) => {\\
  /* new Engine() copies the config, so the pack name has to reach it through\\
     start() rather than by mutating GODOT_CONFIG after the fact. */\\
  GODOT_CONFIG.fileSizes[pack.url] = REQUESTED_PACK_SIZE;\\
  RESOLVED_PACK = pack.name;\\
  return pack;\\
});" \
    -e "s|engine.startGame({|setPhase('엔진을 내려받는 중…'); engine.init(GODOT_CONFIG.executable).then(() => { endPhase('엔진'); setPhase('게임 파일을 내려받는 중…'); return PACK_SOURCE; }).then((pack) => engine.preloadFile(pack.url, pack.name)).then(() => { endPhase('게임 파일'); setPhase('시작하는 중…'); }).then(() => engine.start({ 'args': ['--main-pack', RESOLVED_PACK].concat(BASE_ARGS),|" \
    -e "/engine.init(GODOT_CONFIG.executable)/,/setStatusMode('hidden')/ s|^[[:space:]]*}).then(() => {$|\t\t})).then(() => {|" \
    -e "s|\t\t\tsetStatusMode('hidden');|\t\t\tPHASE.remove();\n\t\t\tsetStatusMode('hidden');|" \
    "$OUT/$name/$RUNNER_PAGE"

  # Keep the previous build alongside the new one. The runner is cached for
  # longer than a deploy cycle, so a browser can ask for the pack it saw last
  # time; deleting it immediately turned a stale cache into a game that refuses
  # to start. Two builds is enough for the loader's fallback never to be needed
  # in practice, and it is a couple of megabytes.
  keep_builds=2
  for stale in $(ls -1t "$OUT/$name"/game-*.pck 2>/dev/null | tail -n +$((keep_builds + 1))); do
    echo "  · 오래된 빌드 제거: $(basename "$stale")"
    rm -f "$stale" "${stale%.pck}.html"
  done

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
