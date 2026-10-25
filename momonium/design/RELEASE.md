# 웹 빌드와 배포 (Step 43)

## 한눈에

| 무엇 | 어디 |
|---|---|
| 게임 | https://7bvcxz.github.io/gamo/momonium/ |
| 시작 페이지 | https://7bvcxz.github.io/gamo/momonium/launch.html — 플레이 / 체험 섬 / 큰 섬 데모, 버전 |
| 데모 주소 | `…/momonium/?demo=full`(체험 섬), `…/momonium/?demo=large`(큰 섬). 저장되지 않음, 상단에 표시 |
| 버전 정보 | `…/momonium/version.json`: `pack`·`packSize`·`version`·`godot`·`source`(빌드한 커밋) |

렌더러는 **Compatibility**(`gl_compatibility`, 모바일도 같음). WebGL 2가 있는 브라우저면 된다.
스레드 없는 Web 템플릿(`web_nothreads`)이라 교차 출처 격리 헤더 없이 GitHub Pages에서 바로 돈다.

## 만드는 법 (재현 가능)

1. 소스를 먼저 커밋한다 (`version.json`의 `source`가 그 커밋을 가리키도록 — 커밋 전 배포는 `-dirty`).
2. `momonium/tools/deploy.sh`
   - 저장소의 `deploy-web.sh momonium`이 `docs/momonium/`에 Web export하고 팩·게임 페이지에 내용 해시를 붙인다.
   - 게시 중인 빌드와 새 빌드 둘만 남긴다(같은 빌드를 다시 내보내면 그 이전 빌드도 남긴다).
   - `version.json`에 버전·엔진·커밋을 적고, `web/launch.html`을 복사하고, `tools/check_release.py`로 검사한다.
3. `docs/`를 커밋하고 push한다. `tools/verify_release.sh`가 Pages 반영을 기다려 폰·데스크톱 스모크와 CI 결과를 본다.

**재현성:** 같은 소스는 바이트까지 같은 팩을 낸다(팩 이름 = SHA-256 앞 12자리). Step 43에서 같은 커밋을 두 번
내보내 `game-c1ca35911f8f.pck`가 그대로임을 확인했다. CI(`check.sh --export`)는 자기가 만든 팩의 해시를 게시된
`version.json`과 비교해 같으면 "reproducible", 다르면 경고를 남긴다(소스만 먼저 올라간 경우).

엔진: Godot 4.7-stable(official). CI는 같은 버전을 내려받는다(`.github/workflows/momonium.yml`).

## 무엇이 실리는가 (`tools/check_release.py`)

팩의 디렉터리를 직접 읽어 목록으로 확인한다.
- **들어가면 안 되는 것:** `tests/`·`tools/`·`design/`·`web/`
- **반드시 있어야 하는 것:** 데이터 표 7개, 4개 언어 번역, 스프라이트 아틀라스, 한·일·중 폰트, 소리 17개, 메인 씬
- 크기 예산 20 MB (0.42.0: 7.4 MB — 그중 4.8 MB는 일본어·중국어 줄바꿈에 쓰는 Godot의 ICU 데이터)

사이트 폴더를 함께 주면 다음도 본다.
- 고정 `index.html`과 `version.json`이 이 팩을 가리키는지
- 팩 이름이 내용 해시인지, 크기가 로더가 알리는 값과 같은지
- runner와 게임 페이지가 있는지, 게임 페이지가 부르는 `../engine/engine-*.js/.wasm`이 있는지
- 시작 페이지가 있는지

## 캐시와 업데이트

- **팩과 게임 페이지는 내용 해시 이름**이다. 내용이 바뀌면 주소가 바뀌므로 캐시가 낡은 것을 줄 수 없다.
- **고정 `index.html`**에는 배포 때의 팩 이름·크기가 적혀 있고, 추가 요청 없이 runner로 넘긴다.
- **runner**는 팩을 Pages → raw.githubusercontent → 같은 폴더의 `version.json` → 자기 빌드 순으로 찾는다. 캐시된 옛 index가 지워진 팩을 가리켜도 현재 팩을 찾는다.
- **직전 빌드를 하나 남긴다.** Pages의 10분 캐시 동안 옛 페이지를 받은 플레이어도 연다.
- **`api.github.com`은 로딩 경로에 없다**(IP당 시간당 60회 제한 — AGENTS.md).
- **세이브는 브라우저 저장소**(`user://` = IndexedDB와 localStorage 사본)에 있다. 빌드가 바뀌어도 이어지고, 저장 형식은 이전 버전을 이주한다. 데모는 저장하지 않는다.

## 브라우저 검사

- **스모크**(`tests/e2e/smoke.mjs`, 배포마다):
  - 폰(터치)과 데스크톱(마우스) 프로필에서 열려 그려지는지, 버전이 맞는지
  - 탭이나 클릭 한 번 뒤에도 오류가 없는지
- **E2E**(`tests/e2e/specs/`): `MOMONIUM_E2E_BASE`로 **공개 URL을 직접** 검사할 수 있다. Step 43은 땅 사기·5개 건설 선택지·특별 하위 메뉴·승급·RP 재배치·랜드마크 효과·데모·시작 페이지를 공개 빌드에서 돌렸다.

## HeyDive

AGENTS.md의 새 게임 규칙에 따라 등록 대상이다.
- 등록은 다른 프로젝트(`heydive-server`의 `GameService` 시드)에 코드를 넣고, 운영 중인 서버를 다시 빌드하는 일이다(`docker compose up -d --build server`).
- 그래서 사용자 확인 없이 하지 않는다.
- 등록할 값
  - 게임명: Momonium
  - `embedUrl`: `https://7bvcxz.github.io/gamo/momonium/index.html`
  - 상태: Release
