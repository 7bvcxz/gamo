# 도구 실측 (Step 01, 2026-11-03, K12)

짐작하지 않고 이 머신에서 실제로 불러 본 결과다. 돈이 드는 생성은 하지 않았다.
'확인'은 명령을 실행해 출력을 본 것, '문서'는 도구의 README에만 근거한 것이다.

## 엔진·빌드

| 도구 | 확인한 명령 | 결과 |
|---|---|---|
| Godot | `godot --version` | `4.7.stable.official.5b4e0cb0f` (`~/.local/bin/godot`). momonium과 같은 버전으로 고정 |
| Web 템플릿 | `ls ~/.local/share/godot/export_templates/4.7.stable` | `web_nothreads_debug.zip`, `web_nothreads_release.zip` (단일 스레드만 있음 → preset은 `thread_support=false`) |
| 렌더 캡처 | `xvfb-run -a -s "-screen 0 800x900x24" godot --path <p> --audio-driver Dummy --script <cap.gd> -- out.png` (SubViewport → `save_png`) | 360×640 PNG 저장, 가운데 픽셀이 그린 색 그대로 (0.96, 0.77, 0.26) |
| 헤드리스 캡처 | 같은 스크립트를 `--headless`로 | **60초 뒤 강제 종료** — 더미 렌더러는 텍스처를 주지 않는다(AGENTS.md 2026-07-22 교훈 재확인). 헤드리스는 로직 테스트에만 |
| 공유 배포 | `deploy-web.sh` 읽음 | 루트의 `project.godot` 폴더를 Web export → 엔진은 `docs/engine/` 하나, PCK·HTML에 내용 해시, 고정 `index.html` + `runner-v2.html` + `version.json` |
| 사이트 | `web/package.json` 읽음 | Next 16.2.11, `npm run build:pages`가 `docs/`에 넣는다. 게임 등록 네 곳: `web/app/page.jsx`, `web/app/doc/page.jsx`, `web/components/content/WhatIsGamo.jsx`, `web/vercel.json` + `web/app/<게임>/doc/page.jsx` |

## 브라우저·증거

| 도구 | 확인한 명령 | 결과 |
|---|---|---|
| Playwright | `NODE_PATH=momonium/tests/e2e/node_modules node pw_check.cjs` (720×1280, 터치, 스크린샷) | 1.64.1, Chromium 156.0.8078.4, PNG 저장. **ESM `import`는 `NODE_PATH`를 무시한다** — 첫 시도(`.mjs`)는 모듈을 못 찾았고 `require`(`.cjs`)로 됐다. Step 03의 e2e는 자기 `package.json`·`node_modules`를 둔다 |
| Chromium 빌드 | `ls ~/.cache/ms-playwright` | `chromium-1228`·`1237`·`1248`, headless shell 1228·1248 |
| ffmpeg | `ffmpeg -encoders` / `-decoders` | 7.0.2 static(`~/.local/bin`). 인코더 libx264·libvorbis·libopus·libmp3lame·libwebp·png·gif·apng, **H.264 디코더 있음** |
| 영상 왕복 | `testsrc` → `libx264` mp4 1초 → `fps=4` PNG | 4장 추출 성공. Playwright가 받는 `ffmpeg-1011`은 디코더가 0개이므로 쓰지 않는다(AGENTS.md) |
| GitHub | `gh auth status` | `7bvcxz` 로그인, ssh. 이슈 코멘트·close 가능 |

## 그림

| 도구 | 확인한 명령 | 결과 |
|---|---|---|
| imagegen | `imagegen "<prompt>" --out x.png --quality low --dry-run` | 요청만 출력, "호출하지 않았습니다. 요금 0원." 키 파일 `~/.config/workspace/secrets.env` 존재(600) |
| 사용 기록 | `imagegen --ledger` | 지금까지 102회·105장(입력 79,063 / 출력 129,841 토큰). 호출마다 `<out>.png.json` 사이드카 |
| 제약(문서) | — | `gpt-image-2`(기본)는 투명 배경 불가, `gpt-image-1`만 가능. 크기 1024² / 1024×1536 / 1536×1024. low가 medium보다 출력 토큰 약 1/9(루트 Progress.md 2026-08-13 실측) |
| 배경 제거 | `command -v rembg convert magick` | **없음.** Pillow·pip도 없음 → Godot `Image` API로 크로마키(`motorio/tools/art/key_buildings.gd`가 선례) |
| 스프라이트 시트 | — | PIL 기반 `motorio/tools/sprite/*.py`는 **실행 불가**. 시트 조립·자르기는 Godot 헤드리스 스크립트로 |
| SVG | `command -v inkscape rsvg-convert` | 없음. momonium은 Godot으로 SVG→아틀라스(`tools/art/build_atlas.gd`) |
| TopView (영상) | `topview-credits` | **실패: "Could not read the balance"** — 이 세션에서 MCP가 인증되지 않음. 쓰려면 사용자가 `claude mcp login plugin:topview-browser:topview-browser`. 모든 생성은 크레딧 차감, 실행 전 사용자 승인 필요(`~/Workspace/tools/topview/CLAUDE.md`) |

## 소리

| 도구 | 확인한 명령 | 결과 |
|---|---|---|
| 합성 | `speaker.py tune "C6:0.25 E6:0.25 G6:0.5" --bpm 180 --timbre bell --out x.wav` | WAV 생성(표준 라이브러리만) |
| 인코딩 | `ffmpeg -i x.wav -c:a libvorbis -q:a 4 x.ogg` | Ogg 2.13초. momonium `tools/audio/build_audio.py`도 같은 길(합성 → Ogg 커밋) |
| 웹 소리 함정(문서) | — | 버스는 `default_bus_layout.tres`에 선언한다. 실행 중 `add_bus()`한 버스는 Web 샘플 재생에서 소리가 0이다(AGENTS.md 2026-10-27) |

## 배포 뒤 등록

| 대상 | 확인 | 결과 |
|---|---|---|
| HeyDive | `curl https://api.heydive.in/api/games` → `{"error":"내부 인증 실패"}`; `heydive-server/.../GameService.kt` grep | 공개 API로 등록할 수 없다. gamo 게임 중 **motorio만** 시드에 있다. 등록은 다른 저장소의 코드 변경 + 운영 서버 재빌드라 **사용자 확인 없이 하지 않는다**(momonium `design/RELEASE.md`의 선례) |

## 없는 것과 대안

| 없는 것 | 대안 | 막히는가 |
|---|---|---|
| 그림 생성 없이 시작 | 도형(`draw_*`)과 색으로 그린 기계·팝콘 — Step 04까지는 이것이 완성된 그림이다 | 아니오 |
| 배경 제거 CLI | 단색(순수 초록) 배경으로 생성 → Godot `Image`로 키잉 | 아니오 |
| 영상 생성(TopView) | 쓰지 않는다. 움직임은 코드(트윈·파티클)로 | 아니오 |
| 사람 플레이테스터 | 비교 페이지와 점수표를 주고 사용자가 직접 한다. AI 플레이는 객관 관찰로만 | 아니오 — 결론만 '잠정'이 된다 |
| HeyDive 등록 권한 | 정적 배포까지 하고, 등록은 미완료로 보고 + 사용자에게 필요한 값 전달 | 등록만 |
