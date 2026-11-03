# Windup — 테스트 목록 (기능별)

무엇이 무엇을 막고 있는지. 숫자 커버리지가 아니라 기능별로 적는다(Step 07 V2). 테스트를 더하면 여기에 한 줄 넣는다.

## 돌리기

| 명령 | 무엇 | 끝 코드 |
|---|---|---|
| `windup/tools/test.sh [unit\|integration] [필터]` | 헤드리스 단위·통합. 출력의 SCRIPT ERROR·파스 오류·누수도 실패로 센다 | 실패 수(≥1이면 실패) |
| `windup/tools/smoke.sh` | 실제 씬을 헤드리스로: 누름 100번 → 인형 1, 회계 | 문제 수 |
| `windup/tools/check.sh [--export]` | import → 에디터 로드 → 위 둘 (+ Web export, 팩에 비게임 폴더 0) — CI와 같다 | 0 = 통과 |
| `windup/tools/desktop_play.sh <out> [WxH]` | **진짜 데스크톱 창**: Xvfb + OS 입력(XTEST) + 녹화 + 게임이 쓴 계측 | 엔진 오류 수를 출력 |
| `windup/tools/e2e.sh [spec] [--project desktop\|phone]` | 브라우저(로컬 `docs/` 또는 `WINDUP_E2E_BASE`). 실패하면 화면을 남긴다 | Playwright |
| `windup/tools/verify.sh [--long]` | 위 전부를 차례로(--long은 3분 플레이·프로필·변형 비교 포함), 단계별 끝 코드 표 | 실패한 단계 수 |
| `godot --headless --path windup --script res://tools/pace.gd -- --variant <v>` | 실제 규칙의 페이스 표(스크립트 플레이어 넷) | — |
| `godot --headless --path windup --script res://tools/pacing_lab.gd -- [--variant v] [--seeds n] [--set json]` | 페이스 실험실: 프로필 6(+가설 2) × 시드, p10/p50/p90, 실패 모양 표시(`design/PACING.md`) | — |
| `windup/tools/blind/run_session.sh <out> [url] [model]` | **블라인드 AI 플레이** 한 세션: 격리된 `claude -p`가 스크린샷만 보고 실제 마우스·키로 플레이, 영상·행동·게임 기록은 기록기가(`design/BLIND_PLAYTESTS.md`) | — |
| `windup/tools/blind/isolation_check.sh <out.txt>` | 같은 플래그의 플레이어에게 저장소·홈·네트워크를 읽게 시켜 **전부 거부되는지** | 새면 1 |
| `windup/tools/blind/rate_sessions.sh <out> <세션들>` | 독립 채점자: 도구 없는 `claude -p`가 섞인 이름표의 세션 기록만 보고 4×5 평가표로 채점(빌드를 모름) | — |
| `windup/tools/blind/selftest.sh` | AI 없이 기록기만: 응답에 스크린샷 경로·초 말고 아무것도 없는지, 행동·게임 기록·소리 있는 영상이 남는지 | 실패면 1 |

시드와 시간: 규칙은 난수를 쓰지 않는다(시드는 기록용). 시간은 `GameClock.advance`/`Atelier.tick`으로만 흐르므로 테스트는 시계를 손으로 민다.
브라우저의 FPS는 이 공용 머신의 부하에 흔들려 증거로만 남기고, 성능은 렌더 예산(≤150 호출, ≤420 객체)으로 검사한다.

## 기능별

| 기능 | 헤드리스 | 브라우저·창 |
|---|---|---|
| 설정·프로젝트·격리(다른 게임 경로 없음, 버스 선언, Web 프리셋) | `unit/test_project` | `boot02` |
| 실행 옵션(`?fresh` `?seed` `?variant` `?dev`) | `unit/test_run_config` | `boot02`, `select06` |
| 게임 시계·멈춤(포커스·숨김), 한 프레임 상한 | `unit/test_game_clock`, `integration/test_boot` | `play04`(blur/focus) |
| 계측(`{t, ev}`, JSON 줄, 상한) | `unit/test_telemetry` | 모든 플레이 스펙이 기록을 남김 |
| **힘 회계**(`energy = 감은 힘 + 자동 − 쓴 힘`) | `unit/test_atelier`(300초), `test_long_runs`(3/10/30/60분 × 4변형), `test_failures` | — |
| 감기 상한·누르고 있기·놓음 | `unit/test_wind_input`, `test_failures`(연타 10,000번), `test_boot` | `boot02`, `correct07` |
| **인형 상태 기계**(앞으로만, 한 번씩, 몫 한 번) | `unit/test_doll_states`, `test_atelier` | — |
| 경계(힘 0·거의·정확히 몫), 같은 틱의 자동 기여+해금 | `test_doll_states`, `test_failures` | — |
| 깨어남 후 자동 일, 도움(`help`) | `test_feel_view` | `correct07`(브라우저에서 도움 확인) |
| 모두 깨어난 뒤, 1시간 막다른 길 없음, 손 놓은 플레이어도 진행 | `test_failures`, `test_long_runs` | — |
| 저장·불러오기·복구(잘린 JSON, 다른 스키마, 이상한 값) | `test_atelier`, `test_robustness` | `play04`(새 페이지에서 이어 감) |
| 다시 시작(두 번 누름) | — | `play04` |
| 멈춘 동안 그림이 움직이지 않음 | `test_robustness` | — |
| 창 크기(1280×720·1920×1080·844×390), 화면 밖 인형 없음 | `test_failures` | `correct07`(창 크기를 바꾸며 클릭), `desktop_play`(1920×1080) |
| 그림 import 크기·아틀라스·예산 | `unit/test_art`, `unit/test_budgets` | `art03`(렌더 예산) |
| 애니메이션 발 고정·NaN | `integration/test_animation_qc` | — |
| 깨어남 애니메이션은 인형마다 한 번 | `test_robustness`(`wake_count`) | — |
| 느린 클릭에 말 없는 '누르고 있기' 힌트(20초 뒤 한 번, 누르면 사라짐; 0.10.0부터 손이 열쇠를 누른 채 손끝 고리가 참) | `unit/test_wind_input`, `unit/test_feel`(손 타이밍), `integration/test_robustness` | `hint10`(손의 픽셀·렌더 예산·오류 없음; 0.8.0 힌트에서는 실패함을 확인) |
| 노드·소리 플레이어가 늘지 않음, 고아 노드 0, 늦은 판의 프레임 비용 | `test_robustness` | — |
| 손맛·톱니·소품·떨림, 흔들림·섬광 없음 | `test_feel`, `test_feel_view` | `feel05` |
| 소리(신호로 잼): 잠든 동안 침묵, 오르골, 끄기 | `test_feel` | `feel05`(RMS) |
| 변형 A·B·C(데이터, 규칙, 저장, 빌드 id) | `unit/test_variants`, `test_variant_scene` | `variants06`, `select06` |
| 3분 실제 플레이(스크립트 플레이어), 프로필 셋 | — | `play04`, `profiles04` |
