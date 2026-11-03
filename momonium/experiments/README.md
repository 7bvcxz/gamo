# Momonium Fun Lab

**재미있는 핵심 루프를 찾기 위한 작은 실험실**이다(Step 86). 본 게임을 더 복잡하게 만드는 대신,
서로 정말 다른 여섯 가지 3분짜리 실험을 따로 만들어 직접 해 보고 비교한다.

| | 실험 | 키우는 것 | 한 가지 버튼 | 주소 |
|---|---|---|---|---|
| A | Island Growth (Step 87, 플레이 가능) | 섬 전체 | Upgrade Island | `#island` |
| B | Momo Evolution (Step 90, 플레이 가능) | 모모 한 마리 | Upgrade Momo | `#evolution` |
| C | Break & Upgrade (Step 88, 플레이 가능) | 거대한 바위 · 곡괭이 | Pickaxe Power | `#rock` |
| D | Harvest Burst (Step 91, 플레이 가능) | 밭 하나 | Harvest All / Bigger Field | `#harvest` |
| E | Production Tycoon (Step 92, 플레이 가능) | 생산 라인 하나 | Improve Line | `#tycoon` |
| F | Endless Growth (Step 89, 플레이 가능) | 나무 한 그루 | Grow Tree | `#tree` |

- 실험실: https://7bvcxz.github.io/gamo/momonium-experiments/
- **C·E 두 트랙(Step 94부터)**: 소유자가 여섯을 해 보고 C와 E를 골랐다. 각각 그대로 둔 기준판과 고쳐 나갈 개선판이 있다.
  계획·규칙·3/15/30분 절차는 [`TRACKS.md`](TRACKS.md)에, 점수표는 https://7bvcxz.github.io/gamo/momonium-experiments/tracks.html 에 있다.

  | 판 | 주소 | |
  |---|---|---|
  | C 기준판 | `#rock` | Step 88 그대로 고정(`test_baselines.gd`) |
  | C+ 개선판 | `#rock-plus` | `experiments/rock_plus/`. Step 95 손맛(접촉·패임·조각·깨짐 정지·무게·곡괭이 단계), Step 96 30분 성장 |
  | E 기준판 | `#tycoon` | Step 92 그대로 고정 |
  | E+ 개선판 | `#tycoon-plus` | `experiments/tycoon_plus/`. Step 97 폰에서 큰 라인(화면 모양대로, 라인만 비춤, 물건 2–5배), Step 98 30분 성장(20단계·시대·예고, 대안 `?alt=grand`) |

  실험실 첫 화면 위쪽의 C·E 카드가 Baseline / Improved 버튼으로 넷을 연다. 여섯 타일은 그 아래에 그대로 있다.
- **비교 페이지(Step 93)**: https://7bvcxz.github.io/gamo/momonium-experiments/compare.html
  여섯 실험을 같은 순서(A·C·F 먼저)와 같은 3분 절차로 해 보고, 네 질문에 1–5점을 매기고, JSON·CSV·Markdown으로 내보낸다.
- 지금까지의 결과와 다음 실험 추천(잠정, 사람 점수 전): [`RESULTS.md`](RESULTS.md)
- 한 실험의 직접 링크: `…/momonium-experiments/#island`. 새로고침해도 그 실험이 다시 열린다.
- 틀 자체의 시연(스텁)은 숨은 링크 `#stub`으로 열린다(타일 없음, 실험실 테스트용).
- 아직 만들지 않은 실험의 타일은 **SOON**이다. 누르면 공통 스텁(코인·자라는 식물·버튼 하나와 'COMING SOON' 카드)이 열린다.
  스텁은 게임이 아니다. 실험이 실험실의 틀(뒤로·다시 시작·시계·기록)에서 뜬다는 것을 보여 준다.
- 본 게임은 그대로다. https://7bvcxz.github.io/gamo/momonium/

### 주소 옵션 (쿼리, 화면을 옮겨도 유지)

