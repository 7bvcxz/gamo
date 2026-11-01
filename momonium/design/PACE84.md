# 생산 3배 빠르게 (Step 84)

Step 78은 건물의 일·기다림·건설을 5배 늦췄습니다. 주인이 완전 초기화한 섬으로 직접 해 보니 **지금 게임이 너무 느렸습니다.**
요청은 **지금(Step 78)보다 세 배 빠르게**였고, 증분 게임의 방향을 되돌리는 것은 아니었습니다.

## 1. 바꾼 것: 숫자 셋

`data/balance.json`의 `pace.production` 세 값을 **5 → 5/3**(1.6666666666666667)으로 바꿨습니다.

| 타이머 | 적용하는 한 곳 | Step 78 | Step 84 |
|---|---|---|---|
| 단계의 일(손·모모·자동·연구소·제련·스튜디오) | `BuildingSystem.work_scale()` = `work_scale` 6.25 × `production.work` | 데이터 초 ×31.25 | ×10.42 |
| 단계 뒤 기다림(물 준 작물이 익음, 기장 자람, 광석 가라앉음, 묘목 뿌리내림, 화로 식음) | `wait_scale()`, `stage_cooldown`(바닥 포함) | ×5 | ×1.67 |
| 건설 | `build_scale()` = `build_scale` 2.5 × `production.build` | ×12.5 | ×4.17 |

- 옛 `work_scale`(6.25)·`build_scale`(2.5)은 그대로입니다. 한 단계는 여전히 한 번만 곱해지고, 모모·플레이어(Step 83의 손)·자동 일이 두 번 곱하지 않습니다.
- 바닥(floor)은 자기 타이머와 함께 움직입니다(연구가 아무리 강해도 Step 78 바닥의 3분의 1).
- **그대로인 것:** 걷기, 하루(30초), 연구 주제의 시간, 편지, 애니메이션 FPS, 화면 전환, 로딩, 가격, EXP, 보상, 손 셋(Step 83), 연구·모모 숙련·시계탑·RP·Prestige의 효과.
- 오프라인 진행은 Step 79대로 꺼져 있습니다.

## 2. 실제 시뮬레이터 타임스탬프: Step 78 → Step 84

`tools/pace84_table.gd`가 장면마다 Step 78 게임(세 값 5)과 지금 게임을 시뮬레이션 시간으로 돌려, 시작·완료·다시 준비의 순간(첫 행동부터 ms)을 적습니다.
- 모모는 걷는 시간을 뺀 자기 단계의 길이입니다.
- 각 타이머는 정수 ms로 반올림하므로 비율은 소수 넷째 자리까지 0.3333입니다.

