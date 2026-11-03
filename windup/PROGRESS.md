# Windup 진행 기록 (재개 지점)

자율 개발이 끊겼을 때 여기서 다시 시작한다. GitHub 이슈("Windup Step NN")와 이 파일이 원본이며 대화 기억은 원본이 아니다.
각 step이 닫힐 때 갱신한다.

## 현재 상태

- 마지막 완료 step: 04 (#97) — 첫 3분 프로토타입: 감기(누름·누르고 있기, 초당 6번 상한) → 태엽 힘 → 인형 12명이 차례로
  깨어나 다음 인형을 함께 감음, 단계별 빛, 효과음, 저장·다시 시작·멈춤, 계측. 실제 브라우저 3분 플레이 기록
- Step 05 (#102) 완료 — 톱니 열차·스프링 열쇠·실·떨림·불꽃·방 소품(재봉틀·재킷·시계)·오르골·접근성 아이콘. 규칙은 그대로
- 다음: Step 06 (#103) — 세 변형 A(손맛)·B(깨어남)·C(연쇄)
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
| 05 | #102 | 손맛·톱니·방 소품·오르골·접근성, 블라인드 AI 순서 맞히기 (0.5.0) | (다음 step에서 채움) |
