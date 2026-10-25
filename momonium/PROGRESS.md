# Momonium 진행 기록 (재개 지점)

자율 개발이 끊겼을 때 여기서 다시 시작한다. 이슈와 이 파일이 원본이며 대화 기억은 원본이 아니다.
매 step이 닫힐 때 갱신한다. 각 step의 커밋 해시는 다음 step에서 채운다(자기 커밋 안에는 적을 수 없다).

## 현재 상태

- 마지막 완료 step: **11** (#11)
- 현재 step: **12** — 맞닿은 1×1 땅 구매와 미리보기 (#12)
- 버전: `0.11.0`
- 테스트: unit+integration 113 통과 (`momonium/tools/test.sh`)
- E2E: 케이스 10파일(+select). Step 10 전체 실행 31/33 → 2건 수정 후 PASS. 다음 전체 실행은 Step 20
- 배포: https://7bvcxz.github.io/gamo/momonium/ (Pages, `docs/momonium/`) — `tools/deploy.sh` → push → `tools/verify_pages.sh`
- 막힌 것: 없음
- 보류: HeyDive 등록(AGENTS.md의 새 게임 규칙) — 플레이할 수 있는 내용이 생기는 Step 43에서 사용자 확인 후 진행

## 작업 방식 (재개할 때 지킬 것)

1. 이슈 본문을 읽고(`gh issue view <n> --repo 7bvcxz/gamo`) 기존 구현·의존성을 확인한다.
2. 구현 → 새 기능마다 자동 테스트(unit/integration) + E2E 케이스 추가(`tests/e2e/specs/`).
3. `momonium/tools/test.sh`로 unit+integration 전체 실행. 새 E2E 케이스는 **그 케이스만** 단독 확인.
   **전체 E2E 스위트는 Step 10·20·30·40 완료 시에만 한 번** (`cd momonium/tests/e2e && npx playwright test`).
4. 리뷰 후 버전 올림: `project.godot`의 `config/version` = `0.<step>.<재배포 횟수>`.
5. `momonium/tools/deploy.sh` → (사이트 변경 시) `cd web && npm run build:pages` → 관련 파일만 커밋 → `main` push.
6. push 후 `momonium/tools/verify_pages.sh`(Pages 반영 대기 → 공개 URL 스모크).
7. 이슈에 한국어 완료 코멘트(구현·변경 파일·추가 테스트·결과·E2E(해당 시)·배포 URL·문제와 해결·제한) → 검증 후 close.
8. 이 파일 갱신 후 다음 step.

다른 게임·`web/`의 다른 페이지는 건드리지 않는다. 커밋 끝에는 세션 attribution 줄을 붙인다.

## Step 기록

| step | 이슈 | 버전 | 커밋 | 테스트 | 배포 |
|---|---|---|---|---|---|
| 01 | #1 프로젝트·환경 | 0.1.0 | `0f37bf70` | unit 5 | 스모크 PASS (로컬·Pages) |
| 02 | #2 모듈 구조·설계 규칙 | 0.2.0 | `ebb32f58` | unit 24, E2E boot 단독 | 스모크 PASS |
| 03 | #3 테스트·검증·CI | 0.3.0 | `1d9f4101` | 30, E2E save 단독, CI success | 스모크 PASS |
| 04 | #4 아트 파이프라인 | 0.4.0 | `248f2bea` | 44, E2E art 단독, CI success | 스모크 PASS |
| 05 | #5 바다 세계·2×2 격자 | 0.5.0 | `bde1bce8` | 51, E2E world 단독, CI success | 스모크 PASS |
| 06 | #6 2.5D 섬 렌더링 | 0.6.0 | `3f008d7d` | 56, E2E island 단독, CI success | 스모크 PASS |
| 07 | #7 카메라·제스처 | 0.7.0 | `0ded785d` | 67, E2E camera 단독, CI success | 스모크 PASS |
| 08 | #8 끝없는 바다·해안 VFX | 0.8.0 | `c7558918` | 76, E2E ocean 단독, CI success | 스모크 PASS |
| 09 | #9 시계·하늘 | 0.9.0 | `df07b881` | 88, E2E sky 단독, CI success | 스모크 PASS |
| 10 | #10 미니멀 HUD | 0.10.0 | `96ad4c7b` (+CI 수정 `1e6aac55`) | 99, **E2E 전체 31/33(+3 skip), 실패 2 수정 후 재실행 PASS** | 스모크 |
| 11 | #11 탭·선택·행동 라우팅 | 0.11.0 | (다음 갱신 시) | 113, E2E select 단독 | 스모크 |
