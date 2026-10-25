# 블라인드 플레이테스트 (Step 45)

공개된 웹 빌드를 **처음 보는 플레이어처럼** AI가 화면만 보고 플레이하게 하고, 그 과정을 기록·평가하는 도구.
플레이어 AI에게는 화면(스크린샷)과 손(탭·드래그·기다리기)만 주고, 소스·이슈·설계 문서·게임 규칙·숨은 상태·이전 실행 내용은 주지 않는다.
평가자(컨트롤러)는 별도로 기록과 게임 저장을 읽는다.

## 파일

| 파일 | 역할 |
|---|---|
| `session.mjs` | 한 세션의 데몬. 새 브라우저 프로필로 게임을 열고, 그려질 때까지 기다린 뒤, 플레이어의 명령을 받는다. 플레이어가 처음 화면을 본 순간부터 **실제 10분** 뒤에 스스로 끝난다. 테스트 브리지(`MOMONIUM_E2E`)·개발 메뉴·시간 가속은 없다. |
| `play.mjs` | 플레이어의 유일한 인터페이스: `look`·`tap X Y`·`drag X1 Y1 X2 Y2`·`wait S`(≤30초)·`note TEXT`·`status`. 행동마다 새 스크린샷 경로를 출력한다. |
| `lib.mjs` | 시계·좌표·로그·저장 읽기·멈춘 구간 계산(순수 함수) |
| `evaluate.mjs` | 컨트롤러용: 세션 기록에서 지표 표를 만든다 |
| `test/` | `node --test momonium/tools/blind_playtest/test/*.test.mjs`(Node 24는 폴더를 받지 않는다) — 순수 함수 단위 테스트 9개 + 로컬 `docs/` 빌드로 짧은 세션을 돌리는 통합 테스트 1개(약 34초) |

세션 폴더:
- `player/shots/`: 플레이어가 볼 수 있는 것(자기 스크린샷)
- `controller/`: 평가자만 읽는 것
  - `actions.jsonl`: 시각이 찍힌 모든 명령
  - `state.jsonl`: 10초마다 게임 자체 저장(localStorage)의 요약. 게임은 15초마다 저장하므로 최대 15초 늦다.
  - `errors.jsonl`: 페이지 오류
  - `start.json`·`summary.json`
- `profile/`: 세션마다 새 브라우저 프로필. 실행 사이에 아무것도 공유하지 않는다.

화면은 세로 휴대폰(400×860 CSS px, DPR 1.5 → 스크린샷 600×1290), 터치 입력이다.

## 실행 절차 (컨트롤러)

준비: `momonium/tests/e2e`에 Playwright가 설치돼 있어야 한다(`npm ci`). 브라우저는 E2E와 같은 Chromium이다.

1. **세션 시작**: 세션마다 새 폴더로 데몬을 띄운다.
   ```bash
   node momonium/tools/blind_playtest/session.mjs --run /tmp/blind/run1 --url https://7bvcxz.github.io/gamo/momonium/
   ```
   `session: ready … on port N`이 나오면 플레이어를 부를 수 있다.
2. **플레이어 AI**
   - 세션마다 **새 컨텍스트의 에이전트**를 하나씩 만든다. 이전 실행을 아는 대화나 메모리를 쓰지 않는다.
   - 아래 프롬프트만 준다(경로 두 곳만 바꾼다).
   - 컨트롤러는 진행 중에 개입하거나 코치하지 않는다.
3. **끝나면**
   - 데몬이 스스로 닫힌다.
   - 플레이어의 마지막 보고(감상)를 `controller/player_report.md`로 저장한다.
   - `node momonium/tools/blind_playtest/evaluate.mjs /tmp/blind/run1 /tmp/blind/run2 /tmp/blind/run3`
4. **보고서**: 지표 표와 스크린샷·노트로 실행마다 타임라인을 쓰고, 실행끼리 비교하고, 심각도 순 UX 수정 목록을 쓴다(`design/BLIND_PLAYTEST.md`).
   - 관찰과 가설을 구별한다.
   - 플레이어의 감상은 **AI 관찰**로 표시한다.

### 플레이어 프롬프트 (그대로)

```
You are trying a mobile web game for the very first time. You know nothing about it except what you see on its screen.
Play it for ten minutes the way a curious new player would, and think aloud as you go.

You have a phone in your hands, through these commands only (run them with Bash):
  node <TOOL>/play.mjs <RUN> look               -> prints the path of a screenshot of the phone; open it with the Read tool to see the screen
  node <TOOL>/play.mjs <RUN> tap X Y            -> touch the screen at pixel (X, Y) of the screenshot (screenshots are 600 x 1290 px); prints a new screenshot path
  node <TOOL>/play.mjs <RUN> drag X1 Y1 X2 Y2   -> slide one finger from (X1, Y1) to (X2, Y2)
  node <TOOL>/play.mjs <RUN> wait S             -> let S seconds pass (at most 30), then see the screen
  node <TOOL>/play.mjs <RUN> note "TEXT"        -> say out loud what you see, what you are trying, what you expect and how it feels (often: at least once a minute)
  node <TOOL>/play.mjs <RUN> status             -> how much of the ten minutes is left

Rules:
- Use only those commands, and the Read tool only on the screenshot files they print. Do not open, list or search any other file or folder, do not browse the web, and do not look for code, documentation or hints anywhere: a real first-time player has only the screen.
- The clock starts at your first look and runs in real time (thinking takes time too). Keep playing until a command answers "Time is up".
- There is no right way to play. Explore, make mistakes, follow your curiosity.

When the time is up, reply with a short report as yourself, the player:
1. Timeline: what you did, noticed and figured out, with the times the tool printed.
2. What felt satisfying or fun.
3. What confused you, where you got stuck or what you could not find.
4. Would you keep playing? Why or why not?
5. Confirm that you used only the play commands and their screenshots.
```

## 한계 (정직하게)

- **블라인드 범위**
  - 블라인드는 **프롬프트와 도구 사용 규칙**으로 지킨다. 에이전트 도구(Read·Bash)가 기술적으로 샌드박스된 것은 아니다.
  - 그래서 플레이어의 마지막 확인(5번)과 `actions.jsonl`(명령만 남음)을 함께 본다.
  - 에이전트는 작업 공간의 일반 지침(CLAUDE.md)을 받을 수 있지만, 거기에 이 게임의 규칙은 없다.
- **명령 왕복 시간**: 화면 한 장을 보고 생각하는 데 실제 시간이 든다. 10분 동안의 행동 수는 사람보다 적을 수 있다.
- **해석 범위**: 이 결과는 사람 플레이어의 증거가 아니라 **AI 관찰**이다.