| Scene | Event | Step 78 (ms) | Step 84 (ms) | Ratio |
|---|---|---:|---:|---:|
| Farm (by hand) | sow starts | 0 | 0 | - |
| Farm (by hand) | sow done | 31250 | 10417 | 0.3333 |
| Farm (by hand) | water starts | 31250 | 10417 | 0.3333 |
| Farm (by hand) | water done | 62500 | 20834 | 0.3333 |
| Farm (by hand) | ready again (after the wait) | 72500 | 24167 | 0.3333 |
| Farm (by hand) | harvest starts | 72500 | 24167 | 0.3333 |
| Farm (by hand) | harvest done | 103750 | 34584 | 0.3333 |
| Millet farm (by hand) | sow starts | 0 | 0 | - |
| Millet farm (by hand) | sow done | 31250 | 10417 | 0.3333 |
| Millet farm (by hand) | ready again (after the wait) | 61250 | 20417 | 0.3333 |
| Millet farm (by hand) | harvest starts | 61250 | 20417 | 0.3333 |
| Millet farm (by hand) | harvest done | 92500 | 30834 | 0.3333 |
| Millet farm (by hand) | sow starts | 92500 | 30834 | 0.3333 |
| Millet farm (by hand) | sow done | 123750 | 41251 | 0.3333 |
| Millet farm (by hand) | ready again (after the wait) | 153750 | 51251 | 0.3333 |
| Mine (by hand) | dig starts | 0 | 0 | - |
| Mine (by hand) | dig done | 125000 | 41667 | 0.3333 |
| Mine (by hand) | ready again (after the wait) | 155000 | 51667 | 0.3333 |
| Mine (by hand) | dig starts | 155000 | 51667 | 0.3333 |
| Mine (by hand) | dig done | 280000 | 93334 | 0.3333 |
| Mine (by hand) | ready again (after the wait) | 310000 | 103334 | 0.3333 |
| Lumberyard (by hand) | chop starts | 0 | 0 | - |
| Lumberyard (by hand) | chop done | 125000 | 41667 | 0.3333 |
| Lumberyard (by hand) | replant starts | 125000 | 41667 | 0.3333 |
| Lumberyard (by hand) | replant done | 187500 | 62500 | 0.3333 |
| Lumberyard (by hand) | ready again (after the wait) | 237500 | 79167 | 0.3333 |
| Lumberyard (by hand) | chop starts | 237500 | 79167 | 0.3333 |
| Lumberyard (by hand) | chop done | 362500 | 120834 | 0.3333 |
| Lab (by hand) | study starts | 0 | 0 | - |
| Lab (by hand) | study done | 93750 | 31250 | 0.3333 |
| Lab (by hand) | ready again (after the wait) | 123750 | 41250 | 0.3333 |
| Lab (by hand) | study starts | 123750 | 41250 | 0.3333 |
| Lab (by hand) | study done | 217500 | 72500 | 0.3333 |
| Lab (by hand) | ready again (after the wait) | 247500 | 82500 | 0.3333 |
| Smelter (by hand) | smelt starts | 0 | 0 | - |
| Smelter (by hand) | smelt done | 312500 | 104167 | 0.3333 |
| Smelter (by hand) | ready again (after the wait) | 337500 | 112500 | 0.3333 |
| Smelter (by hand) | smelt starts | 337500 | 112500 | 0.3333 |
| Smelter (by hand) | smelt done | 650000 | 216667 | 0.3333 |
| Smelter (by hand) | ready again (after the wait) | 675000 | 225000 | 0.3333 |
| Momo at a farm (its stages) | Momo sow (1 of 4) | 31250 | 10417 | 0.3333 |
| Momo at a farm (its stages) | Momo water (2 of 4) | 31250 | 10417 | 0.3333 |
| Momo at a farm (its stages) | Momo harvest (3 of 4) | 31250 | 10417 | 0.3333 |
| Momo at a farm (its stages) | Momo sow (4 of 4) | 31250 | 10417 | 0.3333 |
| Drip line (automatic watering) | automatic water | 18750 | 6250 | 0.3333 |
| Researched farm (water, ripening) | watering (researched) | 18750 | 6250 | 0.3333 |
| Researched farm (water, ripening) | ripening (researched) | 7500 | 2500 | 0.3333 |
| Clock Tower burst (a chop) | chop outside a burst | 125000 | 41667 | 0.3333 |
| Clock Tower burst (a chop) | chop in a burst | 62500 | 20833 | 0.3333 |
| Construction | farm built | 37500 | 12500 | 0.3333 |
| Construction | mine built | 100000 | 33333 | 0.3333 |
| Construction | lumberyard built | 62500 | 20833 | 0.3333 |
| Construction | research built | 62500 | 20833 | 0.3333 |

## 3. 페이스 시뮬레이션(봇, 'blind' 프로필, 300분)

같은 코드(Step 83 손 셋 포함)에서 세 값만 5와 5/3으로 바꿔 쟀습니다(`tools/balance_optimizer/optimize.gd --profile blind --minutes 300`).
- 걷기·하루·연구 주제·편지는 그대로이므로 전체로는 약 2.4배 빨라집니다(3배가 아님).
- 새 기준선은 `tools/balance_optimizer/baseline_step84.json`이고, `test_balance`가 이것을 씁니다. `baseline_step78.json`·`baseline_step69.json`은 이력입니다.

