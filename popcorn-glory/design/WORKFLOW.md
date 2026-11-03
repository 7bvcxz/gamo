# 작업 절차

## Step 하나의 순서

1. 이슈 본문, 루트 `AGENTS.md`·`Progress.md`, 이 폴더의 `PROGRESS.md`, 앞선 Popcorn 이슈의 완료 코멘트를 읽는다.
2. 구현한다. 고치는 곳은 `popcorn-glory/`와, 새 게임 등록에 필요한 최소한의 공유 파일뿐이다.
3. 검증한다(아래 '검증의 사다리'). 실행하지 않은 검사는 통과라고 쓰지 않는다.
4. 관련 경로만 커밋한다: `git commit -- popcorn-glory <등록 파일들>`. 이 작업 트리는 여러 gamo 세션이 함께 쓰므로
   `git add -A`·`git commit -a`를 쓰지 않고, 커밋 직전에 `git diff --cached --stat`을 읽는다.
5. `git pull --rebase` 뒤 `main`에 push. 사이트 산출물(`docs/_next` 등)이 충돌하면 rebase 뒤 사이트를 다시 빌드한다.
6. 이 폴더의 `PROGRESS.md`와 루트 `Progress.md`의 `## popcorn-glory`를 갱신한다.
7. 이슈에 **한국어 완료 보고**(구현·변경 파일·결정·URL·테스트 실측·증거·문제·커밋 SHA·인계)를 코멘트로 남기고,
   수락 조건을 확인한 뒤 close한다. 막히면 열어 두고 막힌 이유를 쓴다.

## 검증의 사다리 (Step 03에서 명령이 생긴다)

| 단계 | 명령 (예정) | 언제 |
|---|---|---|
| 로드 | `godot --headless --path popcorn-glory --editor --quit` — 출력의 `SCRIPT ERROR`·`ERROR`·누수 경고까지 본다(종료 코드 0은 증거가 아니다) | 매 변경 |
| 단위·통합 | `popcorn-glory/tools/test.sh` (헤드리스, 엔진 오류도 실패로 센다) | 매 변경 |
| 묶음 | `popcorn-glory/tools/check.sh` (import → 로드 → 테스트) | 커밋 전 |
| 렌더 | `xvfb-run … --script res://tools/capture.gd` — 헤드리스로는 그림을 못 찍는다 | 화면을 바꿀 때 |
| 배포 | `popcorn-glory/tools/deploy.sh` → `docs/popcorn-glory/` | push 전 |
| 브라우저 | `popcorn-glory/tools/e2e.sh` — 서버 루트는 게임 폴더가 아니라 **`docs/`**(공유 엔진이 `../engine/`) | 배포마다 |
| 공개 | push 뒤 Pages 반영을 기다려 공개 URL을 폰(720×1280 세로, 터치)·데스크톱에서 연다 | URL을 보고하기 전 |

## 브라우저 플레이 규칙 (이 저장소가 이미 겪은 것)

- 준비 완료는 '캔버스가 있다'가 아니라 **캔버스에 한 가지 색 이상이 그려졌다**로 판정한다.
- 모바일은 `touchscreen.tap()`과 CDP 터치(누름·뗌 따로)로. `mouse.click()`은 터치 경로를 지나지 않는다.
- 0.1초짜리 순간을 찍을 때는 그 상태를 멈춰 놓고 찍는다.
- 소리는 '`play()`가 불렸다'가 아니라 출력 신호(RMS)로 잰다.
- 로컬 서버는 띄운 뒤 `curl -sI`로 200인지, 내 파일인지 확인한다.

## 그림·소리

1. **도형이 먼저다.** 기계·팝콘·돈은 `draw_*`와 색으로. 플레이가 그림을 기다리지 않는다.
2. 생성이 필요해지면 `imagegen … --dry-run`으로 요청을 확인하고, `--quality low`부터. 사이드카(`*.png.json`)를 함께 커밋한다.
   스프라이트는 순수 초록 배경으로 생성 → Godot `Image`로 키잉한다. 프롬프트에 없어야 할 물건의 이름을 적지 않는다.
3. 소리는 표준 라이브러리로 합성 → `ffmpeg -c:a libvorbis` → `.ogg` 커밋. 버스는 `default_bus_layout.tres`에.
4. 게임 폴더 안에 게임이 안 쓰는 파일 묶음(문서·증거·웹 페이지)을 두면 **그 자리에서 `.gdignore`**, 배포 뒤
   `strings game-*.pck | grep <폴더>`가 0인지 본다.

## 블라인드 플레이어 분리

- 플레이어는 **새 컨텍스트의 에이전트**이고, 받는 것은 공개 URL과 중립적인 지시뿐이다. 저장소·설계 문서·이 파일을 주지 않는다.
- 손은 '보기·탭·누르고 있기·기다리기·메모'뿐이고, 테스트 브리지·`?dev=1`·시간 가속을 쓰지 않는다. 새 브라우저 프로필.
- 하네스는 momonium `tools/blind_playtest/`(play·session·evaluate)를 본뜬다. 결과는 **AI 관찰**로만 적고 사람의 점수와 섞지 않는다.

## 격리 확인 (Step 03부터 테스트로)

- 소스에 `user://` 쓰기·`localStorage`·네트워크 호출이 없다(있으면 `popcorn_glory_`/`popcorn-glory.` 접두어).
- 다른 게임의 `docs/<게임>/`·세이브를 건드리지 않는다: 배포 전후 `git status docs/`에 `docs/popcorn-glory/`와 사이트 파일만 보인다.
- 세 실험의 실행은 서로의 상태를 공유하지 않는다(다시 시작 = 새 객체).
