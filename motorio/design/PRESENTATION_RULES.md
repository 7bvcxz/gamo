# PRESENTATION_RULES — 무엇을 어떻게 보여 주는가

상태: `[확정]` · 2026-09-27 · Quality Pass 01

연출의 단일 원본. 새로 무언가를 알려야 할 때, 문구를 쓰기 전에 이 표에서 그것이 어느 종류인지
먼저 고른다. 이 저장소의 방침("글로 설명하지 않는다", `AGENTS.md` 작업 원칙)을 연출의 언어로
옮긴 것이다. 소리는 `AUDIO_DIRECTION.md`.

---

## 한 문장

> 플레이어에게 필요한 정보는 **세계**가 말하고, 그다음 **HUD**가, 마지막에야 **글**이 말한다.
> 화면 가운데 문단은 없다.

## 1. 종류별 언어

| 종류 | 언어 | 구현 | 쓰지 않는 것 |
|---|---|---|---|
| **WORLD PROGRESS** — 세계에서 시간이 걸리는 일 (채굴·제작·조사·해동·잔해) | 그 대상 위에서 **닫혀 가는 링**. 끝나면 짧은 펄스와 불꽃 | `WorldProgress.draw` / `draw_strong`(밝은 바닥 위) / `complete`. MachineLayer의 `_progress_ring` 이 지난다 | 화면 가운데 진행 막대·퍼센트·"만드는 중…" 문구 |
| **IMPORTANT ITEM** — 도구, 에너지 코어처럼 처음 손에 드는 것 | **pop → hover → absorb → chime → hotbar pulse**, 해당되면 곧바로 손에 든다. 0.6~1.2초. 로직은 기다리지 않는다(만든 프레임에 이미 그녀 것이다) | `Main.present_to_hand` → `FxLayer.acquire`, `HUD.pulse_slot`, 소리 `chime`. 무엇이 중요한지는 레지스트리(`presentation: important`, 제작표의 `landing: hand`) | 가운데 팝업 "곡괭이를 얻었습니다" |
| **COMMON ITEM** — 열석·구리처럼 자주 줍는 것 | **quick pickup**: 작은 +N, 작은 링, 짧은 소리 | `fx.popup(…)`, `fx.ring(RING_SMALL)` | 날아오는 연출, 차임 |
| **NEW RECIPE / NEW MACHINE** | 기지 위의 작은 **!**, 작업대·건설 목록의 **NEW** 표시. 새 기계는 **한 줄**("새 설계 · 발전기")과 작은 링 | `MachineLayer._draw_base_alert`, HUD의 NEW 배지, `Main._announce_unlocks` | "해금!" 배너, 마일스톤 링, 화면 흔들림 |
| **BASE UPGRADE** — 불이 한 단계 커짐 | **세계의 애니메이션**: 불이 부풀고 밝아지며, 온기의 가장자리가 새 반경까지 달려 나가고, 불 옆의 **작은 단계 표시**가 새 숫자로 번쩍인다. 불의 소리(`level`). 구석 기록에 한 줄 | `Main._on_base_upgraded`, `MachineLayer.core_pulse`·`level_flash`·`_draw_level_plate` | 불 위에 쌓이는 "기지 N단계"·"열석 +N"·"+N" |
| **WORLD EVENT** — 상자가 기지가 됨, 고양이가 깨어남 | **순서가 있는 작은 사건**: 소리와 부분 동작과 빛이 차례로. 게임플레이 결과(온기)는 첫 프레임부터 진짜이고 **그림만** 따라온다 | `Main._begin_deploy`/`_update_deploy`(걸쇠→펼침→삐걱→불), `Defs.unfold_scale`/`unfold_light`, `_on_cat_thawed` | 오브젝트가 그냥 생기는 것, 팡파르 |
| **SYSTEM ERROR** — 규칙이 막은 것 (설치 불가 등) | **UI 메시지**: 짧게, 무엇이 막혔는지 | `Sim.can_build` 의 이유 → `_on_build_rejected` | 그녀의 생각으로 위장하기 |
| **GRIM THOUGHT** — 그 밖에 그녀가 알아차리는 것 | **짧고 자연스러운 생각**, 반말 평서. "~하세요/~습니다" 안내문이 아니다. 숫자는 꼭 필요할 때만 | `Main._notify(…)` → 좌하단 기록 | "기지에서 2칸 내에 내려놓아야 합니다" |

