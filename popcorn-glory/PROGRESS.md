# Popcorn & Glory 진행 기록 (재개 지점)

자율 개발이 끊겼을 때 여기서 다시 시작한다. 이슈와 이 파일이 원본이며 대화 기억은 원본이 아니다.
매 step이 닫힐 때 갱신한다. 각 step의 커밋 해시는 이슈의 완료 코멘트에 있다.

## 현재 상태

- 마지막 완료 step: **01** (#98) — 저장소·도구 실측, 고정 식별자, 작업 절차, Fun First 기준. 아직 `project.godot` 없음.
- 다음: **02** (#99) 세 실험 A Click & Pop · B Perfect Pop · C Pop Explosion 설계 → `design/`.

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
