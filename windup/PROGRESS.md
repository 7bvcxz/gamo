# Windup 진행 기록 (재개 지점)

자율 개발이 끊겼을 때 여기서 다시 시작한다. GitHub 이슈("Windup Step NN")와 이 파일이 원본이며 대화 기억은 원본이 아니다.
각 step이 닫힐 때 갱신한다.

## 현재 상태

- 마지막 완료 step: 01 (#94) — 설계만. 게임 코드 없음
- 다음: Step 02 (#95) — 독립 Godot 프로젝트와 배포 기반
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
| 01 | #94 | 핵심 루프·3분 명세 | (다음 step에서 채움) |