## 2. 문장 예

| 나쁨 | 좋음 |
|---|---|
| 기지에서 2칸 내에 내려놓아야 합니다. | 기지 가까이에 두면 녹을 것 같다. |
| 열석이 3개 더 있어야 한다. | 불이 아직 받아들이지 않는다.  열석이 3개 더 필요하다. |
| 채굴기 해금! | 새 설계  ·  채굴기 |
| 고양이들이 숙소로 돌아옵니다 | 고양이들이 돌아온다 |
| 횃불: 주변 2칸 시야, 30초 보온 | 들고 있으면 주변이 조금 밝아지고 따뜻하다.  오래가지는 않을 것 같다. |

## 3. 시간과 조작

- **연출이 플레이어를 죽이지 않는다.** 깨어나는 동안(`Defs.WAKE_*`)에는 체온이 줄지 않고 조작이
  잠긴다. 기지가 펼쳐지는 동안 온기는 이미 진짜다.
- **길게 잡지 않는다.** 깨어나기 2.7초, 기지 펼침 0.9초, 중요한 물건 0.74초, 침대에서 내려오기 0.6초.
- **일을 한 홀드는 탭이 아니다.** Z를 누르고 있어서 무언가가 진행됐다면(채굴·상자 조사·잔해·해동),
  그 Z를 떼는 것은 새 동작이 아니다(`mine_swung`). 떼는 순간 앞에 있는 것에 반응하면 방금 생긴
  것(기지)의 창이 열린다.
- **HUD는 그녀가 일어선 뒤에** 페이드인한다(`HUD_REVEAL_SECONDS`). 첫 프레임부터 모든 판이 떠
  있을 필요는 없다.

## 4. 재사용할 부품

| 부품 | 어디 | 쓰는 곳 |
|---|---|---|
| 월드 진행 링 | `WorldProgress.draw` / `draw_strong` / `complete` | 채굴, 제작, 상자·잔해 조사, 땅·고양이 해동 |
| 중요한 물건 획득 | `Main.present_to_hand` → `FxLayer.acquire` | 곡괭이, 건물건설총, 횃불, 에너지 코어 |
| 핫바 펄스 | `HUD.pulse_slot` | 획득 연출의 끝 |
| 짧은 알림 (한 줄) | `Main._notify` → 좌하단 기록 (최대 4줄) | 생각, 새 설계, 기록 |
| 쓰러짐/일어남 자세 | `PlayerActor.collapse` + `Defs.wake_pose` | 동결, 추락 후 깨어나기, 침대에 눕기·일어나기 |
| 기지 펄스·단계 표시 | `MachineLayer.core_pulse`, `level_flash`, `_draw_level_plate` | 기지 강화 |
| 펼침 | `MachineLayer.core_unfold`, `Defs.unfold_scale`/`unfold_light` | 긴급기지 전개 |

## 5. 확인하는 법

- 테스트: `test_wake`, `test_deploy`, `test_presentation_progress`, `test_presentation_upgrade`,
  `test_night_sleep` (각각이 지키는 것은 `TESTS.md`).
- 그림: `tools/presentation_capture.gd`가 실제 게임의 첫 몇 분을 두 창 크기로 찍는다(`TESTS.md`의
  명령). Visual North Star(`design/reference/motorio-visual-north-star.png`)는 목표 그림이고, 이것은
  지금의 게임이다.
