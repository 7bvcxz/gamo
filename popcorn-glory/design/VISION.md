# VISION — 팝콘 공장 (Step 13, #126)

> 이 문서와 같은 폴더의 `CORE_LOOP`·`FACTORY_FLOW`·`STATIONS`·`AUTOMATION_PLAN`·`ART_DIRECTION_BRIEF`·`PROGRESSION`·`QUALITY_GATES`·`DECISIONS`가
> Step 14–48의 설계 원본이다. 항목마다 상태가 붙는다: **[confirmed]** 정했다 · **[proposal]** 초안, 구현하며 재서 바꿀 수 있다 · **[question]** 소유자가 정한다.
> 루트 AGENTS.md의 `[확정]·[초안]·[질문]`과 같은 뜻이다. `[question]`은 소유자 결정 없이 구현하지 않는다.
> 설계가 바뀌면 코드보다 이 문서를 먼저 고친다.

## 1. 한 문장

**누르고 있다가 금색에서 떼는 손맛 하나로 시작해, 그 팝콘이 아래층 냄비에서 가운데층 포장대를 지나 위층 가게의 손님 손에
들어가는 것을 눈으로 따라가며, 그 흐름을 기계 마흔 대가 함께 돌리는 3층 공장으로 키우는 게임.** [confirmed]

## 2. 지키는 것 (Step 01–12에서 온 것)

| 무엇 | 왜 | 상태 |
|---|---|---|
| B의 누르기·떼기(금색, 벽시계 프레임 보정, 40ms 관용, 식는 시간) | 소유자가 Step 09에서 고른 손맛. 공장의 주된 손 입력이다 | [confirmed] |
| 돈은 하나 | 두 번째 통화는 따로 정당화될 때까지 없다 | [confirmed] |
| `#stand`(0.12.x)와 실험 A·B·C, 그 저장 `popcorn-glory.stand.v1` | 살아 있는 빌드이자 비교 기준선. 지우거나 덮지 않는다 | [confirmed] |
| 글로 설명하지 않는다(루트 AGENTS 2026-08-19) | 그림이 먼저, 글은 막혔을 때의 대비책 | [confirmed] |
| 활동 시간만 흐른다(숨은 탭·선택 화면에서는 멈춤) | 0.12.x와 같은 시계. 오프라인 진행 없음 → `FACTORY_FLOW` 8절 | [confirmed] |
| 소리 여유 -8 dB, 소리 스트림을 프레임마다 만들지 않기 | 0.12.1·0.12.2에서 고친 결함 | [confirmed] |

## 3. 새로 만드는 것 — 3층 공장

```
┌─────────────── 위층 TOP: 가게 ───────────────┐  손님 줄 → 계산대 → 봉지를 받고 돈을 낸다 (돈은 여기서만 생긴다)
│  간판 · 손님 줄 · 계산대 · (오른쪽 위) 소식 아이콘 │
├─────────────── 가운데층 MIDDLE: 포장 ──────────┤  튀긴 팝콘 → (양념) → 봉지/컵에 담아 봉한다
│  원료 통 · 포장대 · 선반                         │
├─────────────── 아래층 BOTTOM: 제조 ───────────┤  손: 누르고 금색에서 떼기 / 자동 냄비 줄
│  큰 냄비(손) · 자동 냄비 · 기계 칸               │
└──────────────────────────────────────────────┘
          물건은 언제나 아래 → 위로 움직인다
```

- 세 층은 한 화면에 늘 함께 보인다(세로 720×1280 기준). 물건은 아래에서 위로만 간다. [confirmed]
- 첫 3분의 주인공은 아래층의 큰 냄비다. 포장과 판매는 처음부터 저절로 돌아가고, 손이 할 일은 냄비 하나다. [confirmed]
- 경로는 `#factory`, 저장은 따로 `popcorn-glory.factory.v1`이다. `#stand`는 그대로 남는다. 옛 가게를 가져올지는 `DECISIONS` D-07 [question].

## 4. 재미의 약속 (Fun First, 10·30·60·180초)

| 시각 | 약속 | 무엇이 그것을 만든다 |
|---|---|---|
| 10초 | 무엇을 할지 안다 | 큰 냄비, 고리, 대기 손짓(0.12.x 그대로). 첫 손님이 이미 줄에 서 있다 |
| 30초 | 의미 있는 보상 | 첫 완벽한 팝 → 그 팝콘이 위로 올라가 첫 손님 손에 들어가고 동전이 난다(약 15–25초) |
| 60초 | 눈에 보이는 성장 | 첫 냄비 강화(모양이 바뀜), 두 번째 손님 |
| 180초 | 다음이 궁금하다 | 포장대 강화와 간판이 보이고, 자동 기계 칸의 실루엣이 비어 있다 |

## 5. 재사용 지도 — 지금 있는 파일

