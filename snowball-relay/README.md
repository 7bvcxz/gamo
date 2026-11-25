# Snowball Relay

증분 게임 POC #1 (이슈 #162~#166, 버전 0.5.0). 질문: **손은 가끔만 쓰는데도 "계속 자라고 있다"는 느낌이 재미있는가?**

- 플레이: https://7bvcxz.github.io/gamo/snowball-relay/ · 문서: https://7bvcxz.github.io/gamo/snowball-relay/doc/
- 비교 보고서와 Go/Iterate/Discard 가설: [`../incre-poc/REPORT.md`](../incre-poc/REPORT.md) · 사람이 채우는 점수표: [`../incre-poc/SCORECARD.md`](../incre-poc/SCORECARD.md)
- 규칙 `scripts/Sim.gd`(그리기·입력 없음), 화면·입력 `scripts/Main.gd`, 로컬 지표 `scripts/Metrics.gd`.

## 직접 해 보기 (사람 평가용)
1. 새 게임으로 **3분**: 설명 없이 해 본다. 오른쪽 아래 칸(또는 버튼이 아닌 아무 곳)을 짧게 쓸어 눈덩이를 민다.
2. 선택: 실제 폰에서 **10분**, 편한 자세로(엄지 / 두 손 / 책상 위 검지; 좌우가 불편하면 ⇄).
3. **불편하면 즉시 멈춘다.** 끝나면 재미 0–10, 피로 0–10, 스스로 더 만졌는지, 다시 하고 싶은지를 적는다(점수표 `../incre-poc/SCORECARD.md`).
4. ⓘ → COPY로 지표(터치 수, 입력 시간 비율, 보상/분)를 붙여 두면 객관 수치가 남는다.

## 검사
- 헤드리스 규칙: `godot --headless --path snowball-relay --script res://tests/test_sim.gd`
- 입력 경제(합격선 연타/느긋 ≤ 2.5배): `... --script res://tests/scenarios.gd -- --write`
- 브라우저(실제 터치; `BASE`로 주소, `PLAYWRIGHT_DIR`로 Playwright 위치): `node snowball-relay/tests/e2e/{smoke,metrics,feel}.mjs`, 긴 세션 `session.mjs <low|spam> <초> <폴더>`
- 증거: `evidence/step01`~`step05`
