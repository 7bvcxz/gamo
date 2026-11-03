# 블라인드 AI 플레이테스트 — 화면만 보고 하는 실제 플레이 (Step 09)

> AI는 사람 테스터가 아니다. 사람보다 UI를 잘 읽을 수 있지만 취향에는 약하다. 이 문서의 숫자는 "이 AI 플레이어들이 이렇게 했다"이지 "사람이 이렇게 한다"가 아니다.
> 사람 플레이테스트 결과는 **없음**(대본과 설문은 `HUMAN_PLAYTEST.md`).

## 하네스 — 재현 방법

```
windup/tools/blind/run_session.sh <증거 폴더> [게임 URL] [모델]     # 세션 하나
windup/tools/blind/isolation_check.sh <결과.txt>                      # 샌드박스가 막히는지 (AI가 밖으로 손을 뻗게 시킨다)
windup/tools/blind/selftest.sh                                        # AI 없이 기록기만 검사 (응답에 게임 상태가 없는지, 영상·소리·계측이 남는지)
```

| 부분 | 무엇 | 플레이어가 보나 |
|---|---|---|
| `tools/blind/server.mjs` 기록기 | Playwright Chromium(1280×720)으로 **공개된 실제 웹 빌드**를 `?fresh=1`로 연다. 명령 하나마다 마우스·키보드를 실제로 보내고 새 스크린샷을 찍는다. 기록: 명령·벽시계·게임 시각(기록기만 읽음)·스크린샷 번호(`actions.jsonl`), 끊김 없는 영상과 게임 소리(`session_*.mp4`). 끝나면 게임 자신의 기록(`game_events.jsonl`)을 저장 | **아니오** |
| `tools/blind/act.mjs` 조작 | `look` `click X Y` `double_click` `hold X Y 초` `drag` `key` `hold_key` `wait`(≤10초) `end`. 돌려주는 것은 **새 스크린샷 경로와 시작 후 초**뿐 | 예 — 이것이 플레이어의 전부 |
| 플레이어 | 별도 프로세스 `claude -p`(Claude Code 2.1.317, 모델 `claude-opus-5-5`), **빈 샌드박스 폴더**에서 시작(`act.mjs`, `.port`, `screens/`만). 플래그: `--restricted`(파일 도구를 샌드박스로 가둠, 사용자·프로젝트 설정 무시) `--safe-mode`(CLAUDE.md·스킬·플러그인·훅·MCP 없음) `--strict-mcp-config` `--no-session-persistence`(세션 사이 기억 없음) `--tools Bash,Read` `--allowedTools "Bash(node ./act.mjs:*)"` | — |
| `tools/blind/extract.mjs`, `analyze.mjs` | **세션이 끝난 뒤에만**: 플레이어가 연 이미지를 그대로 `seen/`에 풀고, 순서대로 "본 화면 → 한 말 → 한 일"(`decisions.md`)을 만들고, 게임 기록과 맞춘다(`summary.json`) | 아니오 |

**플레이어에게 준 글 전부** (`evidence/step09/*/prompt.txt`, 네 세션 같음):

> Here is a game. Play naturally for at least three minutes and narrate what you think is happening.
>
> How you see and control it (this is the whole interface): run `node ./act.mjs <command>`. Each command returns the path of a fresh screenshot of the game window (1280x720 pixels) and the seconds since the game started; open that screenshot with the Read tool to see it.
> Commands: look | click X Y | double_click X Y | hold X Y SECONDS | drag X1 Y1 X2 Y2 [SECONDS] | key NAME (e.g. Space, Enter, ArrowLeft) | hold_key NAME SECONDS | wait SECONDS (at most 10) | end
> X and Y are pixel positions in the screenshot.
>
> As you play, narrate briefly after each screenshot: what you see, what you think is happening, and why you do what you do next. When at least three minutes have passed and you are ready to stop, run `node ./act.mjs end`, then give a short summary: what you think the game is, what you understood and what confused you, and whether you would keep playing and why.

