# Popcorn & Glory — 테스트 목록

테스트를 추가하면 여기에 한 줄을 넣는다. 각 줄은 **무엇을 막는가**다.

## 한 줄로

```bash
popcorn-glory/tools/test_all.sh            # 헤드리스 → 배포 → 브라우저(빠른 묶음) → 보고서
popcorn-glory/tools/test_all.sh --slow     # + 실험마다 실제 3분(play180)
popcorn-glory/tools/test_all.sh --public   # 공개 URL을 대상으로(배포 없음)
```

보고서는 `tests/results/step07/report.md`·`report.json`이다(`POPCORN_REPORT_DIR`로 다른 폴더에). 공개 URL 대상 실행만 실패한 검사를 한 번 재시도하고, 재시도로 통과하면 `PASSED (on retry)`와 첫 시도의 오류를 남긴다(K12에서는 다른 세션의 도커 인터페이스 변동으로 `net::ERR_NETWORK_CHANGED`가 난다). 검사마다 PASSED, FAILED, SKIPPED(이유와 함께) 중 하나이고, git SHA, 빌드, 실패한 검사의 오류가 함께 남는다. 돌릴 수 없었던 검사는 PASSED가 아니라 SKIPPED다.

메모리가 5GB 미만이면 브라우저 단계를 기다린다. 10분이 지나도 그대로면 SKIPPED(memory)로 남긴다. K12는 메모리 고갈로 네트워크가 끊긴 적이 있다.

CI(`.github/workflows/popcorn-glory.yml`)는 `popcorn-glory/**`가 바뀔 때만 돌고, 헤드리스 검사(`tools/check.sh`)만 한다. 다른 게임에는 아무 부담이 없다.

## 기준 환경 (임계값의 근거)

- **기계**: K12(GMKtec NucBox K12, Ubuntu 24.04, 16코어, RAM 56.7GiB). 다른 세션들과 함께 쓰므로 부하 평균이 20–67, 스왑이 꽉 찬 때가 있다.
- **브라우저**: Playwright 1.64.1 + Chromium 156 headless shell. GPU가 없어 소프트웨어로 렌더한다.
- **FPS**: 같은 정지 화면이 30분 사이에 60과 39로 측정됐다. 그래서 FPS는 기록만 하고, 10 미만으로 무너질 때만 실패로 센다. 성능 문은 결정적인 값으로 세운다: 그리기 호출 ≤ 200(측정 최대 139), 조각 ≤ 400.
- **로딩**: 측정값 2.3–4.2초(엔진 wasm이 대부분)다. 문은 20초로 넉넉하게 둔다. 부하가 큰 기계에서 공개 URL을 연다는 전제다.
- **JS 힙**: 1분 플레이 동안 30MB 미만 증가.

## 헤드리스 (`tools/test.sh`, `tools/check.sh`)

