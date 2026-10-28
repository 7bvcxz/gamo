# 증분 페이스 최적화 도구 (Step 50)

목표 대 실측 비교와 파라미터 실험을 다시 돌리는 도구 모음이다.

- 목표와 합격 기준: `design/INCREMENTAL_PACING.md`, 원본은 `targets.json`이다. 튜닝 전에 고정했다.
- 라운드별 기록: `design/INCREMENTAL_BALANCE_REPORT.md`.

## 파일

| 파일 | 역할 |
|---|---|
| `targets.json` | 고정한 목표. 지표, 목표값, 종류(정확·상한·하한), 가중치, primary 여부, 어떤 증거로 재는지 |
| `baseline_step69.json` | Step 69 게임(일 ×6.25, 건설 ×2.5)에서 잰 페이스 기준선. 목표가 아니라 회귀 방지(±30%)이며, Step 50 목표는 Step 58 속도에서 검사한다(`test_balance`) |
| `profiles.json` | 시뮬레이터 플레이어 프로필: `blind`(블라인드 AI 보정형), `blind_slow`·`blind_fast`, `human`, `human48`(2일 일정) |
| `optimize.gd` | 결정적 시뮬레이터. 프로필로 새 섬을 플레이하고, 체크포인트(10초·30초·1분, 2–10분 매분, 15·20·30·60분)에서 시계열을 읽고, 목표 대비 오차를 낸다 |
| `candidates/*.json` | 실험 라운드. `--set` 덮어쓰기 목록이며, 각 항목에 바꾸기 전 값(`old`)과 이유(`why`)를 적는다. `extends`로 앞 라운드 위에 쌓는다 |
| `score_blind.mjs` | 블라인드 실행(`tools/blind_playtest/`) 3개를 같은 정의로 채점한다. 실행별 값, 중앙값, 상대오차, 가중 집계를 낸다 |
| `chart.mjs` | 보고서 그림(SVG): 첫 10분 누적 수입(목표·시뮬레이터·블라인드 실행과 중앙값), 처음 해낸 시각 띠 |

## 쓰는 법

저장소 루트에서 실행한다. 경로는 저장소 루트 기준이다.

```bash
# 시뮬레이터: 지금 데이터 / 후보 / 한 값만 바꿔 보기
godot --headless --path momonium --script res://tools/balance_optimizer/optimize.gd -- --profile blind --minutes 30
godot --headless --path momonium --script res://tools/balance_optimizer/optimize.gd -- --profile blind --candidate momonium/tools/balance_optimizer/candidates/r3.json
godot --headless --path momonium --script res://tools/balance_optimizer/optimize.gd -- --profile blind --set "balance:momo/hire/base=50" --json /tmp/out.json

# 민감도: 다른 전략
... --profile blind --strategy no_land        # no_hire, no_research, no_letters, hands_only
... --profile blind_slow                      # 결정 간격 15초

# 2일 일정(국가 승급 시각)
... --profile human48 --schedule 48h

# 결정 하나하나 보기
... --profile blind --minutes 5 --trace

# 블라인드 실행 채점과 그림
node momonium/tools/balance_optimizer/score_blind.mjs RUN1 RUN2 RUN3 --md --json /tmp/blind.json
node momonium/tools/balance_optimizer/chart.mjs --sim /tmp/out.json --blind /tmp/blind.json --title R3 --out income.svg --milestones ms.svg
```

## 정의 (시뮬레이터와 블라인드가 같다)

- 시간은 첫 화면부터의 **활동 플레이 시간**이다.
  - 블라인드: 세션 시계.
  - 시뮬레이터: 봇의 `active_ms`.
- `journey:<key>`: 게임 자신의 여정 기록이 처음을 적은 시각이다.
  - 블라인드에서는 저장의 `saved_unix`와 세션 시작 시각으로 게임 시계를 세션 시계에 맞춘다.
  - 10초 폴링이나 15초 저장 지연이 들어가지 않는다.
  - `income`은 여정의 첫 `sale`이다. 모든 판매가 끝난 일의 즉시 수입이기 때문이다.
- `income_at:<s>`: 그때까지의 생산 수입(판매·출시)이다.
  - 블라인드는 저장 사이를 선형 보간한다.
- `meaningful_at:600`: 레벨업 + 새 건물(시작 건물 제외) + 땅 + 고용 + 연구 레벨 + 편지.
- `momo_share_at:600`: 끝난 작업 단계 중 모모(와 자동 장치)의 몫.
- `income_gap`: 모모 첫 수입 뒤 10분까지 수입 사이 최장 공백.
  - 블라인드는 저장 간격(약 15초) 해상도라서 상한 추정이다.
- 도달하지 못한 것은 '없음'이다. 중앙값이 '없음'이면 실패다.

## 블라인드 프로필의 한계

`blind` 봇은 Step 45 블라인드 AI의 박자(10초에 한 번, 세 번에 한 번 둘러보기)로 보정했다. 하지만 열린 것은 무조건 찾는다. 그래서 블라인드 결과의 **예측**일 뿐이고, 합격 판정은 실제 블라인드 실행으로 한다.