이슈가 준 첫 문장에 더한 것은 **조작 방법**(없으면 플레이할 수 없다)과 **끝난 뒤 요약 부탁** 둘뿐이다. 게임 이름·열쇠·인형·감기·목표에 대한 말은 없다.
`hold`는 모든 화면 게임에 있는 일반 조작으로 목록에 들어 있다 — 이 게임에서 누르고 있기가 통한다는 말은 없다.

**소리:** 플레이어는 스크린샷만 받는다. **소리는 듣지 못했다.** 영상에는 게임 소리가 들어 있다(사람 검토용).

## 격리 증명

- `isolation_check.txt`: 같은 플래그로 띄운 플레이어에게 일부러 밖을 읽게 시켰다(저장소의 `AGENTS.md`·`atelier.gd`·`balance.json`, 홈 폴더 목록, `curl github.com`, `node -e`로 저장소 목록). **7개 모두 Claude Code가 거부**(permission_denials 7), `./act.mjs`만 실행됐다.
- 실제 네 세션의 기계 기록(`transcript.sanitized.jsonl`): 도구는 `Bash`·`Read` 둘뿐, **Read 59번 전부 `./screens/NNNN.png`**, Bash는 전부 `node ./act.mjs …`(또는 그것을 되풀이하는 `for` 줄), 거부 0, 도구 오류 0 — 밖으로 손을 뻗으려 한 적도 없다.
- 플레이 중 게임 기록(`window.windup`)은 기록기만 읽었고 플레이어에게 돌아가지 않는다(`selftest.sh`가 응답의 키가 `screenshot`, `seconds_since_start`뿐인지 검사).
- 결정이 **화면에서 왔다는 것**: `decisions.md`의 모든 결정 앞에 플레이어가 연 화면(`seen/`)이 있고, 말한 것은 화면에만 있는 것이다("a thread runs from the gear to one doll", "a red sewing machine", "the grandfather clock moves forward"). 화면에 없는 사실(몫 55, 초당 상한, 인형 수 12의 근거 등)을 말한 적이 없다. 화면을 잘못 읽은 것도 그대로 남아 있다(정령의 고리를 "타이머"로 읽음 — 아래).
- 세션마다 새 브라우저 컨텍스트(새 저장), 새 샌드박스, 새 프로세스. 같은 공개 빌드 **0.8.0+base**(팩 `game-9fe153de3bb8.pck`, 커밋 `a743bba3`), 같은 창 크기, 같은 글.

## 세션 (2026-11-03, 공개 빌드 0.8.0, 기준 변형)

`pilot0`은 같은 조건의 첫 세션인데, 끝날 때 기록기 버그(게임 기록 형식을 잘못 읽음)로 **게임 기록과 소리가 저장되지 않았다**. 플레이어의 말·스크린샷·행동 기록·소리 없는 영상은 있다. 세 번의 정식 세션에 세지 않고 참고로 둔다(버리지 않는다).

| | 세션 1 | 세션 2 | 세션 3 | (pilot 0) |
|---|---|---|---|---|
| 플레이 시간(벽시계, end까지) | 224.6초 | 207.8초 | 190.7초 | 188.5초 |
| 명령 / 실제 입력 / 플레이어가 본 화면 | 128 / 119 / 17 | 155 / 145 / 14 | 33 / 29 / 15 | 119 / 110 / 13 |
| 첫 명령(`look`) | 6.3초 | 6.7초 | 7.5초 | 7.4초 |
| **첫 의미 있는 행동**(열쇠 클릭) | 12.4초 | 14.4초 | 14.6초 | 13.1초 |
| 첫 감기(게임 시각) | 11.5초 | 15.9초 | 15.7초 | (기록 없음) |
| 정령의 '누르고 있기' 힌트가 뜸 | 31.6초 | 35.9초 | 35.8초 | — |
| 누르고 있기 사용 | 100.1초부터 2번 | **없음** | 67.9초부터 9번(감기 291/318이 누르고 있기) | 없음 |
| **첫 인형** | 99.9초 | 91.0초 | 78.5초 | (말로는 깨어남) |
| 첫 도움("help") / 첫 변화(빛) | 106.2 / 101.4초 | 97.4 / 92.7초 | 84.8 / 80.1초 | — |
| 인형 30 / 60 / 180초 | 0 / 0 / 2 | 0 / 0 / 2 | 0 / 0 / 3 | — |
| 열쇠 밖을 누름 | 4(정령, 잠든 인형의 열쇠, 인형의 고리, 왼쪽 아래) | 3(인형, 인형의 열쇠, 정령) | 2(인형, 재봉틀) | 3(인형의 열쇠, 시계, 오른쪽 아래 구석) |
| 끌기·두 번 클릭·키보드 | 끌기 1 | — | — | — |
| 창 포커스 | 잃은 적 없음(멈춤 사건 0) | 같음 | 같음 | — |
| 180초 뒤 계속(마지막 행동이 끝난 시각) | 219.8초까지 | 205.2초까지 | 187.2초까지(30초짜리 누르고 있기) | 184.2초까지 |

