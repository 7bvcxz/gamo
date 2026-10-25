# 개발 환경과 도구 (Step 01)

2026-10-25 기준, 이 머신(Ubuntu 24.04, x86_64)에서 확인한 상태.

## Godot — 4.7.stable로 고정

- 실행 파일: `~/.local/bin/godot` → `4.7.stable.official.5b4e0cb0f`
- 같은 저장소의 다른 게임(motorio·gunslinger·looproom)도 4.7이며 Web 엔진 파일
  (`docs/engine/engine-*.wasm`)을 공유한다. **Momonium만 다른 버전으로 export하면
  엔진 사본이 하나 더 생기고 첫 로딩이 10MB 늘어난다.** 버전을 올릴 때는 저장소 전체를 함께 올린다.
- `project.godot`의 `config/features`가 `"4.7"`이다. 다른 버전의 에디터로 열면 경고가 뜬다.
- CI(Step 03에서 추가)도 같은 버전을 GitHub 릴리스에서 내려받아 쓴다.

## Export 템플릿

| 대상 | 상태 | 위치 |
|---|---|---|
| Web (단일 스레드) | 설치됨 | `~/.local/share/godot/export_templates/4.7.stable/web_nothreads_{debug,release}.zip` |
| Android | **없음** | Step 44에서 4.7.stable `.tpz`를 받아 같은 폴더에 푼다(아래) |

Web은 저장소의 다른 게임과 같이 **thread_support=false**다. GitHub Pages는
SharedArrayBuffer에 필요한 COOP/COEP 헤더를 보낼 수 없기 때문이다.

Android 템플릿 설치(Step 44):

```bash
V=4.7-stable
curl -L -o /tmp/godot-templates.tpz \
  https://github.com/godotengine/godot/releases/download/$V/Godot_v${V}_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.7.stable
unzip -j /tmp/godot-templates.tpz 'templates/android_*' 'templates/version.txt' \
  -d ~/.local/share/godot/export_templates/4.7.stable/
```

## Android SDK

- SDK: `~/Android/Sdk` (`ANDROID_HOME`), `platform-tools/adb`, `cmdline-tools/latest/bin/sdkmanager`
- JDK: `~/.local/share/jdk/jdk-21.0.12.1+1`
- 에디터 설정(`editor_settings-4.7.tres`)에 두 경로와 디버그 키스토어
  (`~/.local/share/godot/keystores/debug.keystore`)가 이미 등록돼 있다.
- 실기기(S23)는 공용 자원이다. 쓰기 전에 `~/Workspace/tools/coordination/resources/s23.md`를
  읽고 규칙대로 점유·해제한다.

## 브라우저 도구

- Playwright **1.64.1**(`tests/e2e/package.json`) — 이 머신에 캐시된 Chromium 1248과 짝이다.
- 로컬 서버는 저장소의 **`docs/`를 루트로** 띄운다. 게임 HTML이 `../engine/`을 참조하기 때문에
  게임 폴더에서 띄우면 엔진이 404가 된다. 띄운 뒤 `curl`로 내 파일이 나오는지 확인한다.

## Godot MCP 평가 — `Coding-Solo/godot-mcp`

Claude Code에서 Godot을 다루는 MCP 서버 중 가장 널리 쓰이고(MIT) 소스가 한 파일(`src/index.ts`,
2.2k줄)이라 검토가 쉬운 것을 골랐다. 평가 커밋 `1209744`(2026-04-16, "fix/rce-arbitrary-script-
instantiation" 병합 직후). 프로세스 실행은 셸을 거치지 않는 `execFile` 인자 배열이다.

임시 폴더에 받아 `npm ci`로 빌드하고, stdio JSON-RPC로 직접 말을 거는 스크립트로 확인했다.

| 도구 | 결과 |
|---|---|
| `get_godot_version` | 성공 — `4.7.stable.official.5b4e0cb0f` |
| `get_project_info` | 성공 — 프로젝트 구조 집계 |
| `create_scene`, `add_node` | 성공 — 프로젝트 사본에 `.tscn` 생성·노드 추가 |
| `run_project` / `get_debug_output` / `stop_project` | **디스플레이가 있어야 성공.** 헤드리스에서는 프로세스가 바로 죽고 "No active Godot process". `xvfb-run` 아래에서는 실행·로그·종료 모두 성공 |
| 스크린샷 | **기능 없음** |

결론: 장면 편집과 실행 로그에는 쓸 수 있지만, 이 프로젝트가 가장 자주 하는 일(헤드리스 테스트,
화면 캡처, Web export)은 CLI가 더 직접적이고 스크린샷은 MCP로 할 수 없다. 그래서
**Claude Code 설정에 등록하지 않고 CLI를 기본으로 쓴다.** 등록이 필요해지면:

```bash
git clone https://github.com/Coding-Solo/godot-mcp ~/Workspace/tools/godot-mcp
(cd ~/Workspace/tools/godot-mcp && npm ci)
claude mcp add godot -e GODOT_PATH=$HOME/.local/bin/godot -- node ~/Workspace/tools/godot-mcp/build/index.js
```

### MCP 없이 쓰는 CLI 대체 명령

| 하려는 일 | 명령 |
|---|---|
| 가져오기(import) | `godot --headless --path momonium --import` |
| 로드 오류 확인 | `godot --headless --path momonium --editor --quit` (출력의 `SCRIPT ERROR`를 본다 — 종료 코드는 0일 수 있다) |
| 실행 | `godot --path momonium` |
| 헤드리스 실행 | `godot --headless --path momonium --quit-after 5` |
| 테스트 | `momonium/tools/test.sh` |
| 스크린샷 | `xvfb-run -a godot --path momonium --script res://tools/capture.gd -- --out <png>` |
| Web export | `./deploy-web.sh momonium` |
