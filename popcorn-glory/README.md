# Popcorn & Glory

팝콘 기계 **하나**, 돈 **하나**, 주된 행동 **하나**로 시작하는 작은 게임. 먼저 서로 다른 3분짜리
실험 셋을 만들어 직접 해 보고, 재미가 확인된 쪽만 키운다(Fun First).

- 진행 기록(재개 지점): [`PROGRESS.md`](PROGRESS.md)
- 재미의 기준(10·30·60·180초): [`FUN_FIRST.md`](FUN_FIRST.md)
- 도구 실측: [`design/TOOLS.md`](design/TOOLS.md) · 작업 절차: [`design/WORKFLOW.md`](design/WORKFLOW.md)
- 개발 단계: GitHub Issues `Popcorn Step NN` (7bvcxz/gamo)
- 저장소 공통 규칙: 루트 [`AGENTS.md`](../AGENTS.md)

## 지금 상태와 명령

플레이할 수 있는 Godot 프로젝트다(Godot 4.7, Compatibility, 세로 720×1280 `expand`).

**게임: 팝콘 가게 `#stand`**(선택 화면 맨 위의 별 타일, Step 10). 소유자가 Step 09에서 승인한 B의 손맛 위에
흔들기(3단계)·자동화 카드(4단계: 모터, 그다음 조수 냄비)·양념 셋(5단계)이 하나씩 열린다. 설계는 `design/SLICE.md`,
비교와 결정은 `experiments/RESULTS.md`·`DECISION.md`, 소유자 점수표는 `docs/popcorn-glory/scorecard.html`.

선택 화면에는 비교의 기준선인 세 실험도 그대로 있다:

| | 실험 | 주소 | 손이 하는 일 |
|---|---|---|---|
| A | Click & Pop | `#click` | 기계를 탭 — 누를 때마다 바로 터진다 |
| B | Perfect Pop | `#perfect` | 누르고 있다가 금색 구간에서 뗀다 (끝까지 누르면 저절로 탄다) |
| C | Pop Explosion | `#explosion` | 탭으로 낟알 8개를 채우면 연쇄 폭발 |

`#stub`은 Step 03의 토대(목록에 없음, 테스트용).

```bash
godot --path popcorn-glory                              # 실행 (선택 화면)
godot --path popcorn-glory -- --exp perfect --dev       # 실험 하나를 바로, 개발 시계와 함께
godot --headless --path popcorn-glory --script res://tools/selftest.gd   # 스크립트 플레이어 3분 (실제 규칙, 객관 수치)
godot --headless --path popcorn-glory --script res://tools/build_atlas.gd # art_src/*.svg -> assets/atlas/ (그다음 --import)
python3 popcorn-glory/tools/build_audio.py                                # 합성 소리 -> assets/audio/*.ogg
popcorn-glory/tools/test.sh                             # 헤드리스 unit + integration (엔진 오류도 실패)
popcorn-glory/tools/check.sh                            # import 두 번 + 에디터 로드 + 테스트
popcorn-glory/tools/deploy.sh                           # docs/popcorn-glory/ 로 Web export (소스를 먼저 커밋)
popcorn-glory/tools/test_all.sh                         # 전부 한 번에(헤드리스 → 배포 → 브라우저 → 보고서), 목록은 TESTS.md
popcorn-glory/tools/e2e.sh                              # 실제 브라우저(720×1280 터치·폰·데스크톱), 로컬 docs/
POPCORN_E2E_BASE=https://7bvcxz.github.io/gamo/popcorn-glory/ popcorn-glory/tools/e2e.sh   # 공개 빌드
xvfb-run -a -s "-screen 0 1280x1600x24" godot --path popcorn-glory --audio-driver Dummy \
  --script res://tools/capture.gd -- --out /abs/shot.png --size 720x1280 --exp stub --presses 12 --buy 1
```

주소 옵션: `#stand`·`#click`·`#perfect`·`#explosion`(직접 링크), `?trial=1`(3분 시험 절차: 3:00에 시계가 보인다), `?dev=1`(활동 시계 + 개발용 브리지 호출), `?motion=reduce`(효과 줄이기),
`?sound=off`(소리 끈 채 시작; 위쪽 스피커 버튼이 크게 → 작게 → 끔으로 돈다). `?dev=1`에서는 왼쪽 기록 버튼이 이번 실행의 JSON을 내려받는다. 그림·소리의 방향과 출처는 `design/ART_AUDIO.md`.
느린 브라우저 검사 `specs/play180.spec.mjs`는 실험마다 실제 3분을, `specs/play_stand.spec.mjs`는 가게를 실제 `POPCORN_STAND_MIN`분(기본 12분) 실제 입력으로 플레이한다(`--project p720`).

