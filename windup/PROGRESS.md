# Windup 진행 기록 (재개 지점)

자율 개발이 끊겼을 때 여기서 다시 시작한다. GitHub 이슈("Windup Step NN")와 이 파일이 원본이며 대화 기억은 원본이 아니다.
각 step이 닫힐 때 갱신한다.

## 현재 상태

- 마지막 완료 step: 10 (#111) — 6세션 채점(개발자 + 빌드를 모르는 독립 채점자), 마찰 분류, 고침 하나(0.10.0: 힌트를 '누르는 손'으로)와
  블라인드 재검사 3번. 결과: 힌트를 타이머로 읽고 기다림 3/3 → 0/3, 첫 인형 −첫 감기 63–88초 → 50–52초, 그러나 누르고 있기는 2/3 → 1/3(손이 '클릭'으로 읽힘),
  30초 목표는 여전히 실패. `design/FUN_SCORES.md`. 사람 결과 없음(`design/HUMAN_PLAYTEST.md`)
- Step 09 (#109): 블라인드 AI 하네스 `tools/blind/`, 세션 3(+pilot), `design/BLIND_PLAYTESTS.md`
- Step 11 (#112): A/B/C 토너먼트 — 보존 빌드 `docs/windup/ref/step11/`(0.10.0), 변형마다 블라인드 3세션(순서 돌림), 독립 채점, 스크립트 입력 3분.
  결론 **검증된 승자 없음**, 다음 후보 C(낮은 확신), ITERATE. `design/TOURNAMENT.md`. **소유자 승인 대기**
- Step 12 (#113): **구현 차단** — 검증된 승자 없음 + 소유자 승인 없음. 제안서 `design/EXPANSION_PROPOSAL.md`(다듬기 순서, 확장 사다리 4칸과 죽이는 조건, 출시 빈 곳). 이슈는 열어 둠
- 다음: 소유자가 (가) C 승인 / (나) 사람 테스트 뒤 결정 / (다) 다른 변형 중 하나를 고르면 Step 12 다듬기를 시작
- 변형: 기준·A(스프링)·B(깨어남)·C(연쇄), `?variant=a|b|c`, 고르는 페이지 `docs/windup/variants.html`(`design/VARIANTS.md`)
- 페이스: `tools/pacing_lab.gd`, 0.8.0 튜닝(첫 몫 55·첫 인형 1.8/초·둘째 160), `design/PACING.md`
- 규칙은 `src/game/atelier.gd`(순수), 수치는 `data/balance.json`만. 실제 규칙 페이스 표: `godot --headless --path windup --script res://tools/pace.gd`
- 그림 생성: OpenAI 크레딧 소진(2026-11-03 HTTP 429), TopView는 매 호출 사용자 승인 필요 → 래스터 경로는 준비만 됨(`design/ART_GUIDE.md`)
- 버전 규칙: `config/version` = `0.<step>.<재배포 횟수>` (Momonium과 같은 방식)
- 배포: 소스 커밋 → `windup/tools/deploy.sh`(공용 `deploy-web.sh` + 새 팩과 공개된 팩만 남김) → (사이트 변경 시) `cd web && npm run build:pages` → docs 커밋 → rebase·push →
  공개 URL 확인(`WINDUP_E2E_BASE=https://7bvcxz.github.io/gamo/windup/ windup/tools/e2e.sh`)
- HeyDive 등록: **보류** — 운영 서버(heydive-server, 다른 프로젝트)의 시드와 재빌드가 필요해 사용자 승인 대기(Momonium과 같은 상태)
- 검사: `windup/tools/check.sh [--export]`(CI와 같음), 브라우저 `windup/tools/e2e.sh`
- 설계: `design/CORE_LOOP.md`(루프·시간표·가설·계측·제외·MVP 끝), `design/PLAYTEST_3MIN.md`(3분 측정과 4×5 평가표)

## 작업 방식

1. 이슈 본문을 읽는다(`gh issue view <n> --repo 7bvcxz/gamo --json title,body,updatedAt`). 닫기 직전에 `updatedAt`을 다시 본다.
2. 이 게임은 `windup/` 안에만 둔다. 다른 게임을 건드리지 않는다. 공용 등록(사이트 네 곳, `Progress.md`)만 예외.
3. 작업 트리는 `/home/merti/Workspace/gamo-windup`(worktree, 브랜치 `windup-work`) — 같은 저장소의 다른 세션이
   메인 체크아웃에서 일한다. `git fetch && git rebase origin/main` 뒤 `git push origin HEAD:main`.
4. 이슈에 한국어 완료 댓글(상태·변경·테스트·플레이 증거·커밋·남은 문제) → 수락 기준을 실제로 확인했을 때만 닫는다.

## Step 기록

| step | 이슈 | 내용 | 커밋 |
|---|---|---|---|
| 01 | #94 | 핵심 루프·3분 명세 | `a57c3120` |
| 02 | #95 | 프로젝트·시계·계측·브리지·검사·CI·Web·사이트 등록 (0.2.0) | `80b94b0d` `a42e3a5d` `a9ccda72` |
| 03 | #96 | SVG 그림·인형 리그·그림 가이드·래스터 경로(차단) (0.3.0) | `00529de0` `f973d800` `42687b46` |
| 04 | #97 | 규칙·감기·인형 12·도우미·빛·소리·저장·다시 시작·3분 실제 플레이 (0.4.0) | `a78b623d` `7768abc0` |
| 05 | #102 | 손맛·톱니·방 소품·오르골·접근성, 블라인드 AI 순서 맞히기 (0.5.0) | `3b23db41` `c48804ad` |
| V2 | 01–05 | 이슈에 붙은 V2 절 따라잡기(첫 3분 스토리보드·흔들림/번쩍임 제거·성격·도우미 줄) (0.5.1) | `2fda2062` `5bf6e41b` `12e4a688` |
| 06 | #103 | 같은 규칙 위의 세 변형 A·B·C와 고르는 페이지 (0.6.0) | `91295099` |
| 07 | #104 | 실제 시뮬레이션 정확성 행렬, 결함 셋 수정(멈춤 중 클릭·열쇠 스프링 폭주·깨진 저장 로그) (0.7.0) | `106ce1bc` |
| 08 | #105 | 페이스 실험실과 데이터만의 튜닝, 말 없는 누르고 있기 힌트 (0.8.0) | `a743bba3` |
| 09 | #109 | 블라인드 AI 플레이 하네스·격리 검사·세션 3(+pilot) | `731ea2b8` |
| 10 | #111 | 채점·마찰 분류·힌트를 누르는 손으로(0.10.0)·블라인드 재검사 3 | `901fb212` `ffde8165` |
| 11 | #112 | A/B/C 토너먼트(보존 빌드, 변형마다 블라인드 3, 독립 채점), 승자 없음·C 후보·승인 요청 | `6d6fd505` `c49ea3fa` |
| 12 | #113 | 차단 — 제안서만(승인 대기) | (이 커밋) |
