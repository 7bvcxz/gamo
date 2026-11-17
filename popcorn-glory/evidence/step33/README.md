# Step 33 증거 — 기계 44대 동시 운영

- `forty_p720.webm`, `forty_desktop.webm`: 공개 후보 빌드(0.33.0, 소스 c00d62ed)를 브라우저에서 탭으로 44대를 지은 뒤(층마다 줄은 개요 카드에서 삼) 90초 실시간 운영, 손이 1.2초마다 누름, 페이지 소리(MediaStreamDestination) 포함(최대 −5.9 / −6.7 dB). 같은 90초의 판매·인분·유지비는 `forty_*_stats.json`(p720: 61판매, 148인분, 유지비 59, 모든 인분의 자리 일치). 녹화 때의 부하는 `footage_load.txt`.
- `strip_p720.png`(15초 간격 6장), `strip_desktop.png`(30초 간격 3장): 영상에서 뽑은 프레임.
- `forty_720x1280.png`, `forty_1280x800.png`: Xvfb 실제 렌더(`tools/capture.gd --steps F,w20000`), `overview_*`: 30대 공장의 개요 카드와 진단 줄(`F30,…,O5`).
- `factory33_forty_*.png`, `factory33_overview_*.png`: 브라우저 시험 `factory33.spec.mjs`의 화면(세 크기).
- `perf.json`: 브라우저 시험의 배치(최소 자리 크기 폰 45·p720 30·데스크톱 21 px), 일한 기계, 멈춘 줄과 U08, 숨은 탭, 데스크톱 1분 성능(FPS 중앙값 19.2 @ 부하 10, 그리기 호출 약 900, 남은 힙 5.7 MB/분, 층별 다시 그리기). 비교 기준: Step 32의 기계 10대 공장(22.2 fps, 약 960 호출, 5.4 MB, 부하 8.4)과 0.12.2 가게의 R-01(1.5–5.5 MB/분).
- `draws.txt`, `draws_1280x800.png`: 화면 층을 하나씩 숨겨 잰 그리기 호출(`capture.gd --draws`). 기계 그림 텍스처 캐시 전 1,331 → 후 약 950.
- `bench.txt`: 모델 한 걸음(50 ms)의 비용과 내역(`tools/bench/forty.gd`). 같은 세션에서 고치기 전 1.94 ms, 고친 직후 0.66 ms, 증거를 찍을 때(부하 13) 0.91 ms.
- `economy/`: 경제 시뮬레이션(줄 없는 판은 Step 32와 같음), `FORTY.md` 44대 한 시간과 기계별 장부, U08 있음/없음.
