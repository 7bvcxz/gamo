# Snowball Relay

증분 게임 POC #1 (이슈 #162~#166). 질문: 손은 가끔만 쓰는데도 "계속 자라고 있다"는 느낌이 재미있는가?

- 플레이: https://7bvcxz.github.io/gamo/snowball-relay/
- 규칙 `scripts/Sim.gd`(그리기·입력 없음), 화면·입력 `scripts/Main.gd`.
- 헤드리스: `godot --headless --path snowball-relay --script res://tests/test_sim.gd` · 입력 경제 `... tests/scenarios.gd -- --write`
- 튜닝 봇: `... --script res://tests/bot.gd`
- 브라우저(실제 터치): `node snowball-relay/tests/e2e/play3.mjs <출력폴더> 180` (BASE로 주소 지정, PLAYWRIGHT_DIR로 Playwright 위치 지정)
- 증거: `evidence/`
