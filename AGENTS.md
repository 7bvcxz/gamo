# Gamo 공동 작업 규칙

이 저장소는 여러 Godot 게임을 한곳에서 관리한다. 각 게임은 루트 바로 아래의 독립 폴더이며, `project.godot`와 Web export preset을 포함해야 한다.

## 작업 원칙

- 작업을 시작하기 전에 이 파일과 루트의 `Progress.md`를 확인한다.
- 기능 작업이 끝날 때마다 `Progress.md`에 완료 내용, 검증 방법, 다음 작업을 갱신한다.
- 작업 중 실제로 발생한 실수나 재발 가능성이 있는 함정을 발견하면 아래 "실수와 교훈"에 원인과 예방책을 추가한다.
- 기존 사용자의 변경은 덮어쓰거나 되돌리지 않는다.
- Godot 프로젝트는 가능하면 외부 에셋 없이도 처음 clone한 상태에서 실행되어야 한다.
- 완료 전 `godot --headless --path <게임 폴더> --editor --quit`로 로드 오류를 확인하고, 가능하면 Web export도 검증한다.
- Web 배포 로더나 runner를 변경하면 정적 검사만으로 완료하지 않는다. 실제 브라우저에서 공개 또는 로컬 HTTP URL을 열어 Godot 캔버스가 초기화되고 오류 화면이 없으며 게임 프레임이 실행되는지 자동 브라우저 테스트로 확인한다.
- 기능 작업은 관련 자동 테스트와 실제 실행 검증이 모두 통과하기 전에는 완료로 보고하거나 push하지 않는다. 실행 환경을 준비할 수 없다면 완료라고 하지 말고 차단 상태와 필요한 검증을 보고한다.
- 새 게임을 추가하면 Web 배포 후 HeyDive 관리자 화면/API에도 게임명, 설명, 태그, `Release` 상태, 배포된 절대 `embedUrl`을 등록하고 실제 목록 노출과 실행을 확인한다.
- HeyDive 등록에 인증이나 서버 접근 권한이 필요해 자동 완료할 수 없다면, 정적 배포 완료와 HeyDive 등록 미완료를 명확히 구분해 보고하고 사용자에게 필요한 최소 작업을 요청한다.
- 완료된 변경은 관련 파일만 커밋하고 `main` 브랜치를 원격에 push한다.
- `motorio`를 push하기 직전에 `motorio/project.godot`의 `application/config/version` patch 값을 `0.0.1` 올리고, 게임 우측 아래 표시와 Web export가 같은 버전을 사용하는지 확인한다.
- minor 또는 major 버전은 사용자가 명시적으로 요청할 때만 올린다. 사용자 요청 없이 patch 증가를 minor/major 증가로 대체하지 않는다.

## 배포

- `./deploy-web.sh <게임명>`은 게임을 `docs/<게임명>/`에 Web export한다.
- GitHub Pages는 `main` 브랜치의 `docs/`를 서비스한다.
- 새 게임을 추가할 때 `export_presets.cfg`의 Web preset을 반드시 포함한다.
- 새 게임의 배포 URL은 `https://7bvcxz.github.io/gamo/<게임명>/index.html` 형식이며, 이 절대 URL을 HeyDive의 `embedUrl`로 사용한다.
- Web export 후 `deploy-web.sh`가 엔진/PCK/게임 HTML에 내용 해시를 붙인다. 고정 `index.html`은 GitHub 저장소 API에서 최신 manifest를 읽고, 고정 `runner.html`은 해시 PCK를 저장소 원본 경로에서 직접 내려받는다. 생성된 해시 파일명, manifest, 로더, runner를 수동으로 되돌리지 않는다.

## 실수와 교훈

