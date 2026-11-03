# Windup — 태엽 공방 (The Wind-Up Atelier)

잊힌 양복점 공방에서 작은 정령이 큰 놋쇠 태엽을 감는다. 감은 힘이 잠든 태엽 인형을 깨우고, 깨어난 인형은
다음 인형을 함께 감는다. **행동 하나(감기)·통화 하나(태엽 힘)·자라는 것 하나(공방).**

- 플레이: https://7bvcxz.github.io/gamo/windup/ (주소 옵션은 아래)
- 설계: [`design/CORE_LOOP.md`](design/CORE_LOOP.md) · 3분 측정: [`design/PLAYTEST_3MIN.md`](design/PLAYTEST_3MIN.md)
- 진행 기록(재개 지점): [`PROGRESS.md`](PROGRESS.md) · 개발 단계: GitHub 이슈 "Windup Step NN"
- 저장소 공통 규칙: 루트 [`AGENTS.md`](../AGENTS.md)

## 요구 환경

| 도구 | 버전 |
|---|---|
| Godot | 4.7.stable (`godot`이 PATH에, 아니면 `GODOT=/path/to/godot`) |
| Web export 템플릿 | 4.7.stable `web_nothreads_*` |
| Node | 20 이상 (브라우저 검사만) |

렌더러는 Compatibility, 기준 화면은 **가로 1280×720**(PC 먼저)이며 `expand`로 어떤 창이든 채운다.

## 명령 (저장소 루트에서)

```bash
godot --path windup                                  # 실행
godot --path windup -- --seed 3 --dev                # 옵션과 함께 (F5 = 같은 시드로 새 게임)
windup/tools/test.sh                                 # unit + integration (SCRIPT ERROR·누수도 실패)
windup/tools/smoke.sh                                # 실제 씬을 헤드리스로: 누름 8번, 요약 한 줄
windup/tools/check.sh [--export]                     # CI와 같은 검사 (+ Web export·팩 내용)
xvfb-run -a -s "-screen 0 1600x1000x24" godot --path windup --audio-driver Dummy \
  --resolution 1280x720 --script res://tools/capture.gd -- --out /abs/shot.png   # 실제 렌더러 화면
./deploy-web.sh windup                               # Web export → docs/windup/
windup/tools/e2e.sh                                  # 브라우저 검사 (로컬 docs/, 처음엔 tests/e2e에서 npm install)
WINDUP_E2E_BASE=https://7bvcxz.github.io/gamo/windup/ windup/tools/e2e.sh   # 공개 빌드에
```

### 주소 옵션

| 옵션 | 뜻 |
|---|---|
| `?fresh=1` | 새 게임으로 시작 |
| `?seed=N` | 새 게임의 시드 |
| `?variant=a\|b\|c` | Fun Lab 변형 (Step 06) |
| `?dev=1` | 개발 훅(`window.windup.call('dev_…')`)과 F5 새 게임 |

## 구조

| 경로 | 내용 |
|---|---|
| `scenes/main.tscn` | 진입점 (`src/app/main.gd`) |
| `src/core/` | 시계(`GameClock`, 멈춤), 계측(`Telemetry`, `{t, ev}` JSON 줄), 실행 옵션(`RunConfig`) |
| `src/view/` | 공방 화면 |
| `src/web/` | 브라우저: 주소 옵션·보임/포커스(`WindupWeb`), `window.windup` 브리지(`WindupBridge`) |
| `data/` | 밸런스 데이터 (Step 04부터) |
| `tests/` | `unit`·`integration`(헤드리스), `e2e`(Playwright, `.gdignore`) |
| `tools/` | 검사·캡처 도구 (export 제외) |
| `design/`, `evidence/` | 설계 문서, step별 증거 (`.gdignore`, export 제외) |

## 멈춤

창이 포커스를 잃거나 탭이 숨으면 게임 시계가 멈춘다. 자리를 비운 동안 진행되는 것은 없다(오프라인 진행 없음).
