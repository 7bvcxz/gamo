# Popcorn & Glory

팝콘 기계 **하나**, 돈 **하나**, 주된 행동 **하나**로 시작하는 작은 게임. 먼저 서로 다른 3분짜리
실험 셋을 만들어 직접 해 보고, 재미가 확인된 쪽만 키운다(Fun First).

- 진행 기록(재개 지점): [`PROGRESS.md`](PROGRESS.md)
- 재미의 기준(10·30·60·180초): [`FUN_FIRST.md`](FUN_FIRST.md)
- 도구 실측: [`design/TOOLS.md`](design/TOOLS.md) · 작업 절차: [`design/WORKFLOW.md`](design/WORKFLOW.md)
- 개발 단계: GitHub Issues `Popcorn Step NN` (7bvcxz/gamo)
- 저장소 공통 규칙: 루트 [`AGENTS.md`](../AGENTS.md)

## 지금 상태

Step 01에서는 **문서만** 만든다. `project.godot`은 Step 03에서 생긴다 — 그전에는 이 폴더가
`deploy-web.sh`·`web/scripts/to-docs.mjs`가 '게임'이라고 부르는 것(루트 아래 `project.godot`이 있는
폴더)이 아니므로 어떤 빌드도 이 폴더를 보지 않는다.

## 고정 식별자 — 다른 게임과 섞이지 않게

| 무엇 | 값 | 왜 |
|---|---|---|
| 폴더 | `popcorn-glory/` | 루트 바로 아래의 독립 게임(AGENTS.md) |
| Godot `config/name` | `Popcorn Glory` | 데스크톱 `user://`(app_userdata) 폴더 이름이 된다. `&`는 경로에 넣지 않는다 |
| Web `user://` | **저장하지 않는다** (프로토타입은 매 실행 새로 시작) | Godot Web은 `user://`를 `persistentPaths: ['/userfs']` 하나에 둔다 — 같은 도메인(7bvcxz.github.io)의 **모든 Godot 게임이 같은 IndexedDB 폴더**를 쓴다(`docs/engine/engine-*.js`에서 확인). 저장이 필요해지면 파일 이름을 `user://popcorn_glory_*`로만 쓴다 |
| localStorage | `popcorn-glory.*` 키만 | 비교 점수표 같은 Godot 밖 페이지용. 다른 키를 읽거나 지우지 않는다 |
| 배포 경로 | `docs/popcorn-glory/` → `https://7bvcxz.github.io/gamo/popcorn-glory/` | `deploy-web.sh`의 규칙 그대로. 해시 PCK·공유 엔진 `docs/engine/` |
| 사이트 | `web/app/popcorn-glory/doc/`, Vercel 리다이렉트 `/popcorn-glory` | 새 게임 등록 네 곳 + 문서 페이지(AGENTS.md) |
| 테스트 브리지 | `window.popcorn` (테스트 표지가 있을 때만) | E2E가 상태를 묻는 유일한 길 |

## 폴더 (Step 03부터 채워진다)

| 경로 | 내용 | export |
|---|---|---|
| `design/` | 설계·도구·절차 문서 | 제외(`.gdignore`) |
| `scenes/`, `src/` | 게임 | 포함 |
| `tests/unit`, `tests/integration` | 헤드리스 GDScript 테스트 | 제외 |
| `tests/e2e` | Playwright 브라우저 검사 | 제외(`.gdignore`) |
| `tools/` | 테스트·캡처·배포 스크립트 | 제외 |
| `evidence/` | step별 증거 그림·기록 | 제외(`.gdignore`) |