| 파일 | 막는 것 |
|---|---|
| `unit/test_economy.gd` | 경제 파일 로드·가격 공식·업그레이드가 아무것도 바꾸지 않는 표(평평하거나 짧은 표) 거부, 살 수 있는 모든 단계에 기계 그림이 있음 |
| `unit/test_rules.gd` | 스텁 규칙: 누름 = 돈, 정확한 가격, 돈이 음수가 되지 않음, 프레임을 어떻게 잘라도 같은 결과 |
| `unit/test_variants.gd` | A/B/C 규칙: B의 판정(덜 익음·아깝다·완벽·조금 탐·탐)과 정확한 밀리초의 탐, 식는 동안 거절, 금색 폭, C의 8칸·폭발 중 채움·끝나는 순간의 다음 폭발, 결정성 |
| `unit/test_exploits.gd` | 구매 연타, 최고 단계 넘어 사기, B의 순서 어긋난 명령, C의 폭발 중 1,000번 누름, 큰 돈 |
| `unit/test_clock.gd` | 활동 시계: 정수 ms, 한 프레임 최대 0.25초, 이유가 있는 일시정지 |
| `unit/test_session.gd` | 로컬 기록: 마일스톤 한 번씩, 5초 이상 쉼, CSV |
| `unit/test_route.gd` | 주소(`#click` 등)·`?dev=1`·`?sound=off`·명령줄 |
| `unit/test_isolation.gd` | 소스에 `user://` 쓰기·브라우저 저장소·네트워크·다른 게임 경로가 없음, 오토로드 없음 |
| `unit/test_shapes.gd` | 둥근 사각형이 늘 삼각분할됨(몇 픽셀짜리 채움이 브라우저에서 깨졌다) |
| `unit/test_assets.gd` | 아틀라스가 SVG 원본과 맞음, 소리 13개 로드, SFX 버스 선언, export 필터와 `.gdignore` |
| `integration/test_app.gd` | 실제 입력: 선택 화면, 같은 프레임의 팝·돈, 손가락 하나 = 한 번, 업그레이드, 다시 시작·뒤로, 스페이스, 숨긴 탭, 3:00 |
| `integration/test_experiments.gd` | 실험별 실제 입력, 빠른 탭이 하나도 버려지지 않음, 효과 풀이 차도 새 조각을 삼키지 않음, 실행 사이 격리, 기계가 모양이 바뀔 때만 다시 그려짐 |
| `integration/test_sound.gd` | 순간마다의 소리, 음량 크게/작게/끔, 이정표 팡파르가 차임을 대신함 |
| `integration/test_states.gd` | 스프링·도약·효과가 가라앉음, 세 실험을 해도 `user://`가 그대로, 50번 재시작·전환 후에도 깨끗함 |

## 브라우저 (`tools/e2e.sh`, 실제 Web export)

| 스펙 | 막는 것 |
|---|---|
| `stub03.spec.mjs` | 스텁의 누름·업그레이드·다시 시작·뒤로·브라우저 뒤로 가기, 숨긴 탭, 3:00, 브라우저 저장소 없음 |
| `experiments04.spec.mjs` | 선택 화면 A·B·C, 실험별 주 행동(B는 실제로 누르고 있기), 탐이 막지 않음, 실행 사이 격리, **스프라이트가 흰 사각형이 아님**(동전 픽셀이 금색) |
| `sound05.spec.mjs` | 첫 동작 뒤 실제 출력 신호(RMS), 크게/작게/끔, `?sound=off` — 세 화면 모두 |
| `responsive07.spec.mjs` | 720×1280·1920×1080·360×640(DPR 3)·태블릿·가로 폰에서 잘림·겹침 없음, 돈 높이 ≥ 24px, 아이콘 ≥ 28px, 놀이 영역 ≥ 40%, 효과 줄이기·소리 끔 |
| `input07.spec.mjs` | 버튼에서 미끄러져 나가면 사지 않음, 기계에서 시작해 버튼에서 뗀 누름은 사지 않음, 더블클릭 = 한 번, 취소된 터치가 B를 잠그지 않음, 끌기가 페이지를 스크롤하지 않음, 키보드 |
| `progression07.spec.mjs` | **빨리 감기**(개발 훅)로 마일스톤 순서, 10번 연속 다시 시작, A→C→B→A 재진입 — 실시간 초보 플레이가 아님을 이름에 적음 |
| `perf07.spec.mjs` | 첫 그림까지의 로딩, 1분 플레이의 힙 증가, 최악의 폭발(C 최고 단계)의 그리기 호출·조각·FPS 붕괴, 탭 잠자기·깨어나기 |
| `play180.spec.mjs` | (느림) 실험마다 **실제 3분**: 체크포인트 캡처, 끝까지 계속 범, 그리기 예산, 다시 시작이 0에서 |
| `render_probe.spec.mjs` | (측정, 문 아님) 빌드 하나의 로딩·힙·단계별 그리기 비용 |

## 시뮬레이션 (`tools/selftest.gd`, `tools/sim/runner.gd`)

자동 시뮬레이션이고 사람의 플레이가 아니다. `runner.gd`는 21개 행동의 불변식(돈 ≥ 0, 돈 = 번 돈 − 쓴 돈, 살 수 있을 때만 구매)을 매 사건마다 검사하고, `--replay`로 브라우저 실행의 입력을 재생해 게임과 같은 결과인지 확인한다.
