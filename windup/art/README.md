# art/ — 생성 원본 (게임에 들어가지 않는다)

- `raw/<이름>.png` — `imagegen` 원본. **커밋하지 않는다**(크다, `.gitignore`). 옆의 `raw/<이름>.png.json`(프롬프트·모델·참조·토큰,
  imagegen이 쓰는 사이드카)은 커밋한다 — 원본이 없어도 같은 요청을 다시 할 수 있다.
- `ref/green_*.png` — 생성 참조용 순수 초록 캔버스. `tools/art/build_art.gd --green`이 만든다.
- 이 폴더는 `.gdignore`라 Godot이 import하지 않는다. 게임이 쓰는 것은 `tools/art/build_art.gd`가 만든 `assets/art/`뿐이다.

절차와 출처는 `design/ART_GUIDE.md`.
