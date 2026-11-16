# AUTOMATION_PLAN — 기계 40종과 그 실행기 (Step 13 → 구현 Step 26–33)

## 1. 원칙 [confirmed]

- 기계는 **실제로 일한다**: 입력을 먹고 출력을 내고, 옮기고, 고르고, 시간을 바꾼다. 어딘가에 '+10%'를 곱하는 수동 항목은 기계가 아니다.
- 40종은 다섯 무리 × 8종이다. 한 종은 다른 종과 **다른 동작**을 가져야 한다(같은 동작에 숫자만 다르면 한 종으로 친다).
- 켜진 기계는 활동 시간 1초마다 유지비를 낸다. 돈이 모자라면 멈추고, 돈이 생기면 다시 켜진다(`FACTORY_FLOW` 7절).
- 손은 '선택한 줄에 잠깐 더 좋은 질/속도'를 주는 개입이다. 기계 40대를 하나하나 돌보지 않아도 공장이 돈다.
- 같은 단계에서 기초 자동 냄비 하나는 손의 완벽한 팝 하나보다 시도당 덜 만든다. 대신 쉬지 않고 여럿이 함께 돈다.

## 2. 데이터 모양 (Step 26)

카탈로그 행(`data/factory.json` → `machines`):

```json
{ "id": "M01", "name": "Kernel Hopper Loader", "group": "make_basic", "floor": "bottom",
  "slot": 1, "cost": 400, "upkeep_mc_per_s": 50, "cycle_ms": 2000,
  "needs": [], "unlock": { "cooker": 3 }, "effect": { "kind": "feed_kettle", "portions": 2 } }
```

인스턴스(저장됨): `{uid, id, slot, tier, on, paid_mc, cycle_ms_left, holding, state}` — `state`는 `run | idle_starved | idle_blocked | unpaid | off`.

- 칸(slot): 층마다 정해진 자리. 고스트 실루엣이 빈 칸을 보여 준다. 기계는 자기 칸에서만 일한다.
- 처리: 50ms 고정 걸음마다 켜진 기계를 정해진 순서(층 아래→위, 칸 번호)로 처리한다. 순서가 결과를 정하므로 결정적이다.

## 3. 조작 (Step 26, 33) [confirmed]

- 칸을 누르면 그 칸의 살 수 있는 기계 2–3개만 보인다. 산 기계를 누르면: 켜기/끄기, 다음 단계, 지금 하는 일(아이콘).
- 층 단위 '모두 끄기/켜기' 하나. 40행 표는 없다.
- 위쪽에 세 수(만든·포장한·판 봉지/분), 막힌 층 표시, 순이익/분(판매 − 유지비).

## 4. 40종 (Step 27에서 수치·칸·선행 조건을 확정)

> **Step 27(0.27.0)에서 확정**: 단일 원본은 `data/machines.json`, 읽는 표는 생성 문서 `design/MACHINES.md`(층·자리·움직임·계약·입출력·제약·선행·필요한 체계·값·유지비·단계·한계 이익·상태), 그림은 게임 안 `#machines`. 아래 표는 처음 계획(Step 13)이며 이름과 동작은 그대로 이어졌다.

### 제조 기초 M01–M08 (아래층, Step 28)
| ID | 이름 | 다른 동작 |
|---|---|---|
| M01 | Kernel Hopper Loader | 자동 냄비에 낟알을 채운다 — 없으면 자동 냄비가 굶는다 |
| M02 | Precision Oil Doser | 기름을 재서 넣는다: 자동 냄비의 품질 분포를 '좋음' 쪽으로 옮긴다(기름을 소모 = 유지비) |
| M03 | Heat Controller | 자동 냄비의 판정을 일정하게: '탐'이 나오지 않는다 |
| M04 | Agitation Motor | 자동 흔들기: 자동 냄비의 묶음이 고르게(+인분). 0.12.x 모터의 후손 |
| M05 | Pop Detector | 자동 냄비가 '늦음' 대신 제때 꺼낸다(등급 분포에서 늦음 제거) |
| M06 | Batch Ejector | 냄비 유리 → 원료 통으로 옮기는 시간을 없앤다(손 냄비 포함: 유리 대기 단축) |
| M07 | Dual Kettle Sequencer | 자동 냄비 둘을 엇갈려 돌린다(두 번째 냄비 칸을 연다) |
| M08 | Cooling/Recovery Fan | 손·자동 냄비의 식는 시간을 줄인다 |

