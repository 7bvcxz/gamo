# Gamo 진행 상황

마지막 업데이트: 2026-07-20

## motorio

- 상태: 첫 번째 플레이 가능한 프로토타입 완료 및 Web export 검증
- 목표: Factorio를 재해석한 탑뷰 2D 자동화 게임
- 완료 내용:
  - 32px 타일 기준 100×100 월드 생성
  - 640×640 뷰포트에 20×20 타일 표시
  - WASD/방향키 8방향 이동과 월드 경계 제한
  - 플레이어 추적 카메라와 현재 타일 좌표 UI
  - 절차적으로 그려지는 지형, 격자, 플레이어 비주얼
  - Web export preset 및 `docs/motorio/` 배포 파일 생성
- 검증:
  - `godot --headless --path motorio --editor --quit` 성공
  - `godot --headless --path motorio --quit-after 3` 런타임 오류 없음
  - `./deploy-web.sh motorio` Web export 성공
  - GitHub Pages의 `/gamo/motorio/` HTTP 200 응답 확인
  - Noto Sans CJK 폰트를 프로젝트에 포함하고 UI에 명시 적용해 Web 한글 깨짐 수정
  - 1×1 크기의 갈색 물리 타일 추가: 플레이어 충돌 시 밀리고 선형 감쇠로 정지
  - 플레이어 충돌체와 월드 외곽 물리 벽 추가
  - 한글/물리 타일 변경 후 headless 실행 및 Web export 재검증
  - UI에서 한글과 번들 폰트를 제거해 설명 없는 영문 좌표 UI로 단순화
  - 갈색 타일의 중력을 비활성화하고 미세 잔여 속도를 제거해 정지 상태 보장
  - 1×1 타일 안에 방향 표시와 걷기 바운스/다리 모션이 있는 간이 쿼터뷰 캐릭터 적용
  - Shift를 누르는 동안 이동 속도가 1.8배 증가하는 달리기 추가
  - 플레이어와 물리 상자를 오른쪽으로 운반하는 1×1 컨베이어 블록 및 흐르는 화살표 모션 추가
  - Motorio 버전을 0.0.5로 설정하고 게임 화면 우측 아래에 작은 버전 표시 추가
  - 0.0.6: 컨베이어를 갈색 상자와 동일하게 밀리고 정지하는 고체 물리 블록으로 변경
  - 0.0.6: 컨베이어는 주변 사물을 표시 방향으로 계속 밀도록 별도 감지 영역 유지
  - 0.0.6: 월드의 각 5×5 구역마다 갈색 상자와 무작위 방향 컨베이어를 각각 1개씩 배치
- 연동 조사:
  - HeyDive 게임 목록은 `heydive-server`의 PostgreSQL `game` 테이블에서 조회됨
  - `gamo` push를 감지하거나 새 게임을 자동 등록하는 webhook/워크플로는 현재 없음
  - `heydive-server` 시작 시 Motorio를 URL 기준으로 중복 없이 `Release` 등록하는 시드 구현 및 `main` push
  - 등록 URL: `https://7bvcxz.github.io/gamo/motorio/index.html`
  - Motorio HTML/WASM HTTP 200 및 CORS 허용 확인
  - HeyDive 서버 Docker 이미지를 재빌드·재기동하고 운영 DB 등록 완료
  - localhost 및 `api.heydive.in`의 `/api/games` 응답에서 Motorio `Release` 노출 확인
  - `heydive-client` 프로덕션 빌드와 `https://www.heydive.in/game` HTTP 200 확인

## 다음 작업

- 자원 종류와 채집 방식 설계
- 인벤토리 및 핫바 구현
- 첫 생산 설비 배치와 운송 시스템 구현

## 운영 규칙

- 앞으로 새 게임의 완료 범위에는 Godot 구현, Web export, GitHub push, HeyDive 게임 등록 및 실행 확인을 모두 포함한다.
- Web 배포는 내용 해시가 붙은 게임 파일과 최신 버전 로더를 생성해 브라우저의 이전 빌드 캐시를 우회한다.
- Motorio는 push 직전에 patch 버전을 0.0.1 올리며, minor/major는 사용자 요청이 있을 때만 변경한다.
