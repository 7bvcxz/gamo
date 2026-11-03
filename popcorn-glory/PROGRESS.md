# Popcorn & Glory 진행 기록 (재개 지점)

자율 개발이 끊겼을 때 여기서 다시 시작한다. 이슈와 이 파일이 원본이며 대화 기억은 원본이 아니다.
매 step이 닫힐 때 갱신한다. 각 step의 커밋 해시는 이슈의 완료 코멘트에 있다.

## 현재 상태

- 마지막 완료 step: **02** (#99) — 세 실험 설계 `design/EXPERIMENTS.md`, 공정한 3분 절차·점수표 `design/PLAYTEST.md`,
  손 모델 `design/model/pace_model.py`(게임 아님). 아직 `project.godot` 없음.
- 다음: **03** (#100) Godot 토대와 웹 검사. 이어서 04(#101) 세 실험 구현 → 05 그림·소리 → 06 시뮬레이션 → 07 테스트 → 08 블라인드 AI →
  09 비교·추천(소유자 승인 요청). **10–12(#115–#117)는 소유자가 09의 방향을 승인하기 전에는 시작하지 않는다.**

## 작업 방식

`design/WORKFLOW.md`가 원본이다. 요약: 이슈 읽기 → `popcorn-glory/`만 구현 → 실제 검증 → 관련 경로만
`git commit -- <경로>` → `git pull --rebase` → push → 이 파일과 루트 `Progress.md` 갱신 → 이슈에 한국어 완료
보고 → close.

## Step 기록

### Step 01 — 저장소·도구 감사 (#98, 2026-11-03)

- 만든 것: `README.md`(고정 식별자), `FUN_FIRST.md`(10·30·60·180초 기준·기록 형식·점수표), `design/TOOLS.md`(실측),
  `design/WORKFLOW.md`(절차·검증·블라인드 분리·격리), `design/.gdignore`.
- 실측: Godot 4.7.stable + Web 단일 스레드 템플릿, Xvfb 렌더 캡처 됨 / 헤드리스 캡처 안 됨, Playwright 1.64.1 +
  Chromium 156, ffmpeg 7.0.2(H.264 디코딩 됨), imagegen dry-run(0원), 합성 소리 → Ogg.
- 없는 것: Pillow·pip·rembg·ImageMagick·Inkscape, TopView 인증(이 세션), HeyDive 등록 권한.
- 발견: Godot Web의 `user://`는 도메인 전체가 공유하는 `/userfs` 하나 → 프로토타입은 저장하지 않고, 저장이 필요하면
  `popcorn_glory_` 접두어. ESM `import`는 `NODE_PATH`를 무시한다 → e2e는 자기 `node_modules`를 둔다.

### Step 02 — 세 실험 설계 (#99, 2026-11-03)

- A Click & Pop(탭마다 즉시 터짐) · B Perfect Pop(누르고 있다가 금색 구간에서 떼기, 실패는 너그럽고 0은 없음) ·
  C Pop Explosion(8탭으로 채우면 연쇄 폭발, 그리는 조각 ≤ 400). 기계 하나·돈 하나·주 행동 하나·업그레이드 버튼 하나.
- 경제는 가설이다. 손 모델로 고른 값: A 탭당 팝 `[1,2,3,4,6,8,11,…]`·가격 `30×1.7^L`, B 한 판 `5×1.6^L`·가격 `25×1.9^L`,
  C 폭발 `10×2.2^L`·가격 `30×2.6^L`. 꾸준한 플레이어 기준 첫 업그레이드 9–14초, 3분에 Lv8–9.
- 모델이 잡은 것: 첫 가격 곡선은 A가 3분에 12단계를 넘겼다(너무 쌈). 반올림한 지수 표는 A의 1단계 업그레이드가 탭당 팝을
  바꾸지 않았다(1→1) — 눈에 보이는 변화가 없는 업그레이드라 명시적 표로 바꿨다.
