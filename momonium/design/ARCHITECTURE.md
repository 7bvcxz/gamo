# Momonium 아키텍처 가이드

짧게: **시뮬레이션은 화면을 모르고, 화면은 시뮬레이션을 읽기만 한다.** 바꾸는 길은 명령 하나,
알리는 길은 이벤트 버스 하나, 시간이 흐르는 길은 스케줄러 하나다.

## 흐름

```
 입력(터치·마우스) ──► InputRouter ──► sim.execute({type: ...}) ──► SimSystem.execute
                                                                  │
 프레임 루프 ──► sim.advance_seconds(Δ) ──► Scheduler(시각, 순번) ──► SimSystem.handle_event
                                                                  │
                         뷰·HUD·오디오·통계 ◄── EventBus.emitted(type, payload) ◄┘
                         (상태는 sim에서 직접 읽는다 — 쓰지 않는다)
```

## 모듈

| 폴더 | 층 | 책임 |
|---|---|---|
| `src/core` | 로직 | `SimClock`(유일한 시간), `Scheduler`(이벤트 힙), `EventBus`, `SimResult` |
| `src/data` | 로직 | `GameData` — `data/*.json` 로드·검증. 수치와 표는 전부 여기 |
| `src/sim` | 로직 | `Simulation`(조립·시간·명령·저장), `SimSystem`(시스템 기반), `SystemRegistry`(순서) |
| `src/world` | 로직 | 격자·땅·점유 (Step 05~) |
| `src/economy` | 로직 | 돈·창고·판매 |
| `src/progression` | 로직 | 레벨·EXP·숙련도·해금 |
| `src/research` | 로직 | `ResearchSystem` — 연구 트리·해금·진행, 효과는 `BuildingSystem.modifiers`로(작업·기다림 배율, 수확 보너스) |
| `src/agents` | 로직 | 모모(에이전트)·작업 스케줄링(`JobSystem`)·모모 편지(`MailSystem`)·매니저 |
| `src/persistence` | 로직 | 저장 형식·버전·이주·원자적 쓰기 |
| `src/power` | 로직 | `PowerSystem` — 발전(태양·바람·증기·수력)·사용·공급 비율, `BuildingSystem.modifiers`로 작업 속도와 시작 차단 |
| `src/render` | 표현 | 섬·바다·하늘·건물 그리기, 깊이 정렬 |
| `src/input` | 표현 | 카메라, 제스처, 입력 라우터 |
| `src/ui` | 표현 | HUD, 패널, 문구 |
| `src/actors` | 표현 | 모모 스프라이트·리그·애니메이션 |
| `src/audio` | 표현 | 음악·효과음 서비스 |
| `src/app` | 표현 | `main.gd` — 조립 루트와 프레임 루프 |
| `src/platform` | 표현 | 웹 브리지 등 플랫폼별 |

**의존 방향은 표현 → 로직 한쪽뿐이다.** 로직 폴더의 스크립트는 노드가 아니며(`RefCounted`),
`Input`·`get_tree()`·`JavaScriptBridge` 같은 화면/플랫폼 API와 표현 쪽 클래스를 부르지 않는다.
`tests/unit/test_architecture.gd`가 소스를 읽어 이것을 검사한다.

## 규칙

- **싱글턴(autoload)을 두지 않는다.** `main.gd`가 `Simulation`을 만들고 각 뷰에 `setup(sim)`으로
  넘긴다. 테스트는 원하는 데이터·시스템으로 자기만의 `Simulation`을 만든다. (테스트가 autoload
  부재를 검사한다.)
- **시간은 `SimClock.now_ms`(정수 ms) 하나.** 프레임 수나 벽시계를 읽어 규칙을 정하지 않는다.
  미래의 일은 `sim.schedule_in(지연, 타입, 데이터)`로 예약하고, 예약은 순수 데이터라 그대로 저장된다.
  같은 명령을 같은 시각에 주면 프레임을 어떻게 나눠도 같은 세계가 된다(테스트가 16ms·17ms·1s·95s
  조각으로 비교한다). 오프라인 진행(Step 24)은 `advance_to(지금)` 한 번이다.
- **취소는 토큰으로.** 예약된 이벤트는 지우지 않는다. 주인이 토큰을 들고 있다가 맞지 않는 이벤트를 무시한다.
- **명령의 답은 `{ok, reason, ...}`.** `reason`은 문장이 아니라 번역 키(`err.not_enough_money`)다.
- **시스템 사이 호출은 직접, 바깥으로는 버스로.** 시스템 안에서의 순서가 규칙의 일부이기 때문이다
  (하루가 바뀔 때 판매가 생산보다 먼저 본다 등 — `SystemRegistry`의 순서).
- **시스템은 `sim`을 약하게 참조한다.** `Simulation`이 시스템을 소유하므로 강한 역참조는 해제되지
  않는 순환이 된다. 같은 이유로 `sim.bus`에 연결하는 람다는 `sim`을 붙잡지 않는다(필요하면 `sim.clock`처럼
  sim이 소유한 하위 객체만 붙잡는다) — 버스는 sim의 것이라 sim → 버스 → 람다 → sim 순환이 된다.
