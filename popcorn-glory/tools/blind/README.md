# 블라인드 AI 플레이테스트 (Popcorn Step 08)

처음 보는 플레이어처럼 **화면만 보고** 3분 동안 플레이하는 AI를 위한 도구다. momonium `tools/blind_playtest/`를 본떠 새로 썼다.
플레이어 AI가 받는 것은 스크린샷과 손(탭·누르고 있기·끌기·기다리기)뿐이다. 소스, 이슈, 설계, 규칙, 숨은 상태, 이전 실행 내용, URL은 주지 않는다.
URL을 주지 않는 이유는 실험 주소(`#perfect` 등)의 이름이 손동작을 암시하기 때문이다. 평가자(컨트롤러)는 따로 기록을 읽는다.

| 파일 | 역할 |
|---|---|
| `session.mjs` | 세션 데몬. 새 브라우저 프로필(400×860, DPR 1.5, 터치)로 게임을 열고, 플레이어의 첫 명령부터 **실제 3분** 뒤에 닫힌다. 테스트 훅(`POPCORN_E2E`)·개발 모드·시간 가속은 없다. 평가자용으로 5초마다 게임 상태, 끝에 게임 자체 기록(`game_log.json`)과 화면 녹화(webm)를 남긴다. |
| `play.mjs` | 플레이어의 유일한 인터페이스: `look`·`tap X Y`·`hold X Y S`(≤5초)·`drag X1 Y1 X2 Y2`·`wait S`(≤30초)·`note TEXT`·`status` |
| `evaluate.mjs` | 평가자용 지표 표(관찰만, 의견 없음) |

## 절차 (평가자)

1. 세션마다 새 폴더로 데몬을 띄운다: `node popcorn-glory/tools/blind/session.mjs --run /abs/runA --url 'https://7bvcxz.github.io/gamo/popcorn-glory/#click'`
   `session: ready`가 나오면 플레이어를 부른다.
2. **플레이어 AI**: 실험마다 새 컨텍스트의 에이전트를 하나씩 만든다. 이전 실행·대화·메모리를 쓰지 않는다. 아래 프롬프트만 준다(경로만 바꾼다). 진행 중에는 코치하지 않는다.
3. 끝나면 플레이어의 마지막 보고를 `controller/player_report.md`로 저장하고 `node popcorn-glory/tools/blind/evaluate.mjs RUN...`을 돌린다.
4. 평가: 스크린샷·노트·기록을 보고 네 질문(1–5)을 **AI 대리 판단**으로 매긴다. 관찰과 해석을 나누고, 사람(소유자) 칸은 비워 둔다.

## 플레이어 프롬프트 (그대로)

```
You are trying a mobile game on a phone for the very first time. You know nothing about it except what you see on its screen.
Play it for three minutes the way a curious new player would, and think aloud as you go.

You have the phone in your hands through these commands only (run them with Bash):
  node <TOOL>/play.mjs <RUN> look               -> prints the path of a screenshot of the phone; open it with the Read tool to see the screen
  node <TOOL>/play.mjs <RUN> tap X Y            -> touch the screen at pixel (X, Y) of the screenshot (screenshots are 600 x 1290 px); prints a new screenshot path
  node <TOOL>/play.mjs <RUN> hold X Y S         -> press at (X, Y) and keep the finger down for S seconds (at most 5), then lift it; prints a screenshot taken just before you lift and one after
  node <TOOL>/play.mjs <RUN> drag X1 Y1 X2 Y2   -> slide one finger from (X1, Y1) to (X2, Y2)
  node <TOOL>/play.mjs <RUN> wait S             -> let S seconds pass (at most 30), then see the screen
  node <TOOL>/play.mjs <RUN> note "TEXT"        -> say out loud what you see, what you try, what you expect and how it feels
  node <TOOL>/play.mjs <RUN> status             -> how much of the three minutes is left

Start with one look, and before you touch anything write a note saying what on the screen you think you can press and what you expect it to do.

Rules:
- Use only those commands, and the Read tool only on the screenshot files they print. Do not open, list or search any other file or folder, do not browse the web, and do not look for code, documentation or hints anywhere: a real first-time player has only the screen.
- The clock starts at your first command and runs in real time (thinking takes time too). Keep playing until a command answers "Time is up".
- There is no right way to play. Explore, make mistakes, follow your curiosity. Write a note at least every 30 seconds.

When the time is up, reply with a short report as yourself, the player:
1. Timeline: what you did, noticed and figured out, with the times the tool printed.
2. What felt satisfying or fun, and what did not.
3. What confused you, where you got stuck or what you could not find.
4. Would you keep playing past three minutes? Why or why not?
5. Confirm that you used only the play commands and their screenshots.
```

## 바뀐 것

- **Step 09(3차)부터** `hold`는 손을 떼기 약 0.3초 전의 화면도 돌려준다(프롬프트의 `hold` 줄에 한 구절이 붙었다). Step 08의 1·2차는 뗀 뒤의
  화면만 봤고, B 플레이어가 바늘의 방향을 거꾸로 짐작했다 — 사람은 누르는 동안 화면을 본다. 누르는 시간은 시계로 지키고(스크린샷 시간을
  더하지 않음) 실제 값을 `actions.jsonl`의 `held_ms`에 남긴다.

## 한계 (정직하게)

- **블라인드는 지시로만 지킨다.** 에이전트 도구(Read·Bash)는 기술적으로 샌드박스되어 있지 않다. 그래서 끝난 뒤 플레이어 에이전트의
  대화 기록(JSONL)에서 **모든 도구 호출**을 감사한다: `python3 -I tools/blind/audit.py r1 <기록.jsonl> r2 <기록.jsonl> …` — 화면 명령과
  자기 스크린샷 읽기 밖의 호출이 있으면 나열하고 1로 끝난다. 보고서에는 '지시 + 사후 감사, 샌드박스 아님'이라고 적는다.
- 한 번 해 본 에이전트는 다시 블라인드가 아니다. 고친 빌드는 **새** 에이전트로 다시 한다.
- `hold`는 손을 뗀 뒤의 화면만 돌려준다 — 누르는 동안의 움직임(B의 바늘)은 플레이어에게 보이지 않는다. 녹화에는 있다.
- AI 플레이어는 생각하는 동안에도 시간이 흐른다(3분에 명령 수십 개). 사람의 손 속도가 아니다.
- AI의 즐거움 판단은 사람의 즐거움·재방문의 증거가 아니다.
