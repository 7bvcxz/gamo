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
- 연동 조사:
  - HeyDive 게임 목록은 `heydive-server`의 PostgreSQL `game` 테이블에서 조회됨
  - `gamo` push를 감지하거나 새 게임을 자동 등록하는 webhook/워크플로는 현재 없음
  - Motorio를 노출하려면 HeyDive 관리자 화면/API에 외부 embed URL을 별도로 등록하거나 자동 동기화 기능을 구현해야 함

## 다음 작업

- Motorio를 HeyDive 게임 목록에 `Release` 상태로 등록
- 자원 종류와 채집 방식 설계
- 인벤토리 및 핫바 구현
- 첫 생산 설비 배치와 운송 시스템 구현

## 운영 규칙

- 앞으로 새 게임의 완료 범위에는 Godot 구현, Web export, GitHub push, HeyDive 게임 등록 및 실행 확인을 모두 포함한다.