- **수치는 데이터에.** 비용·시간·해금·확률은 `data/*.json`에 두고 `GameData`가 검증한다. JSON의 숫자는
  실수로 읽히므로 `get_int`·`get_float`·`get_vec2i`로 꺼낸다. 새 표는 `GameData.TABLES`에 등록해야
  로드되고, 등록하지 않은 파일은 테스트가 실패시킨다.
- **돈은 정수 달러.** 비율 효과는 명시적으로 내림한다.
- **UI는 한 뿌리 아래.** 모든 UI 컨트롤은 `UI`(CanvasLayer) 밑의 `Root` 컨트롤 아래에 있고, `Root`가 HUD와
  같은 `Theme` 객체를 쓴다. CanvasLayer는 테마를 물려주지 않아서, 예전에는 HUD 밖 패널이 엔진 기본 회색
  상자와 기본 폰트(한글·가나 없음)로 그려졌다 — 데스크톱은 시스템 폰트가 메워 줘서 안 보였고 웹에서만 깨졌다.
- **더 보여 줄 것은 `PanelFrame`으로.** 카드·흐린 막·닫기·탭이 한 가지 모양이고, 본문은 `refresh()`가 있는
  작은 뷰(`StatusPanel`·`InventoryView`·`EconomyView`·`StatsView`·`BuildingDetailView`)다. 뷰는 값을 들고
  있지 않고 그릴 때마다 시스템에서 읽는다. 프레임은 시뮬레이션 사건마다, 그리고 초당 4번 보이는 뷰만 새로 그린다.
  프레임은 HUD 아래 층이라 열려 있어도 모서리 버튼이 눌린다.
- **설정은 섬과 따로**(`SettingsStore`): 언어, 튜토리얼 본 여부. `user://momonium_settings.json` + 웹 localStorage.
- **체험 섬**(`DemoWorld`): 실제 명령과 시간으로 만든 중반 섬. `Engine` 메타 `momonium_demo`로 장면을 다시 불러
  들어가고 나오며(메타는 장면 재로드를 넘어 남는다), 그동안 `persist`는 꺼진다.
- **튜토리얼**(`ui/Tutorial`): HUD 위 오버레이. 단계는 상태가 아니라 계산이다(`current_step()`이 세계와 화면을 본다).
  새 섬 + 처음 + 데모 아님 + 브라우저 테스트 아님(테스트는 `window.MOMONIUM_E2E_TUTORIAL`로 켠다)일 때만 스스로 시작.
- **화면에 쓰는 기호는 폰트에 있어야 한다.** UI 폰트는 언어별 서브셋이라 "✕" 같은 기호가 없다. 닫기 표시는
  그린다(`PanelViews.close_button`). `test_locale`이 UI 코드의 문자열 리터럴을 훑어 확인한다.

## 저장

- **봉투**: `{format: "momonium", schema, saved_unix, checksum, state}`. `state`는 시뮬레이션 상태의 JSON 문자열,
  `checksum`은 그 SHA-256 — 잘리거나 고친 파일을 알아본다. 스키마가 오르면 `SaveMigration`에 한 단계씩 더한다.
- **원자적 쓰기**: `.tmp`에 쓰고 → 지금 저장을 `.bak`으로 → `.tmp`를 제자리로. 어느 순간 죽어도 둘 중 하나는 온전.
  읽을 때 저장 → 백업 순. 손상된 파일은 `.corrupt`로 남기고, **더 새 버전의 저장은 읽지도 덮어쓰지도 않는다**.
- 게임은 15초마다, 창이 포커스를 잃을 때, 닫힐 때 저장한다. 테스트 러너와 캡처 도구는 `Engine` 메타
  `momonium_no_save`로 저장을 끈다(한 테스트의 저장이 다음 테스트의 세계가 되지 않게).
- **오프라인 진행**(`OfflineProgress`): 떠나 있던 시간만큼 시뮬레이션을 그대로 진행한다 — 열어 둔 채 아무도 손대지
  않은 것과 똑같다(배치된 모모·점적 관개·기다림·연구·하루 판매, 창고 한도·쿨다운 그대로). 사람 몫의 일은 대신하지
  않는다. 상한 둘: 시간 `offline.max_hours`(8), 이벤트 `offline.max_events`(40,000 — 시계는 마지막으로 처리한
  이벤트에서 멈춘다). 둘 다 결정적이라 같은 저장은 같은 순간에 멈춘다. 시계가 거꾸로 가면 아무것도 주지 않는다.
  숨겨진 탭이 그리지 않은 시간도 같은 방법으로 따라잡는다.


`sim.save_state()`는 `{schema, clock, scheduler, systems: {키: 상태}}` 형태의 순수 Dictionary이며 JSON
왕복이 가능하다. 각 시스템이 자기 상태만 `save_state`/`load_state`한다. 스키마·이주·원자적 쓰기는
`src/persistence`(Step 24)가 맡는다.

## 테스트 층

| 층 | 위치 | 언제 |
|---|---|---|
| unit | `tests/unit` | 로직 단위. 매 step 전체 실행 (`tools/test.sh`) |
| integration | `tests/integration` | 씬을 띄우고 실제 입력 이벤트를 보낸다. 매 step 전체 실행 |
| E2E | `tests/e2e/specs` | 브라우저에서 웹 빌드를 조작. **Step 10·20·30·40에서만 전체 실행** |
| 스모크 | `tests/e2e/smoke.mjs` | 배포마다. 로드·프레임·버전·탭 한 번 |