| 옵션 | 뜻 |
|---|---|
| `?dev=1` | 틀에 플레이 시계와 **기록** 버튼이 보인다. 기록 창에서 JSON·CSV 다운로드 |
| `?motion=reduce` | 움직임 줄이기. 시스템 설정 `prefers-reduced-motion`도 따른다 |
| `?sound=off` | 소리 끈 채로 시작. 틀의 스피커 버튼으로도 끄고 켠다 |
| `?alt=<이름>` | 트랙의 실험용 대안(Step 96·98). 기록의 `variant`에 남는다. 모르는 이름은 기본 |

예: `https://7bvcxz.github.io/gamo/momonium-experiments/?dev=1#rock`

## 구조 — 본 게임과 어떻게 분리되나

- `momonium/experiments/`는 **자기 `project.godot`을 가진 별도 Godot 프로젝트**다. Godot은 다른
  `project.godot`이 있는 폴더를 건너뛴다("Detected another project.godot ... will be ignored").
  그래서 게임의 import·export는 이 폴더를 보지 않는다. 게임 팩에 `res://experiments`가 없는지는
  `tests/unit/test_isolation.gd`와 게임 `tools/check.sh --export`가 확인한다. 실험실도 게임의 `res://`를 볼 수 없다.
- 게임에서 다시 쓰는 것(모모 시트, 아틀라스, 잔디·절벽 텍스처, 바다 셰이더, 소리, 폰트)은
  `shared/`에 **바이트 그대로 복사**한다(`tools/sync_shared.sh`, 목록은 `shared/MANIFEST.json`).
  처음 clone한 상태에서 바로 열린다. 원본과 다르면 `test_shared_assets.gd`가 실패한다.
  게임 그림이 바뀌어 실험실도 따라가야 하면 sync를 다시 돌리고 커밋한다. 새 유료 그림은 쓰지 않았다.
- 실험실은 **아무것도 저장하지 않는다.** 세이브·설정·localStorage·네트워크가 없다(`test_isolation.gd`가 소스를 검사한다).
  예외는 Godot 밖의 페이지 둘이다. 사람이 매긴 점수를 그 브라우저의 localStorage에만 둔다(서버로 보내지 않음).
  비교 페이지(`compare.html`)는 `funlab.compare.v1`, C·E 트랙 페이지(`tracks.html`)는 `funlab.tracks.v1`을 쓴다.
  E2E `compare93`·`tracks94`가 `funlab.` 밖의 키가 없음을 확인한다.
  이름이 `Momonium Fun Lab`이라 Godot의 user:// 폴더도 게임(`Momonium`)과 다르다. 브라우저에서 게임 세이브(IndexedDB와
  localStorage 사본)가 그대로인지는 E2E `funlab86`이 실제로 잰다.
- 실행마다 새로 시작한다. 다시 시작이나 뒤로를 누르면 그 실행의 실험·기록을 버리고 새로 만든다.
  기록 요약만 이번 방문 동안 메모리에 남는다.
- 배포는 `docs/momonium-experiments/`만 쓴다. 엔진은 `docs/engine/`의 공유 엔진을 그대로 가리킨다(같은 Godot이면 같은 파일).
  사이트 빌드(`web/scripts/to-docs.mjs`)는 게임 안에 중첩된 프로젝트를 `docs/<게임>-<폴더>/`로 보고 지우지 않는다(`kept-dirs.mjs`).

```
experiments/
  project.godot  export_presets.cfg  default_bus_layout.tres
  lab/            실험실의 틀: main(주소·화면), launcher(타일 여섯), host(틀·시계·정지),
                  session(기록), bridge(window.funlab), route, registry, audio, ui/, art/
  experiments/    실험 하나에 폴더 하나(stub = 아직 없는 실험의 자리)
  shared/         게임 파일의 사본 + MANIFEST.json
  tests/          unit · integration(헤드리스), e2e(Playwright)
  tools/          test.sh check.sh capture.gd deploy.sh e2e.sh sync_shared.sh selftest.gd
                  compare_assets.sh compare_grid.gd compare_jpg.gd (비교 페이지의 그림·숫자)
  web/            비교 페이지 compare.html과 compare/(그림·selftest.json), C·E 트랙 페이지 tracks.html. 팩에는 들어가지 않는다
  evidence/       step별 증거 그림·기록(팩에 들어가지 않는다)
  LOG.md          실험 기록(무엇을 만들었고, 무엇을 쟀나)
  TRACKS.md       C·E 두 트랙의 결정·규칙·3/15/30분 절차·의존 관계(Step 94부터)
  RESULTS.md      여섯 실험의 객관 수치와 다음 실험 추천(잠정)
```