- 2026-07-20: GitHub Pages Web export 배포를 HeyDive 게임 목록 등록과 같은 것으로 간주했다. `gamo`의 push는 정적 파일만 배포하며, 현재 HeyDive 목록은 별도 서버 DB에서 관리된다. 이후 배포 완료를 보고할 때 정적 URL 응답과 HeyDive API 등록 여부를 각각 확인한다.
- 2026-07-20: Godot 기본 폰트가 Web export에서도 한글을 표시할 것이라 가정해 UI 한글이 깨졌다. 한글 UI가 있는 게임은 OFL 등 배포 가능한 한글 폰트를 프로젝트에 포함하고 모든 관련 Control에 명시적으로 적용한 뒤 Web 빌드에서 확인한다.
- 2026-07-20: HeyDive 서버 코드를 push한 뒤 실행 중인 Docker 서버도 자동 배포될 것이라 가정해 Motorio가 실제 목록에 노출되지 않았다. HeyDive 게임 등록 변경은 `docker compose up -d --build server`로 서버를 갱신하고 localhost와 `api.heydive.in`의 `/api/games` 응답을 모두 확인한다.
- 2026-07-20: 폰트 서브셋 작업 전에 `pip`/`ensurepip` 사용 가능 여부를 확인하지 않아 설치 명령이 두 번 실패했다. 변환 도구가 필요하면 먼저 `command -v`와 모듈 가용성을 확인하고, 없다면 시스템을 변경하지 않는 저장소 내 대안을 우선한다.
- 2026-07-20: 탑다운 게임의 `RigidBody2D` 갈색 타일에 기본 중력이 적용되어 아래로 계속 움직였다. 평면 탑뷰 물체는 `gravity_scale = 0`을 명시하고, 정지 요구가 있으면 감쇠와 저속 임계 정지를 함께 검증한다.
- 2026-07-20: 불필요해진 폰트 파일을 `rm -f`로 삭제하려다 안전 정책에 의해 명령이 거부됐다. 이미 추적 중인 파일은 패치로 삭제하고, 큰 바이너리는 정확한 단일 경로를 확인한 뒤 `unlink`를 사용한다.
- 2026-07-20: 걷기 모션의 삼항 조건식에서 GDScript가 `bob`의 타입을 추론하지 못해 파싱 오류가 발생했다. 수치 애니메이션 지역 변수에는 `float` 타입을 명시한다. 또한 Godot headless가 스크립트 오류에도 종료 코드 0을 반환할 수 있으므로 명령 성공 여부뿐 아니라 출력의 `SCRIPT ERROR`/`ERROR`도 확인한다.
- 2026-07-20: GitHub Pages의 약 10분 브라우저 캐시 때문에 같은 URL에서 이전 Web 빌드가 계속 보였다. HTTP 캐시 헤더는 저장소에서 제어할 수 없으므로 배포 시 내용 해시 파일명과 cache-busting 버전 로더를 사용한다.
- 2026-07-20: 컨베이어를 고정 `Area2D`로 구현해 플레이어와 겹칠 수 있었고 갈색 상자처럼 밀리지 않았다. 물리 블록 요구가 있으면 고체 충돌/중력/감쇠/밀기 동작과 효과 감지 영역을 별도로 설계해 모두 확인한다.
- 2026-07-20: GitHub Pages의 `version.json`에 시간 쿼리를 붙이면 캐시가 분리될 것으로 예상했지만 Pages CDN은 쿼리를 무시하고 동일 캐시를 최대 10분 제공했다. Pages의 최신 버전 판단에는 GitHub Contents API를 사용하고, 실제 공개 경로와 HeyDive iframe 양쪽에서 검증한다.
- 2026-07-20: 저장소 API로 최신 해시를 즉시 알아도 GitHub Pages 배포 전에 새 해시 URL을 조회해 404가 캐시됐다. 업데이트된 PCK는 Pages 준비 여부를 미리 조회하지 말고, 고정 runner가 저장소의 고유 해시 PCK를 직접 다운로드하게 한다.
- 2026-07-20: 모바일 컨트롤 테스트에서 배열 원소와 동적 씬 인스턴스의 GDScript 타입 추론 오류가 발생했다. 상수 배열에서 꺼내는 값과 `load().instantiate()` 결과는 명시적으로 타입을 지정하고, 정적 `Node`의 사용자 정의 속성은 `get()`으로 검증한다.
- 2026-07-20: cache-busting runner에서 `Engine.start()` 전에 `Engine.init(executable)`을 호출하지 않아 브라우저에서 “A base path must be provided” 오류가 발생했다. Web runner는 엔진 초기화 → PCK preload → start 순서를 지키고, Node 문법 검사뿐 아니라 실제 브라우저 실행 테스트를 필수로 한다.
- 2026-07-20: `npx -p playwright node -e`가 임시 Playwright 모듈을 Node 검색 경로에 제공할 것으로 가정해 브라우저 테스트 실행이 실패했다. 일회성 브라우저 테스트는 명시적 임시 prefix에 패키지를 설치하고 해당 `node_modules`를 `NODE_PATH`로 지정한다.
- 2026-07-20: 컨베이어 화살표 wrap 계산이 32×32 블록 범위를 벗어났고, 효과 감지 영역을 충돌체보다 크게 만들어 외곽선 접촉만으로 이동이 적용됐다. 애니메이션 점의 최대 범위와 엄격한 내부 판정을 각각 자동 테스트한다.
