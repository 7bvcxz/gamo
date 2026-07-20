# Gamo 공동 작업 규칙

이 저장소는 여러 Godot 게임을 한곳에서 관리한다. 각 게임은 루트 바로 아래의 독립 폴더이며, `project.godot`와 Web export preset을 포함해야 한다.

## 작업 원칙

- 작업을 시작하기 전에 이 파일과 루트의 `Progress.md`를 확인한다.
- 기능 작업이 끝날 때마다 `Progress.md`에 완료 내용, 검증 방법, 다음 작업을 갱신한다.
- 작업 중 실제로 발생한 실수나 재발 가능성이 있는 함정을 발견하면 아래 "실수와 교훈"에 원인과 예방책을 추가한다.
- 기존 사용자의 변경은 덮어쓰거나 되돌리지 않는다.
- Godot 프로젝트는 가능하면 외부 에셋 없이도 처음 clone한 상태에서 실행되어야 한다.
- 완료 전 `godot --headless --path <게임 폴더> --editor --quit`로 로드 오류를 확인하고, 가능하면 Web export도 검증한다.
- 새 게임을 추가하면 Web 배포 후 HeyDive 관리자 화면/API에도 게임명, 설명, 태그, `Release` 상태, 배포된 절대 `embedUrl`을 등록하고 실제 목록 노출과 실행을 확인한다.
- HeyDive 등록에 인증이나 서버 접근 권한이 필요해 자동 완료할 수 없다면, 정적 배포 완료와 HeyDive 등록 미완료를 명확히 구분해 보고하고 사용자에게 필요한 최소 작업을 요청한다.
- 완료된 변경은 관련 파일만 커밋하고 `main` 브랜치를 원격에 push한다.

## 배포

- `./deploy-web.sh <게임명>`은 게임을 `docs/<게임명>/`에 Web export한다.
- GitHub Pages는 `main` 브랜치의 `docs/`를 서비스한다.
- 새 게임을 추가할 때 `export_presets.cfg`의 Web preset을 반드시 포함한다.
- 새 게임의 배포 URL은 `https://7bvcxz.github.io/gamo/<게임명>/index.html` 형식이며, 이 절대 URL을 HeyDive의 `embedUrl`로 사용한다.

## 실수와 교훈

- 2026-07-20: GitHub Pages Web export 배포를 HeyDive 게임 목록 등록과 같은 것으로 간주했다. `gamo`의 push는 정적 파일만 배포하며, 현재 HeyDive 목록은 별도 서버 DB에서 관리된다. 이후 배포 완료를 보고할 때 정적 URL 응답과 HeyDive API 등록 여부를 각각 확인한다.
