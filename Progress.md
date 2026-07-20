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

## 다음 작업

- 자원 종류와 채집 방식 설계
- 인벤토리 및 핫바 구현
- 첫 생산 설비 배치와 운송 시스템 구현
