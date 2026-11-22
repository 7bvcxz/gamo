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
  node <TOOL>/play.mjs <RUN> hold X Y S         -> press at (X, Y) and keep the finger down for S seconds (at most 5), then lift it
  node <TOOL>/play.mjs <RUN> drag X1 Y1 X2 Y2   -> slide one finger from (X1, Y1) to (X2, Y2)
  node <TOOL>/play.mjs <RUN> path S X1 Y1 X2 Y2 [X3 Y3 ...] -> put a finger down at (X1, Y1), keep it on the screen while it moves through the other points over S seconds (at most 5), then lift it
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

- **Step 09 3차에서 `hold`가 손을 떼기 약 0.3초 전의 화면도 돌려주게 했다가 되돌렸다.** 사람은 누르는 동안 화면을 보므로 맞는 방향 같았지만,
  부하가 큰 이 머신에서 그 캡처가 페이지를 멈춰 누름이 벽시계로 0.3–3.9초, 게임 시계로 +240–500ms 길어졌다(1·2차는 +76–224ms).
  B 플레이어는 "같은 길이로 눌렀는데 +10과 +5가 나와 조금 무작위 같다"고 적었다 — 도구 때문이었다. **시간을 재는 입력 도중에는 화면을 찍지 않는다.**
  그 3차 B(t2)의 타이밍 관찰은 오염되었으므로 같은 빌드에서 새 에이전트로 다시 했다(3b). `held_ms`(벽시계 누름)는 계속 남긴다.

- **세션은 하나씩 띄운다.** Step 10에서 두 세션을 동시에 띄웠더니 둘 다 엔진(39MB)을 받는 중에 150초 대기를 넘겨 죽었다. 하나씩 띄우면 3–5초에 준비됐다. 띄운 뒤 `ready`를 보고 다음 것을 띄운다.
- `--seconds 600`이면 10분 세션이다(Step 10의 긴 플레이). 프롬프트의 'three minutes'를 'ten minutes'로 바꿔 준다.
- **Step 11부터** `path` 명령이 있다(손가락을 댄 채 여러 점을 지나 움직이고 뗀다). 사람은 누른 채 움직일 수 있는데, AI의 `drag`는 0.2초라
  그것이 불가능했다(가게의 흔들기를 아무도 찾지 못한 이유 중 하나). 이 명령은 무엇을 하라고 말하지 않는다. 시간은 시계로 지킨다(1.6초 요청 →
  1.64–1.69초, 게임 판정 1,550–1,616ms). Step 11의 긴 세션은 보고에 '6. What do you think the goal of the game is?'를 더한다.

- **Step 47: 세 가지 장면과 새 도구.**
  - `session.mjs --save FILE`: 미리 만든 공장 저장으로 시작한다. 새 프로필의 localStorage에 페이지가 열리기 전에 한 번 넣는다. 세션 안의 새로 고침은 플레이어가 만든 것을 지킨다. `start.json`에 파일·크기·sha256이 남고, **보고서와 플레이어 프롬프트 둘 다 그 사실을 말한다.** 프롬프트에는 "This phone already has a game in progress that someone else built up over a while; you are picking it up from where they left it." 한 문장을 더한다.
  - `session.mjs --log-every S`: 게임 자신의 기록을 S초마다 읽는다(기본 5). 44대 공장은 20분에 기록이 수만 줄이고, 그것을 5초마다 통째로 읽으면 플레이어가 보는 공장을 멈춘다.
  - 상태 표본에 `view`(신문이 열렸는지, 고른 층·기계)가 들어간다.
  - `prepare_factory.mjs`: 공개 빌드의 개발 다리(`?dev=1`)로 44대 저장을 만든다. 결과는 `<out>`과 `<out>.about.json`이다(`evidence/step47/fixtures/`).
  - `evaluate47.mjs`: 공장의 이정표를 플레이어 시계로 잰다. 첫 Perfect, 첫 판매, 첫 기계, 첫 구매와 구매 사이 시간, 조리법 바꾸기, 신문 열기, 대회 참가, 거절된 누름, 같은 자리 다시 누르기, 병목 표본, 세션 동안의 매출·운영비를 낸다.
  - **중립 경로:** 플레이어의 명령 경로에 게임 이름·`blind`·step 번호가 보이지 않게, `play.mjs`를 스크래치패드의 `phone/`에 복사해 쓰고 세션 폴더도 그 옆에 둔다(`phone/p1` …). 감사는 그 경로를 플레이어 것으로 센다.
  - **감사 고침:** 첫 20분 플레이어가 `P=<phone 폴더>; node $P/play.mjs $P/p2 …`처럼 같은 명령 안에서 변수를 정의해 썼고, 감사는 147개 호출을 모두 표시했다(모두 전화기 명령이었다). 이제 감사는 같은 명령 안에서 정의된 변수를 그 값으로 바꾼 뒤 경로를 본다. 가짜 기록으로 확인했다: 전화기 명령은 통과하고 `cat $P/../../x.txt`·`ls $X`는 여전히 표시된다.
  - 긴 세션의 녹화는 VP9 6fps로, 스크린숏은 WebP(품질 72)로 줄여 남긴다. 플레이어가 본 것은 같은 프레임의 PNG 원본이다(`actions.jsonl`의 `shot` 이름은 `.png` 그대로).

## 한계 (정직하게)

- **블라인드는 지시로만 지킨다.** 에이전트 도구(Read·Bash)는 기술적으로 샌드박스되어 있지 않다. 그래서 끝난 뒤 플레이어 에이전트의
  대화 기록(JSONL)에서 **모든 도구 호출**을 감사한다: `python3 -I tools/blind/audit.py r1 <기록.jsonl> r2 <기록.jsonl> …` — 화면 명령과
  자기 스크린샷 읽기 밖의 호출이 있으면 나열하고 1로 끝난다. 보고서에는 '지시 + 사후 감사, 샌드박스 아님'이라고 적는다.
- 한 번 해 본 에이전트는 다시 블라인드가 아니다. 고친 빌드는 **새** 에이전트로 다시 한다.
- `hold`는 손을 뗀 뒤의 화면만 돌려준다 — 누르는 동안의 움직임(B의 바늘)은 플레이어에게 보이지 않는다. 녹화에는 있다.
- AI 플레이어는 생각하는 동안에도 시간이 흐른다(3분에 명령 수십 개). 사람의 손 속도가 아니다.
- AI의 즐거움 판단은 사람의 즐거움·재방문의 증거가 아니다.
