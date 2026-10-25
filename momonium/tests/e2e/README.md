# Momonium 브라우저 검사

웹 빌드(`docs/momonium/`)를 실제 Chromium에서 조작한다. 처음 한 번 `npm install`.

| 무엇 | 명령 | 언제 |
|---|---|---|
| 배포 스모크 | `node smoke.mjs --url <URL> [--version x.y.z] [--pack game-*.pck]` | 배포마다 (E2E 아님) |
| E2E 전체 | `npx playwright test` | **Step 10·20·30·40 완료 시에만** |
| 새 케이스 하나 | `npx playwright test specs/<file>.spec.mjs` | 케이스를 쓰는 동안 |

- E2E는 저장소 `docs/`를 로컬 서버(기본 포트 18432, `MOMONIUM_E2E_PORT`)로 띄워 방금 export한 빌드를 연다.
  먼저 `./deploy-web.sh momonium`.
- 페이지에 `window.MOMONIUM_E2E = true`를 미리 심으면 게임이 `window.momonium.state()`·`command()`·
  `setTimeScale()`·`call()`을 연다(`src/platform/web_bridge.gd`). 상태 확인은 브리지로, 조작은 가능한 한
  실제 터치·마우스로 한다.
- 프로젝트 둘: `phone`(390×844, 터치)과 `desktop`(1280×800, 마우스).