**배포가 `deploy-web.sh`가 아닌 이유**: 공용 runner는 게임이 시작되기 전에 주소를 게임 폴더로 되돌리고
(`history.replaceState('./')`) 로더는 해시를 넘기지 않으므로, 실험 하나로 가는 직접 링크(`#click`)가 살아남지
못한다. 그래서 Fun Lab(`momonium/experiments/tools/deploy.sh`)과 같은 방식을 쓴다 — Godot 자체 페이지가
공유 엔진 `docs/engine/`과 내용 해시 팩을 가리키고, 고정 `index.html`에 팩 이름을 적으며, 직전 팩 하나를 남긴다.
`api.github.com`은 쓰지 않는다. 배포는 `docs/popcorn-glory/`와 `docs/engine/` 밖이 바뀌면 실패한다.

## 구조

```
app/      main(주소·화면·한 곳에서 명령 실행), frame(뒤로·다시 시작·돈·업그레이드·3분), chooser,
          play_view(기계·입력·힌트), active_clock, session_log, bridge(window.popcorn), web, route, registry, ui/
core/     rules(정수 ms 시계의 결정적 규칙: execute·advance·이벤트), economy(data/economy.json 읽기·검사)
art/      palette, machine_art(도형으로 그린 기계 12단계·네 외형), machine_node(모양이 바뀔 때만 다시 그림),
          pop_fx(풀 400개, 아틀라스 스프라이트), atlas(아틀라스 읽기)
art_src/  손으로 쓴 SVG 원본 (.gdignore, 팩에 안 들어감)
assets/   atlas/(sprites.png + json, build_atlas.gd가 만듦), audio/(*.ogg, build_audio.py가 만듦)
variants/ click/ perfect/ explosion/ (각각 *_rules.gd = 규칙, *_view.gd = 그림), stub/
data/     economy.json — 가격·수확은 여기에만
tests/    unit · integration(헤드리스), e2e(Playwright)
tools/    test.sh check.sh deploy.sh e2e.sh capture.gd(--steps p,w1600,r) selftest.gd
```

- 바꾸는 길은 하나다: 화면이 명령을 내면 `PopApp`이 활동 시간을 찍고, 기록하고, 규칙에 실행하고, 그 이벤트를
  **같은 프레임에** 기록과 화면으로 넘긴다. 규칙은 그림·프레임 시계를 모른다(Step 06의 시뮬레이터가 같은 규칙을 쓴다).
- 버전은 `0.<step>.<재배포>`(`project.godot`의 `config/version`).

## 고정 식별자 — 다른 게임과 섞이지 않게

| 무엇 | 값 | 왜 |
|---|---|---|
| 폴더 | `popcorn-glory/` | 루트 바로 아래의 독립 게임(AGENTS.md) |
| Godot `config/name` | `Popcorn Glory` | 데스크톱 `user://`(app_userdata) 폴더 이름이 된다. `&`는 경로에 넣지 않는다 |
| Web `user://` | **저장하지 않는다** (프로토타입은 매 실행 새로 시작) | Godot Web은 `user://`를 `persistentPaths: ['/userfs']` 하나에 둔다 — 같은 도메인(7bvcxz.github.io)의 **모든 Godot 게임이 같은 IndexedDB 폴더**를 쓴다(`docs/engine/engine-*.js`에서 확인). 저장이 필요해지면 파일 이름을 `user://popcorn_glory_*`로만 쓴다 |
| localStorage | `popcorn-glory.*` 키만 | 비교 점수표 같은 Godot 밖 페이지용. 다른 키를 읽거나 지우지 않는다 |
| 배포 경로 | `docs/popcorn-glory/` → `https://7bvcxz.github.io/gamo/popcorn-glory/` | `deploy-web.sh`의 규칙 그대로. 해시 PCK·공유 엔진 `docs/engine/` |
| 사이트 | `web/app/popcorn-glory/doc/`, Vercel 리다이렉트 `/popcorn-glory` | 새 게임 등록 네 곳 + 문서 페이지(AGENTS.md) |
| 테스트 브리지 | `window.popcorn` (테스트 표지가 있을 때만) | E2E가 상태를 묻는 유일한 길 |

## 폴더와 export

| 경로 | 내용 | export |
|---|---|---|
| `design/` | 설계·도구·절차 문서 | 제외(`.gdignore`) |
| `scenes/`, `src/` | 게임 | 포함 |
| `tests/unit`, `tests/integration` | 헤드리스 GDScript 테스트 | 제외 |
| `tests/e2e` | Playwright 브라우저 검사 | 제외(`.gdignore`) |
| `tools/` | 테스트·캡처·배포 스크립트 | 제외 |
| `evidence/` | step별 증거 그림·기록 | 제외(`.gdignore`) |
