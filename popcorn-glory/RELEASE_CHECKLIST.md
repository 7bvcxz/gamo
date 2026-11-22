# 출시 후보 체크리스트 — Popcorn & Glory 0.48.1 (Step 48, #161)

> **상태: 출시 후보(Release Candidate) — 소유자의 Go/No-Go를 기다림.**
> - 외부 스토어 출시, 결제, 광고, HeyDive 등록은 하지 않았다. 웹 빌드는 지금까지의 모든 step처럼 Pages 주소에서 열리지만, 알리거나 목록에 올리지 않았다.
> - '재미'에 관한 말은 블라인드 AI의 대리 관찰이다. **사람의 점수는 아직 없다.**
> - 소유자용 한 장 요약은 `OWNER_REVIEW.md`이다.
> - 0.12.2(가게)의 출시 후보 체크리스트는 `git show 8b908442:popcorn-glory/RELEASE_CHECKLIST.md`로 볼 수 있다.

## 1. 무엇을 내놓는가

| | |
|---|---|
| 게임 | 3층 팝콘 공장(`#factory`). 선택 화면의 첫 칸이다(D-71). 0.12.x 가게(`#stand`)와 비교 기준판 A·B·C도 선택 화면에 남아 있다 |
| 버전 | **0.48.1** (`project.godot`의 `config/version`, 0.48.0 → 0.48.1은 선택 화면의 공장 칸) |
| 소스 | `ab57311a`(0.48.1) · `5b4bdad1`(0.48.0) · 배포 커밋 `40d187d9` |
| Web 주소 | https://7bvcxz.github.io/gamo/popcorn-glory/#factory · 선택 화면 https://7bvcxz.github.io/gamo/popcorn-glory/ |
| 팩·엔진 | `game-a0c5dc788068.pck`(1,007,040바이트) · 공유 엔진 `docs/engine/engine-7eda98958eb0.*`(wasm 39,509,339바이트, 압축 전) · Godot `4.7.stable.official.5b4e0cb0f` |
| 함께 있는 페이지 | [정보·개인정보·라이선스](https://7bvcxz.github.io/gamo/popcorn-glory/about.html) · [저장 복구](https://7bvcxz.github.io/gamo/popcorn-glory/saves.html) |
| 설치 | 필요 없다. 브라우저로 주소를 연다. 휴대폰은 세로가 가장 좋다 |
| 개인정보 | 계정·결제·광고·분석 없음. 게임 파일을 받는 것 말고는 요청을 보내지 않는다. 진행은 이 브라우저의 localStorage `popcorn-glory.factory.v1`(공장)·`popcorn-glory.stand.v1`(가게)에만 있다 |
| 문서 | `RELEASE_NOTES.md`(버전별), `STORE.md`(영어·한국어 설명, 사진, 맛보기 영상), `CREDITS.md`(권리 목록), `OWNER_REVIEW.md` |

## 2. 다시 만드는 법

```bash
git checkout ab57311a                   # 0.48.1의 소스
godot --headless --path popcorn-glory --import
popcorn-glory/tools/deploy.sh           # docs/popcorn-glory/ 에 해시 이름 팩 + index.html + version.json
popcorn-glory/tools/test_all.sh         # 헤드리스 -> 배포 -> 모든 브라우저 스펙 -> 보고서 (약 2시간 45분)
popcorn-glory/tools/test_all.sh --public  # 같은 묶음을 공개 주소에
```

- 배포 스크립트는 팩에 `res://design/`·`tests/`·`tools/`·`evidence/`가 있으면 실패한다.
- 4절의 매트릭스는 공개 주소의 팩 자체(`game-a0c5dc788068.pck`, `tests/results/step48/public_0481/version_tested.json`)를 시험했다. 그 팩은 커밋된 소스 `ab57311a`에서 배포됐다(`version.json`의 `source`).

## 3. 플랫폼별 상태 (사실대로)

| 대상 | 상태 |
|---|---|
| **Web (GitHub Pages)** | **출시 후보.** 4절의 매트릭스로 공개 주소에서 검증했다 |
| **Android (실제 폰)** | Samsung S23의 Chrome에서 공개 0.48.0의 공장을 확인했다(0.48.1과 같은 공장 코드): 로딩 3.7초, 새 공장 60fps, 실제 터치 누름 셋 = Perfect 셋, 새로 고침 뒤 저장 그대로, 오프라인에서도 팝과 판매, 44대 13.2fps. **디버그 APK 0.48.1:** 설치 → 선택 화면의 첫 칸이 공장 → 실제 누름 둘 → 강제 종료 뒤 다시 열면 공장이 그대로 → logcat에 게임 오류 없음 → 지움. Godot 디버그 키로 서명했으므로 배포용이 아니다. **릴리스 빌드는 없다** — 출시 서명 키와 스토어 계정은 소유자의 것이다 |
| PC (Windows·Linux·macOS) | **시험하지 않음.** 이 머신의 Godot export 템플릿은 Web과 Android뿐이다 |
| iOS | **시험하지 않음.** macOS·Xcode가 없다 |

## 4. 출시 매트릭스 (공개 0.48.1)

- **대상:** 공개 주소 https://7bvcxz.github.io/gamo/popcorn-glory/ 의 0.48.1(`game-a0c5dc788068.pck`, 소스 `ab57311a`). `tools/test_all.sh --public`, 2026-11-22 05:22–08:15 UTC(2시간 53분). 결과는 `tests/results/step48/public_0481/`(`report.md`, `report.json`, `run_info.json`, `version_tested.json`).
- **헤드리스:** 354 통과, 0 실패(검사 24,130개, 31파일, 698초).
- **브라우저:** **314 통과, 0 실패, 57 건너뜀**, 다시 돌려 통과한 것 0. 스펙 45개.
- **건너뜀 57개는 모두 스펙이 정한 것이다.** 같은 것을 한 화면에서만 잰다(예: '데스크톱이 소리를 잰다', '마우스 경로는 데스크톱에서', '브라우저 강제 종료는 한 번이면 된다'). 이유는 `report.md`의 각 줄에 있다. 실패해서 건너뛴 것은 없다.
- **돌리지 않은 스펙 5개:** `--perf`·`--slow` 묶음이다(`perf46` 벤치 표, `render_probe`, 실제 시간 3분 세션 셋). 성능 수치는 5절에 따로 있다.
- **부하:** 시작 2.20 → 끝 10.85(1분 평균), 남은 메모리 33.6GB, 스왑 거의 가득(8.0/8.2GB). 다른 세션과 나눠 쓰는 머신이다. 그래도 실패는 없었다.

| 표의 칸 | 뜻 |
|---|---|
| 숫자 | 그 화면에서 통과한 검사 수 |
| (+n 건너뜀) | 스펙이 다른 화면에서만 재도록 정한 검사 |
| 720×1280·390×844 | 터치(휴대폰 에뮬레이션) |
| 1280×800 | 마우스와 키보드 |

| 영역 | 스펙 | 720×1280 터치 | 390×844 터치 | 1280×800 마우스·키보드 | 다른 크기 5개 |
|---|---|---|---|---|---|
| 로딩·첫 화면 | `experiments04`, `factory16`, `negative46`, `perf07`, `release12`, `stub03` | 6 (+3 건너뜀) | 4 (+5 건너뜀) | 7 (+2 건너뜀) | — |
| 첫 플레이(누름·고리·여정) | `burst14`, `career39`, `factory16`, `journey46`, `ready47`, `stall09`, `ui44` | 9 (+1 건너뜀) | 8 (+2 건너뜀) | 10 | 0 (+5 건너뜀) |
| 입력(키보드·마우스·터치) | `input07`, `negative46`, `ui44` | 5 (+3 건너뜀) | 5 (+3 건너뜀) | 6 (+2 건너뜀) | 4 (+6 건너뜀) |
| 화면 크기 5개 더(720×1280·1920×1080·360×640·768×1024·844×390) | `responsive07` | — | — | — | 25 |
| 전체 라인(기계·맛·손님) | `career39`, `craft35`, `customers36`, `factory17`, `factory18`, `factory19`, `factory20`, `factory21`, `factory22`, `factory23`, `factory26`, `factory28`, `factory29`, `factory30`, `factory31`, `factory32`, `flavors34` | 20 (+5 건너뜀) | 20 (+5 건너뜀) | 25 | — |
| 높은 부하(44대·1분 최대·소리) | `factory33`, `perf07`, `soak43`, `sound43` | 2 (+2 건너뜀) | 2 (+2 건너뜀) | 4 | — |
| 뉴스 | `news37` | 1 | 1 | 1 | — |
| 대회 | `contests38` | 2 | 2 | 2 | — |
| 설정(움직임·소리) | `responsive07`, `soak43`, `sound43`, `ui44` | 2 (+1 건너뜀) | 2 (+1 건너뜀) | 3 | 5 (+5 건너뜀) |
| 저장·이주 | `negative46`, `release12`, `save45` | 4 | 4 | 4 | — |
| 오프라인·숨긴 탭 | `negative46`, `release12`, `sound43`, `stub03` | 4 | 3 (+1 건너뜀) | 3 (+1 건너뜀) | — |
| 복구(깨진 저장·강제 종료·내려받기·다시 시작) | `save45` | 3 (+1 건너뜀) | 3 (+1 건너뜀) | 4 | — |
| 그 밖(A·B·C, 가게, 그림, 움직임, 소리) | `art15`, `art40`, `art41`, `catalog27`, `experiments04`, `motion42`, `progression07`, `scorecard09`, `sound05`, `sound43`, `stand10`, `stub03` | 33 | 33 | 33 | — |
| 되돌리기(옛 빌드가 새 저장을 읽는가) | 브라우저 매트릭스에 없음 | — | — | — | — |

- **되돌리기에 대해 확인한 것:**
  - 옛 빌드가 새 저장을 읽는 것은 Step 45에서 옛 빌드 자신의 코드로 확인했다(0.43.0과 0.12.2의 worktree, `evidence/step45/fixtures/old_builds_read_045.log`).
  - 이번 매트릭스는 0.48.1의 저장이 여전히 schema 1임을 확인했다(`save45`의 첫 검사).
  - 배포를 실제로 되돌려(`git revert`) 보지는 않았다.
- **선택 화면의 공장 칸(D-71):**
  - `experiments04`의 '선택 화면' 검사가 세 화면 모두에서 목록이 공장부터 다섯 칸임을 확인했다. 그 검사는 A·B·C 칸만 눌러 연다.
  - 공장 칸을 눌러 여는 것은 S23의 디버그 APK에서 실제 탭으로 확인했다(3절).

## 5. 성능 (측정, 목표와 함께)

| 무엇 | 측정 | 목표 | 판정 |
|---|---|---|---|
| S23 새 공장 | 58–60fps | G-32 ≥ 55 | 통과 |
| S23 44대 | 13.2fps(0.48.0, 식은 폰), 0.46.2에서 16.6 → 데워진 뒤 10.5–12.2 | G-32 ≥ 55 | **미달**(출시 위험, `OWNER_REVIEW.md`) |
| K12 데스크톱 44대(소프트웨어 WebGL) | 13.8–15.3fps | 기록(D-69), Step 33 목표 20 | 목표 미달, 붕괴 바닥 통과 |
| 44대 JS 힙(GC 뒤) | 10분 1.98MB/분(K12), 5분 +7.1MB(S23) | G-30 < 2MB/분 | 간신히 통과 |
| 첫 프레임까지 | 1.98–2.23초(K12 로컬), 3.7–4.0초(S23 공개) | — | 기록 |
| 팩 | 1,007,040바이트 | — | 기록 |

## 6. 저장·이주·백업·되돌리기

- **저장.** 공장은 `popcorn-glory.factory.v1`에 저장한다. schema 1에 확인값이 든 봉투를 쓰고, 5초마다 쓰고 다시 읽어 확인한다. 1분 전 저장을 `.bak`에 두고, 거절된 저장은 `.rejected`로 따로 둔다(Step 45, `design/SAVES.md`).
- **이주.** 0.12.2 가게·0.22.0 공장·0.43.0 공장(44대) 고정본이 모두 열린다(`tests/fixtures/saves/`, `test_save45`). 0.43.0·0.12.2 빌드도 0.45 이후의 저장을 읽는다. 그래서 CDN이 10분 동안 옛 빌드를 줘도 저장을 잃지 않는다.
- **플레이어의 백업과 복구.** `saves.html`에서 모두 내려받기·가져오기·1분 전 저장으로 되돌리기를 할 수 있다.
- **배포 되돌리기(소유자·개발자).** `docs/popcorn-glory/`의 배포 커밋을 되돌리면 된다(`git revert 40d187d9`, 0.48.0으로; 더 앞이면 해당 배포 커밋). 이전 팩 하나는 같은 폴더에 남아 있어 캐시된 페이지도 열린다. 저장 형식은 0.45부터 같으므로 되돌려도 저장은 읽힌다(옛 빌드는 자기가 모르는 새 필드만 버린다).

## 7. 알려진 결함·한계 → `OWNER_REVIEW.md`의 '알려진 결함', `evidence/step47/README.md`의 마찰 목록

## 8. 소유자의 결정이 필요한 것

- [ ] Go / No-Go
- [ ] 알릴 곳(HeyDive 등록, 사이트 목록) — 하지 않았다
- [ ] Android 릴리스(서명 키, 스토어 계정) — 하지 않았다
- [ ] 사람의 플레이 평가 — 아직 없다
