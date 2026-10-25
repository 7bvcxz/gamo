# Momonium

바다 한가운데 2×2 섬에서 $10로 시작하는 세로형 섬 경영 게임. 모모(Momo)들이 일을 배워
섬을 마을로, 마을을 문명으로 키운다.

- 플레이: https://7bvcxz.github.io/gamo/momonium/
- 개발 단계: GitHub Issues `[momonium-step01]` ~ `[momonium-step44]`
- 진행 기록(재개 지점): [`PROGRESS.md`](PROGRESS.md)
- 저장소 공통 규칙: 루트 [`AGENTS.md`](../AGENTS.md)

## 요구 환경

| 도구 | 버전 | 비고 |
|---|---|---|
| Godot | **4.7.stable** (`4.7.stable.official.5b4e0cb0f`) | `godot`이 PATH에 있어야 한다. 다른 버전이면 `GODOT=/path/to/godot` |
| Web export 템플릿 | 4.7.stable `web_nothreads_*` | `~/.local/share/godot/export_templates/4.7.stable/` |
| Node | 20 이상 | 브라우저 검사(Playwright 1.64.1)용 |
| Android | SDK + JDK 21 + Android 템플릿 | Step 44에서 사용. 설치 상태와 절차는 [`design/TOOLING.md`](design/TOOLING.md) |

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

# 화면 캡처 (실제 렌더러가 필요하므로 Xvfb)
xvfb-run -a -s "-screen 0 1280x1600x24" godot --path momonium --audio-driver Dummy \
  --script res://tools/capture.gd -- --out /abs/shot.png --size 405x720

# Web export → docs/momonium/ (저장소 공용 deploy-web.sh + 게시 중인 이전 빌드 보존)
momonium/tools/deploy.sh

# push 뒤 Pages 반영을 기다렸다가 공개 URL 스모크
momonium/tools/verify_pages.sh

# 배포 스모크 검사 (E2E 아님). 처음 한 번 npm install
(cd momonium/tests/e2e && npm install && node smoke.mjs --url https://7bvcxz.github.io/gamo/momonium/)

# E2E (브라우저) — 전체 실행은 Step 10·20·30·40에서만. 자세한 것은 tests/e2e/README.md
(cd momonium/tests/e2e && npx playwright test specs/boot.spec.mjs)
```

설계: [`design/ARCHITECTURE.md`](design/ARCHITECTURE.md) · [`design/DESIGN_RULES.md`](design/DESIGN_RULES.md) ·
[`design/TOOLING.md`](design/TOOLING.md)

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