시간은 벽시계(플레이어가 가진 유일한 시계)이고, 게임 시각은 그보다 약 1초 늦게 시작한다(로딩 뒤 1.5초 대기).
**AI의 결정 하나는 4–8초**가 걸린다(화면을 읽고 생각하고 명령). 그 사이 게임은 흐른다 — 사람의 망설임과 같은 것이 아니다.

## 목표와 비교 (`CORE_LOOP.md`의 10/30/60/180초)

| 목표 | 결과 | 판단 |
|---|---|---|
| ≤10초: 첫 의미 있는 행동 | 12.4–14.6초. 단, 세 명 모두 **첫 화면을 본 뒤 첫 결정이 열쇠 클릭**이었다(첫 명령까지 6–8초는 모델 지연이고, 그 6초 중 3초는 하네스가 표준 입력을 기다린 것 — 고쳤다) | 결정 기준으로는 통과, 시간 기준으로는 AI 지연 때문에 판단 불가 |
| ~30초: 첫 인형 | **78.5–99.9초** | **실패.** 원인 아래 |
| ~60초: 보이는 변화 | 첫 빛 80–101초(첫 인형과 함께) | **실패**(첫 인형이 늦어서) |
| 180초: 자동 일 인식·더 하고 싶음 | 셋 다 "passive"·"on their own"을 말했고, 셋 다 "인형이 다음 인형을 감는다"를 스스로 설명했다. 셋 다 "for a while, yes" | 통과(AI의 말) |

### 왜 첫 인형이 늦었나 — 기록으로 본 것

1. **AI의 클릭 속도.** 15–30번씩 몰아 누르고 화면을 보고 4–8초 생각한다. 첫 인형 전 평균 입력: 세션 1 초당 0.55번, 세션 2 0.64번(세션 3은 누르고 있기로 바꿈) — 실험실의 `confused_slow`(초당 0.8번, 첫 인형 115초)와 `casual`(1.5번, 24초) 사이이고, 결과(78–100초)도 그 사이다. 실험실 예측과 맞는다.
2. **정령의 힌트가 '기다려라'로 읽혔다.** 네 세션 모두 31–36초에 뜬 고리를 **타이머·충전**으로 읽었다:
   - 세션 1: "The ring is draining counterclockwise like a timer. I'll wait to see what happens when it runs out." → 16초를 기다림, 그 사이 대기 힌트(idle20)까지 떴다.
   - 세션 2: "an arc appeared around the gear, maybe a charge or timer. I'll wait a bit" → 기다림 두 번, 대기 힌트, **끝까지 누르고 있기를 안 씀**.
   - 세션 3: "a thin gold arc growing around the gear, like a progress ring. I'll wait to see if it fills up by itself." → 5초 기다린 뒤 클릭, 그다음 누르고 있기를 시도해 "Holding the gear down winds it continuously and is much faster"를 알아냈다. 힌트 덕인지 스스로 시도한 것인지는 기록으로 가를 수 없다.
   - 세션 1의 누르고 있기(100.1초, 첫 인형은 그 누르고 있기 도중 99.9초 게임 시각에 깨어남)도 힌트가 아니라 "Since it's a wind-up key, I'll try a circular drag to turn it, then a long hold"에서 나왔다.
   - Step 08이 가설로 둔 '힌트를 받아들이면 첫 인형 50초'는 이 셋에서 **확인되지 않았다**. 오히려 기다림을 늘렸다.
