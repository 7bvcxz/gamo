# 실제 폰 — Galaxy S23 (Step 12, 2026-11-04 04:22–04:48 UTC)

SM-S911N, Android 15, Chrome 156.0.8078.79, 휴대폰 Wi-Fi. 조정 파일(`~/Workspace/tools/coordination/resources/s23.md`)로 빌리고 기본 상태로 돌려줬다.

- 손: 안드로이드의 실제 입력(`adb shell input tap/swipe/motionevent`). 상태: Popcorn 탭 하나에만 붙인 DevTools(CDP, `adb forward` → 그 탭의 WebSocket). 다른 탭은 건드리지 않았다.
- `run.log`·`s23_run.json`: 0.12.1 공개 빌드 — 첫 로딩, 위치 재기, 실제 누름, 3분 플레이(30초마다 단계·FPS·JS 힙·버퍼), 새로고침 이어하기, 홈 버튼.
- `audio_0.12.1.log`·`audio_0.12.2.log`: 페이지 출력 신호(오디오 스레드의 미터, `tests/e2e/lib/audio_tap.mjs`)를 실제 누름 동안. 피크 1.94 → 0.68–0.77.
- `apk_*.png`: 0.12.2 디버그 APK — 실행, 가게, 실제 누름 셋 뒤 30 동전, 강제 종료 뒤 다시 열어 30.
- `s23_*.png`: Chrome 화면(첫 화면·3분 뒤·새로고침 뒤). 첫 화면과 새로고침 뒤에 Chrome의 '번역하시겠습니까?'가 위쪽을 가린다 — 0.12.2의 페이지에서 막았다.
- 스크립트 사본: `cdp.mjs.txt`, `run.mjs.txt`, `audio.mjs.txt`, `cleanup.mjs.txt`(`node run.mjs <폴더> <분>`; 실행 전 S23을 빌린다).
- 처음 두 번의 실행은 시험 도구 문제로 멈췄다: 화면이 꺼져 숨은 탭이 로드되지 않음, 폰이 가로로 누워 있어 좌표가 화면 밖. 그 뒤 시험 동안만 화면 켜짐(`svc power stayon usb`)·세로 고정을 걸고 끝나면 되돌렸다.