## 명령 (저장소 루트에서)

```bash
godot --path momonium/experiments                          # 에디터/실행
godot --path momonium/experiments -- --exp island --dev    # 실험 하나를 바로
momonium/experiments/tools/test.sh                         # 단위 + 통합 (헤드리스)
momonium/experiments/tools/check.sh                        # import 두 번 + 에디터 로드 + 테스트 (CI와 같음)
xvfb-run -a -s "-screen 0 1280x1600x24" godot --path momonium/experiments --audio-driver Dummy \
  --script res://tools/capture.gd -- --out /abs/shot.png --size 720x1280 --exp island --advance 60
momonium/experiments/tools/deploy.sh                       # docs/momonium-experiments/ 로 Web export
momonium/experiments/tools/e2e.sh specs/funlab86.spec.mjs  # 브라우저 검사(로컬 docs/)
FUNLAB_E2E_BASE=https://7bvcxz.github.io/gamo/momonium-experiments/ momonium/experiments/tools/e2e.sh
momonium/experiments/tools/sync_shared.sh                  # 게임 그림이 바뀌었을 때
godot --headless --path momonium/experiments --script res://tools/selftest.gd -- --exp island   # 스크립트 플레이어 3분(객관 수치만)
godot --headless --path momonium/experiments --script res://tools/selftest.gd -- --exp rock-plus --seconds 900 --taps 1.5   # 트랙도, 15분, 느린 탭
momonium/experiments/tools/compare_assets.sh               # 비교 페이지의 그림(배포 빌드에서 각 실험을 처음부터 3분)·격자·수치
```

배포 순서는 게임과 같다. 소스를 커밋한다 → `deploy.sh`(version.json에 소스 커밋이 찍힌다) →
`docs/momonium-experiments/`를 커밋·push한다 → 공개 URL에서 `e2e.sh`를 돌린다.

## 실험을 만드는 법

1. `experiments/<id>/<id>.gd`에 `extends LabExperiment`(`lab/experiment.gd`)를 쓴다. 틀이 부르는 것은 다음과 같다.
   - `tick(dt)`: 플레이 시간. 숨김·포커스 잃음이면 멈추고, 한 번에 0.25초를 넘지 않는다. 경제는 **이것으로만** 움직인다.
   - `hud()`: 보이는 자원 하나, `{value, rate, icon}`.
   - `action_info()`/`do_action()`: 버튼 하나, `{label, cost, affordable, icon}`. 살 수 없는 누름은 틀이 거절하고 기록한다.
   - `state()`/`dev(name, arg)`: 테스트와 `window.funlab`용.
   - 기록에는 `session.action()`(탭 같은 입력), `session.upgrade()`, `session.milestone()`, `session.metric()`을 쓴다.
2. `lab/registry.gd`에서 그 실험의 `script`를 채운다. 그러면 타일이 PLAY가 된다.
3. 터치 하나는 누름 하나다. 실험실은 터치를 마우스 사본으로만 받는다(`LabApp._input`).
   월드 탭을 직접 받는 실험은 `InputEventMouseButton`만 센다.

## 기록 (로컬 전용)

실행마다 `LabSession`이 메모리에 남긴다. 서버로 보내지 않고 디스크에도 쓰지 않는다.