| 이정표 | Step 78 | Step 84 | 비율 |
|---|---:|---:|---:|
| 첫 수입 | 39 s | 18 s | 0.47 |
| 모모의 첫 수입 | 168 s | 95 s | 0.57 |
| Lv 2 | 663 s | 274 s | 0.41 |
| 첫 연구 | 1200 s | 488 s | 0.41 |
| 땅 첫 구입 | 1000 s | 400 s | 0.40 |
| 모모 2 | 1576 s | 668 s | 0.42 |
| Lv 5 | 4795 s | 2075 s | 0.43 |
| 도시(tier 1) | 4420 s | 1944 s | 0.44 |
| 섬 판매 가능 | 218 분 | 90 분 | 0.41 |
| 10분까지 번 돈 | $48 | $174 | 3.6배 |
| 1시간까지 번 돈 | $1001 | $5834 | 5.8배 |

## 4. 이미 진행 중인 단계(옛 세이브)

- 시작된 단계는 **저장된 끝 시각(`task_end`, `ready_at`, `build_end`)을 그대로** 지킵니다. 업데이트 뒤에 시작하는 단계부터 새 시간입니다.
- 재료 손실, 보상 중복, 갑작스러운 완료, 섬 초기화, 스키마 변경은 없습니다.
- 새 플레이어는 곧바로 빠른 주기를 봅니다. 새 섬의 익은 밭은 첫 탭에 10.4초 동안 수확합니다(E2E가 진짜 첫 섬으로 확인).

## 5. 함께 고친 것

- **밀리초 반올림.** 5/3에서는 한 단계가 10.4167초이고, 게임은 10417 ms로 반올림합니다. 그런데 테스트 22곳과 E2E 질의 `rules`(`farm_stages`·`farm_wait_ms`·`farm_build_ms`·`build_ms`·`stages_ms`)가 `int()`로 잘라 10416 ms를 기다렸습니다. 그래서 단계가 1 ms 모자라게 끝나지 않았습니다.
  - Step 78의 31.25초(31250 ms)는 정수라 드러나지 않았던 것입니다.
  - 테스트는 `ms()`(게임과 같은 반올림), 질의는 `round`로 고쳤습니다.
  - 개조(refit)의 건설 타이머도 잘라내고 있었는데(설치는 반올림), 같은 반올림으로 맞췄습니다.
- 데모 섬 미리 돌리기(`DemoWorld.build`)는 '데이터 페이스의 30분 × production.work'로 데이터에서 읽습니다. Step 78에서는 ×5로 적혀 있었습니다.
- 벤치 해시 2556685979 → 4096964579(같은 한 시간에 사건 31,486 → 100,189, 규칙 변경). `tools/bench/budgets.json`의 `_doc`에 적었습니다.

## 6. 확인

- `tests/unit/buildings/test_production_pace84.gd`(8): 손으로 밭(씨·물·익음·수확, 손 주기 34.58초), 기장, 광산, 목재소(뿌리내림), 연구소, 제련소, 모모(9분의 1이 아님), 드립 라인, 연구·시계탑(한 번), 바닥, 건설이 모두 Step 78의 3분의 1(반올림 ±4 ms)입니다. Step 78 세이브의 진행 중 단계는 끝을 지키고, 다음 단계는 새 시간입니다. 걷기·하루·연구 주제·편지·가격·손 셋은 그대로입니다.
- `tests/unit/buildings/test_production_pace.gd`는 **이력**입니다. Step 78 데이터(세 값 5)를 0.77과 비교해 Step 78의 관계를 그대로 지킵니다.
- `tests/unit/buildings/test_pace.gd` 등 지금 게임의 값을 말하는 테스트는 Step 84 값으로 고쳤습니다(손 주기 103.75 → 34.58초, 광산 155 → 51.7초/개, Lv 2 창 6.25~37.5분 → 2.1~12.5분).
- E2E `tests/e2e/specs/pace84.spec.mjs`(Step 78의 `pace78.spec`을 대신함)
  - 진짜 탭 씨뿌리기 10.4초(11초부터 카운트다운, 1 ms 전에는 안 끝남), 손 주기 '35 s'
  - 물 뒤 익음 3.3초(4초부터 카운트다운, 10 ms 전 거부, 수확 전 돈 없음), 건설 12.5초
  - 진짜 첫 섬의 첫 수확 10417 ms, 수확 중 저장 → 새 탭으로 열면 같은 끝 시각에 한 번 완료