### 제조 고급 M09–M16 (아래층, Step 29)
| ID | 이름 | 다른 동작 |
|---|---|---|
| M09 | Kernel Sorter | 덜 익은 낟알을 골라 다시 돌린다: '덜 익음' 묶음의 품질↑, 인분 약간↓ |
| M10 | Multi-Pot Distributor | 원료를 여러 냄비에 나눠 보낸다(냄비 줄 3–4 지원) |
| M11 | Quality Sensor | 묶음을 품질로 나눠 두 통에 담는다(좋은 것은 비싼 봉지로) |
| M12 | Flavor Base Mixer | 맛 바탕을 미리 섞어 둔다(맛이 열리기 전에는 잠들어 있다) |
| M13 | Vent Stabilizer | 여러 냄비가 함께 돌 때 생기는 '과열 멈춤'을 없앤다 |
| M14 | Heat Recycler | 냄비들의 유지비를 줄인다(돌고 있는 냄비가 있을 때만) |
| M15 | Smart Job Dispatcher | 선반에 모자란 맛/크기를 보고 냄비 일감을 고른다 |
| M16 | Rotary Popper | 큰 연속 냄비: 작은 묶음을 쉬지 않고 낸다(자동 냄비의 다른 형태) |

### 포장 P01–P08 (가운데층, Step 30)
| ID | 이름 | 다른 동작 |
|---|---|---|
| P01 | Cup Feeder | 컵을 대 준다 — 포장대의 주기에서 '용기 대기'를 없앤다 |
| P02 | Bag Dispenser | 큰 봉지(M/L)를 대 준다 — 큰 크기 포장을 연다 |
| P03 | Volumetric Filler | 부피로 담는다: 빠르지만 인분이 들쭉날쭉(품질↓ 약간) |
| P04 | Portion Weigher | 무게로 담는다: 느리지만 정확(넘친 인분을 통에 돌려준다) |
| P05 | Seasoning Sprayer | 가루 양념(치즈·매콤)을 입힌다 — 맛 SKU를 만든다 |
| P06 | Caramel Coater | 카라멜·코코아 코팅 — 느린 맛 SKU를 만든다 |
| P07 | Auto Sealer | 봉하기를 따로 해서 포장 줄 둘이 함께 돌게 한다 |
| P08 | Package Conveyor Diverter | 봉지를 맛별 선반 칸으로 나눠 보낸다(섞이지 않게) |

### 가게 S01–S08 (위층, Step 31)
| ID | 이름 | 다른 동작 |
|---|---|---|
| S01 | Pickup Belt | 선반 → 계산대로 봉지를 옮긴다: 건네는 시간↓ |
| S02 | Order Ticket Printer | 주문을 미리 받아 맞는 봉지를 예약한다(줄이 길 때 빠름) |
| S03 | Auto Cashier | 계산을 따로: 한 계산대가 둘을 동시에 응대 |
| S04 | Queue Router | 여러 계산대에 손님을 나눈다(줄 2개 이상일 때만 의미) |
| S05 | Express Window | 한 가지 봉지만 사는 손님을 따로 받는 창구(FIFO 예외) |
| S06 | Menu Display Board | 손님이 있는 맛 중에서 고르게 한다: '맞는 봉지 없음' 이탈↓ |
| S07 | Self-Service Kiosk | 직원 없이 파는 칸: 기본 봉지만, 느리지만 줄을 하나 더 |
| S08 | Multi-Lane Serving Robot | 여러 계산대를 오가며 건넨다(줄 4개 이상) |

### 보조 U01–U08 (층을 가리지 않음, Step 32)
| ID | 이름 | 다른 동작 |
|---|---|---|
| U01 | Maintenance Robot | 멈춘(유지비 외 사유) 기계를 다시 돌린다 — 과열·막힘 회복 |
| U02 | Lubrication Station | 이웃 칸 기계의 주기 시간↓(이웃이 있을 때만) |
| U03 | Energy Saver | 쉬는 기계의 유지비를 깎는다(돌고 있을 때는 그대로) |
| U04 | Buffer Lift | 층 사이 버퍼 용량↑(원료 통·선반) — 실제 칸이 늘어난다 |
| U05 | Quality Inspector | 품질 낮은 봉지를 골라 싸게 파는 칸으로(손님 만족↑) |
| U06 | Sanitation Bot | 오래 쌓인 원료의 품질이 떨어지지 않게 한다(원료 노화가 있을 때만) |
| U07 | Demand Scheduler | 소식·손님 선호를 보고 포장 맛 순서를 정한다 |
| U08 | Route Balancer | 막힌 줄의 물건을 한가한 줄로 돌린다 |

## 5. 40대가 동시에 (Step 33)

- 칸 수: 아래층 14, 가운데층 12, 위층 10, 보조 4 이상 → 40칸. 같은 종을 여러 대 놓을 수 있다(자동 냄비 여럿 등). [proposal]
- 낟알 하나하나를 물리로 돌리지 않는다. 논리는 묶음·봉지 단위, 그림은 대표 화물 + 개수. [confirmed]
- 성능 예산은 `QUALITY_GATES`(그리기 호출, 남는 메모리, FPS).

## 6. 열려 있는 질문

- [question] 기계를 되팔 수 있나(값의 일부를 돌려받기)? 시작값: 되팔기 없음, 끄기만.
- [question] 유지비 외에 '고장'을 둘까? 시작값: 두지 않는다(Step 32: 예측 가능하고 되돌릴 수 있을 때만).
