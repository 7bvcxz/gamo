# Momonium

바다 한가운데 2×2 섬에서 $10로 시작하는 세로형 섬 경영 게임. 모모(Momo)들이 일을 배워
섬을 마을로, 마을을 문명으로 키운다.

- 플레이: https://7bvcxz.github.io/gamo/momonium/ · 시작 페이지 [`launch.html`](https://7bvcxz.github.io/gamo/momonium/launch.html) · 데모 `?demo=full` / `?demo=large`
- 개발 단계: GitHub Issues `[momonium-step01]` ~ `[momonium-step49]` (44 다음은 46 → 47 → 48 → 49 → 45)
- 진행 기록(재개 지점): [`PROGRESS.md`](PROGRESS.md)
- 저장소 공통 규칙: 루트 [`AGENTS.md`](../AGENTS.md)

## 요구 환경

| 도구 | 버전 | 비고 |
|---|---|---|
| Godot | **4.7.stable** (`4.7.stable.official.5b4e0cb0f`) | `godot`이 PATH에 있어야 한다. 다른 버전이면 `GODOT=/path/to/godot` |
| Web export 템플릿 | 4.7.stable `web_nothreads_*` | `~/.local/share/godot/export_templates/4.7.stable/` |
| Node | 20 이상 | 브라우저 검사(Playwright 1.64.1)용 |
| Android | SDK + JDK 21 + Godot 4.7 Android 템플릿 | 템플릿은 `tools/android/fetch_templates.py`(필요한 두 파일만). 빌드·서명·AAB·실기기 결과는 [`design/ANDROID.md`](design/ANDROID.md) |

렌더러는 **Compatibility**(웹·모바일 공통), 기준 해상도는 세로 **720×1280**이며
`expand`로 어떤 화면비든 채운다.

## 명령

모든 경로는 저장소 루트 기준이다.

```bash
# 실행
godot --path momonium

# 헤드리스 테스트 (unit + integration). 출력의 SCRIPT ERROR·leak 경고도 실패로 센다
momonium/tools/test.sh
momonium/tools/test.sh unit            # 한 묶음만
momonium/tools/test.sh unit land       # id에 land가 들어간 케이스만

# 아트: SVG → 아틀라스, 팔레트 → 지형 텍스처 (design/ART_SPEC.md)
godot --headless --path momonium --script res://tools/art/build_atlas.gd
godot --headless --path momonium --script res://tools/art/build_textures.gd

# UI 글꼴: 언어별 Noto Sans CJK 서브셋 (data/i18n/*.csv의 글자로)
(cd momonium/tools/fonts && npm install && node build_fonts.mjs)

# CI와 같은 검사: import → 에디터 로드 → 테스트 (+ --export: Web export·팩 크기·브라우저 스모크)
momonium/tools/check.sh --export

# 화면 캡처 (실제 렌더러가 필요하므로 Xvfb)
xvfb-run -a -s "-screen 0 1280x1600x24" godot --path momonium --audio-driver Dummy \
  --script res://tools/capture.gd -- --out /abs/shot.png --size 405x720

# Web export → docs/momonium/ (소스를 먼저 커밋 — version.json에 커밋이 적힌다; 팩 내용 검사 포함)
momonium/tools/deploy.sh

# push 뒤 Pages 반영 대기 → 공개 URL 스모크(폰·데스크톱) → CI 결과
momonium/tools/verify_release.sh

# Android APK (릴리스는 서명 키 환경 변수가 필요 — design/ANDROID.md)
momonium/tools/android/build.sh debug

# 플레이 봇 보고서 / 밸런스 후보 비교 (design/BALANCE.md)
godot --headless --path momonium --script res://tools/playtest/run.gd -- --minutes 30

# 배포 스모크 검사 (E2E 아님). 처음 한 번 npm install
(cd momonium/tests/e2e && npm install && node smoke.mjs --url https://7bvcxz.github.io/gamo/momonium/)

# E2E (브라우저) — 전체 실행은 Step 10·20·30·40에서만. 자세한 것은 tests/e2e/README.md
(cd momonium/tests/e2e && npx playwright test specs/boot.spec.mjs)
```

설계: [`design/ARCHITECTURE.md`](design/ARCHITECTURE.md) · [`design/DESIGN_RULES.md`](design/DESIGN_RULES.md) ·
[`design/TOOLING.md`](design/TOOLING.md) · [`design/TESTING.md`](design/TESTING.md) · [`design/ART_SPEC.md`](design/ART_SPEC.md) ·
[`design/BALANCE.md`](design/BALANCE.md) · [`design/RELEASE.md`](design/RELEASE.md) (웹 배포·캐시) ·
[`design/ANDROID.md`](design/ANDROID.md) · [`design/RELEASE_CHECKLIST.md`](design/RELEASE_CHECKLIST.md) (단계별 출시·게임 범위·수익화 계획)

## 게임의 범위

- **혼자 하는 로컬 우선 게임.** 계정·서버·순위표가 없고, 섬은 그 브라우저나 기기에만 저장된다.
- **설치하는 건물은 네 가지**(밭·광산·목재소·연구소, 반복해서 짓는다)와 **특별**(시계탑·학교·모모 기념비, 종류마다 하나).
  다른 시설은 네 가지를 개조해서 만든다.
- **마을 → 도시 → 국가**: 특별 건물 자리가 1·2·3개.
- **매각(Prestige)**: 연구 레벨이 연구 포인트가 되어 해금은 남고, 새 섬에서 자유롭게 다시 배치한다(3/1/1 → 1/2/2).
- 웹 데모는 무료로 끝까지 플레이할 수 있다. 결제(Accelerator)는 계획만 있고 넣지 않았다.

## 폴더

| 경로 | 내용 |
|---|---|
| `scenes/` | 씬. `main.tscn`이 진입점 |
| `src/` | 게임 코드 (모듈 구조는 `design/ARCHITECTURE.md`) |
| `data/` | 밸런스·콘텐츠 데이터 (JSON) |
| `assets/` | 게임이 쓰는 그림·소리 |
| `tests/unit`, `tests/integration` | 헤드리스 GDScript 테스트 (`tools/test.sh`) |
| `tests/e2e` | 브라우저 검사. `.gdignore`로 Godot이 읽지 않는다 |
| `tools/` | 캡처·빌드 보조 도구 (export 제외) |
| `design/` | 설계 문서 (`.gdignore`, export 제외) |
| `web/` | 웹 시작 페이지 원본 (`.gdignore`, export 제외 — deploy가 `docs/momonium/`로 복사) |
| `build/` | 로컬 빌드 산출물(Android APK 등). 커밋하지 않는다 |