| 지금 있는 것 | 공장에서 | 어떻게 |
|---|---|---|
| `app/main.gd`(PopApp: 한 명령 경로, 시계, 저장 시점, 숨은 탭, 브리지) | 그대로 쓴다 | 레지스트리에 `factory` 줄을 더한다 |
| `app/registry.gd`, `app/route.gd`, `app/chooser.gd` | 쓴다 | `#factory`와 선택 화면 타일 |
| `core/rules.gd`(PopRules: 정수 ms·돈, `execute`/`advance`, 이벤트) | 공장 규칙의 바탕 | `FactoryRules extends PopRules`. 돈·이벤트·명령 형식을 같게 |
| `variants/stand/stand_rules.gd`의 판정(`_judge`, 금색·관용·식는 시간) | 손 냄비의 판정 | 판정 부분만 공유 모듈(`core/perfect_judge.gd`)로 떼어 두 규칙이 같은 함수를 부른다. `#stand`의 동작은 바이트 단위로 같아야 한다 |
| `core/economy.gd` + `data/economy.json` | 수치의 유일한 출처 | 공장 수치는 새 파일 `data/factory.json`(기계 40종·레시피·강화 나무·손님·소식·대회) |
| `app/save_store.gd` | 쓴다 | 키 `popcorn-glory.factory.v1` / `user://popcorn_glory_factory.v1.json` |
| `app/clock.gd`(PopClock), `app/session_log.gd` | 쓴다 | 같은 활동 시계·기록 |
| `app/audio.gd`(풀, 간격, 여유, 루프 하나) | 쓴다 | 소리 문법은 Step 43. 기계 소리는 우선순위·목소리 수 제한을 더한다 |
| `art/machine_art.gd`, `art/pop_fx.gd`, `art/atlas.gd` | 쓴다 | 큰 냄비 그림과 조각 풀. **매 프레임 다시 그리지 않는 층 구조**는 처음부터(`QUALITY_GATES` R-01) |
| `app/frame.gd`, `app/ui/*`(돈, 카드, 누름 영역, 아이콘) | 쓴다 | 위쪽 막대와 누름 영역 |
| `tools/test.sh`·`test_all.sh`·`e2e.sh`·`deploy.sh`·`capture.gd`·`tools/blind/`·`tools/sim/` | 넓힌다 | 공장 시뮬레이터는 `tools/sim/factory.gd` |

## 6. 기능 → 이슈 지도

| 기능 | 이슈 | 원본 문서 |
|---|---|---|
| 설계 묶음과 품질 기준 | 13 #126 | 이 폴더 |
| 완벽한 팝 + 쌓아서 터지는 C의 장관(되돌릴 수 있는 모드) | 14 #127 | `CORE_LOOP` 3절 |
| 미술 방향·디자인 토큰·에셋 목록 | 15 #128 | `ART_DIRECTION_BRIEF` |
| 3층 장면과 배치(`#factory`) | 16 #129 | `FACTORY_FLOW` 1절, `ART_DIRECTION_BRIEF` 3절 |
| 보존되는 묶음과 3단 시뮬레이션 | 17 #130 | `FACTORY_FLOW` 2–7절 |
| 실제 묶음을 따라가는 이동 그림 | 18 #131 | `FACTORY_FLOW` 9절 |
| 손 냄비·등급·제조 강화 | 19 #132 | `STATIONS` 1절 |
| 포장 단계와 강화 | 20 #133 | `STATIONS` 2절 |
| 가게·계산대·손님 반응 | 21 #134 | `STATIONS` 3절 |
| 확률적 손님 도착(평균 약 15초) | 22 #135 | `FACTORY_FLOW` 5절 |
| 주문·맞춤·인내·병목 신호 | 23 #136 | `FACTORY_FLOW` 6절 |
| 세 층의 강화 나무 | 24 #137 | `STATIONS` 4절 |
| 3단 경제와 손·자동의 가치 | 25 #138 | `PROGRESSION` 3–4절 |
| 자동 기계 실행기·배치·유지비 | 26 #139 | `AUTOMATION_PLAN` 1–3절 |
| 40종 기계 명세 | 27 #140 | `AUTOMATION_PLAN` 4절 |
| 제조 기초 M01–08 / 고급 M09–16 | 28 #141 / 29 #142 | `AUTOMATION_PLAN` 4절 |
| 포장 P01–08 / 가게 S01–08 / 보조 U01–08 | 30 #143 / 31 #144 / 32 #145 | `AUTOMATION_PLAN` 4절 |
| 동시에 40대 | 33 #146 | `AUTOMATION_PLAN` 5절, `QUALITY_GATES` |
| 맛 다섯 / 양념 솜씨 | 34 #147 / 35 #148 | `STATIONS` 5절 |
| 손님 성격·평판 | 36 #149 | `STATIONS` 3절 |
| 소식과 시장 이벤트 | 37 #150 | `PROGRESSION` 5절 |
| 대회 | 38 #151 | `PROGRESSION` 6절 |
| 30–60분 진행 조정 | 39 #152 | `PROGRESSION` |
| 최종 미술 / 손님·상품·아이콘 / 움직임·빛 | 40 #153 / 41 #154 / 42 #155 | `ART_DIRECTION_BRIEF` |
| 소리 | 43 #156 | `ART_DIRECTION_BRIEF` 6절 |
| 사용성·접근성 | 44 #157 | `QUALITY_GATES` |
| 저장 이주와 큰 공장의 저장 | 45 #158 | `FACTORY_FLOW` 8절, `DECISIONS` D-07 |
| 웹 회귀·스트레스·성능 묶음 | 46 #159 | `QUALITY_GATES` |
| 블라인드 AI 플레이 | 47 #160 | `QUALITY_GATES` 4절 |
| 출시 후보와 소유자 검토 | 48 #161 | `QUALITY_GATES`, `RELEASE_CHECKLIST.md` |