3. **인형의 고리가 '찼다'로 보였다**(세션 1 46초: "The doll's ring looks full" — 실제로 41/55). 찬 것을 눌러 보려고 인형을 눌렀다.

### 무엇을 알아냈나 (플레이어의 말 그대로)

- 무엇: 넷 다 "cozy idle/clicker game set in a toymaker's workshop at night".
- 인형이 서로 돕는다: 세션 1 "Each awake doll walks over and helps wind the next sleeper", 세션 2 "it wakes, stands and glows, then walks over to help wind the other dolls", 세션 3 "joins in winding the next sleeping doll".
- 공방의 변화: 셋 다 톱니가 늘고 책상 램프가 켜지고 빨간 재봉틀이 드러난 것을 말했고, 세션 2는 "the grandfather clock moves forward"까지 봤다.
- 실(열쇠 → 다음 인형): 넷 다 스스로 알아냈다.

### 헷갈린 것 (마찰 후보 — Step 10에서 분류)

| 마찰 | 세션 | 근거 |
|---|---|---|
| 열쇠 둘레의 큰 고리(정령의 힌트)를 타이머로 읽고 기다림 | 4/4 | 위 인용, 기다린 구간, idle20 힌트 2번 |
| 인형이 깨어날 때 숫자가 줄어드는 것(몫을 씀)이 안 읽힘 | 3/4 | "The counter dropped from 26 to 2 … spending, a reset, or a per-doll progress meter" |
| 정령을 누르면 아무 일도 없음 | 4/4 | 넷 다 정령을 눌렀다(세션 2: "Clicking the orb sent it onto the gear" — 실제로는 힌트가 첫 감기 20초 뒤라는 제 규칙대로 떴고(세 세션 모두 +20.0초) 클릭과 우연히 겹쳤다) |
| 잠든 인형·인형의 열쇠·고리를 누름 | 4/4 | 넷 다 (422–450, 605)를 누름 |
| 상점이 없다 | 2/4(pilot, 세션 2) | 장르 기대. 설계상 의도(통화 하나·상점 없음) — 고칠 것이 아니라 기록 |
| 선택이 없어 오래가지 않을 것 같다 | 4/4 | "I barely make any choices" — MVP 범위 밖, Step 11·12의 판단 재료 |

## 증거 (`windup/evidence/step09/`)

세션 폴더마다:
- `session_0.8.0+base.mp4`: 끊김 없는 원본 영상과 게임 소리. pilot은 `session_pilot_noaudio.mp4`(webm을 mp4로만 바꿈).
- `seen/`: 플레이어가 실제로 연 스크린샷 원본 PNG.
- `screens/`: 매 명령의 스크린샷 전부를 480px JPEG로 줄인 색인. 원본 PNG는 크기 때문에 지웠고, 플레이어가 본 것은 `seen/`에 원본으로 있다.
- `actions.jsonl`: 명령·인자·벽시계·게임 시각·스크린샷 번호.
- `transcript.sanitized.jsonl`: 플레이어의 기계 기록 전체. 이미지 base64만 `seen/` 파일 이름으로 바꿨다.
- `decisions.md`: 본 화면 → 한 말 → 한 일.
- `narration.md`: 말만.
- `game_events.jsonl`, `game_state_end.json`: 세션 뒤 저장한 게임 기록.
- `summary.json`: 위 표의 숫자.
- `setup.txt`: 샌드박스·시작 시각·URL·커밋·플래그.
- `prompt.txt`.

함께 둔 파일: `isolation_check.txt`.
