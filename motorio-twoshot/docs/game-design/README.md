# game-design

Motorio의 장기 설계 문서. 기능을 만들기 전에 읽고, 설계가 바뀌면 코드보다 이 문서를
먼저 고친다.

| 문서 | 다루는 것 |
|---|---|
| [`../../VISION.md`](../../VISION.md) | **단일 원본.** 무엇을 만들고 무엇을 만들지 않는가 |
| [`CORE_LOOP.md`](CORE_LOOP.md) | Explore·Heat·Cat·Automation·Logistics가 서로를 먹여 살리는 방식 |
| [`PROGRESSION.md`](PROGRESSION.md) | Level 0~10의 방향, 확정과 미확정 |
| [`WORLD_AND_STORY.md`](WORLD_AND_STORY.md) | Grim, 펭귄, 행성, 마을, 냥파편, 두 엔딩 |
| [`VERTICAL_SLICE.md`](VERTICAL_SLICE.md) | 첫 30분의 분 단위 설계 |
| [`CURRENT_STATE.md`](CURRENT_STATE.md) | 기존 구현과의 대조, P0~P4 우선순위 |

`VISION.md`가 이 폴더가 아니라 게임 폴더 루트에 있는 이유: 같은 내용을 두 곳에 두면
도구마다 다른 규칙을 따르게 된다는 것이 이 저장소가 `CLAUDE.md`/`AGENTS.md`로 이미
겪은 문제다. 사본 대신 링크를 둔다.

상태 표기 — `[확정]` 합의됨 · `[초안]` 바뀔 수 있음 · `[질문]` 사용자 결정 없이 구현 금지.