- **플레이 시간**: 페이지가 보이고 포커스가 있을 때만 흐른다. 숨긴 탭이나 다른 창으로 가면 멈추고, 돌아와도 따라잡지 않는다.
- **행동**: 탭·버튼 누름(종류별 횟수, 시각), 살 수 없을 때의 누름(`button_refused`).
- **업그레이드**: 시각·레벨·비용, 첫 업그레이드까지의 시간, 업그레이드 사이 간격.
- **마일스톤**: 실험이 정한 큰 변화.
- **쉰 구간**: 5초 이상 아무 입력이 없던 구간. 첫 입력 전과 마지막 입력 뒤도 센다. 합계와 가장 긴 구간.
- **3·15·30분 시점 요약**: 플레이 3:00·15:00·30:00에 그때의 요약과 FPS를 얼려 둔다(`at_3min`·`at_15min`·`at_30min`, 뒤의 둘은 Step 94).
- **분당 행동 수와 가장 긴 업그레이드 대기**(Step 94): `actions_per_minute`, `longest_upgrade_wait_s`(아직 열린 대기 포함). 실행 번호 `run`과 대안 `variant`.
- **계속할 마음**(Step 89): 플레이 3:00에 버튼 바로 위에 작은 카드가 뜬다("Keep playing?", F는 "See the next tree?").
  Yes / Not now로 답하고, 20초 안에 답이 없으면 `none`이다. 답은 `metrics.continue_intent`에 남고 플레이를 멈추지 않는다. 답하는 탭은 행동으로 세지 않는다.
- **실험의 숫자**(`metrics`): 레벨, 자원, 수입률 등.

`?dev=1`의 기록 창에서 `funlab-<id>-<시각>.json`과 `.csv`를 받는다. CSV는 사건 한 줄에 한 행이고, 끝에 요약 행이 붙는다.
콘솔에서 `funlab.call('summary')`로도 읽을 수 있다.

## 시험 방법 (편향을 줄이기 위해 설명 없이)

**설명하지 않는다.** 실험 이름과 "3분 동안 해 보세요"만 말한다. 무엇을 누르는지, 무엇이 목표인지는 말하지 않는다.

1. 시험할 실험의 직접 링크를 `?dev=1`로 연다. 예: `…/momonium-experiments/?dev=1#island`
2. **첫 30초**: 손을 대기 전에 무엇을 하는 게임인지 짐작해 적는다. 30초 동안 무엇을 했는지, 처음 누른 것이 무엇인지 본다.
   기록의 첫 쉰 구간과 첫 업그레이드 시각이 이것을 숫자로 남긴다.
3. **3분**: 틀의 시계가 3:00이 될 때까지 계속한다. 멈추고 싶어진 순간이 있으면 그 시각을 적는다.
4. 3:00에 비교 페이지(또는 바로 아래 점수표)에서 점수를 매기고, 기록 창에서 JSON을 받는다. 해 보지 않은 실험은 '안 해 봄'으로 둔다(0점이 아니다).
5. 다른 실험은 다시 시작한 상태에서 연다. 순서를 바꿔 가며 시험한다(먼저 한 실험이 기준이 되지 않게).

## 점수표 (1–5)

| 항목 | 질문 |
|---|---|
| 직관 | 설명 없이 무엇을 해야 할지 알았나? (1 전혀 모름 – 5 바로 앎) |
| 업그레이드의 기쁨 | 업그레이드한 순간이 기분 좋았나? (1 아무 느낌 없음 – 5 매번 좋음) |
| 다음 변화가 궁금함 | 다음에 무엇이 될지 보고 싶었나? (1 아니 – 5 아주) |
| 3분 뒤 계속 | 3분에서 멈추라고 하면 아쉬운가? (1 아니 – 5 아주) |

| 실험 | 시험자 | 날짜 | 직관 | 기쁨 | 다음 | 계속 | 기록 파일 | 메모 |
|---|---|---|---|---|---|---|---|---|
| A Island Growth | | | | | | | | |
| B Momo Evolution | | | | | | | | |
| C Break & Upgrade | | | | | | | | |
| D Harvest Burst | | | | | | | | |
| E Production Tycoon | | | | | | | | |
| F Endless Growth | | | | | | | | |

사람이 매긴 점수만 이 표에 적는다. 개발 중 자동 시험(봇·E2E)으로 잰 숫자는 `LOG.md`에 따로, 그렇다고 밝혀서 적는다.
