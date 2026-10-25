# 테스트와 검증 (Step 03)

## 층

| 층 | 위치 | 무엇을 | 실행 |
|---|---|---|---|
| unit | `tests/unit/**/test_*.gd` | 로직 규칙: 시계·스케줄러·데이터·시스템·저장 | 매 step 전체 |
| integration | `tests/integration/**/test_*.gd` | 실제 씬을 SceneTree에 올리고 프레임·입력 이벤트로 조작 | 매 step 전체 |
| E2E | `tests/e2e/specs/*.spec.mjs` | 웹 빌드를 Chromium(폰·데스크톱)에서 실제 터치·마우스로 | **Step 10·20·30·40에만 전체**. 새 케이스는 단독 |
| 스모크 | `tests/e2e/smoke.mjs` | 배포된 URL: 로드·프레임·버전·탭 한 번 | 배포마다 |
| CI | `.github/workflows/momonium.yml` | import·로드 검사·unit+integration, main push에는 export+스모크 | `momonium/**` 변경 시 |

## 명령

```bash
momonium/tools/test.sh                  # unit + integration (가장 자주)
momonium/tools/test.sh unit sim         # id에 "sim"이 들어간 unit 케이스만
momonium/tools/check.sh                 # CI와 같은 검사: import → 에디터 로드 → 테스트
momonium/tools/check.sh --export        # + 임시 폴더로 Web export → 팩 크기·테스트 누출 → 브라우저 스모크
```

## 왜 GdUnit4가 아니라 자체 러너인가

GdUnit4는 좋은 도구지만 이 저장소에는 맞지 않았다.

- **오류를 실패로 세는 방법이 핵심이다.** GDScript 런타임 오류는 그 함수만 끝내고 실행은 계속되므로, 단언만
  세는 러너는 터진 케이스를 통과로 읽는다(이 저장소의 motorio에서 네 파일이 4주 동안 그랬다). Godot 4.5+의
  `Logger`(`OS.add_logger`)로 케이스마다 엔진 오류를 받아 실패로 세는 것은 러너 120줄로 된다.
- 플러그인 수백 파일과 에디터 버전 결합 없이, 처음 clone한 상태에서 `godot --script`만으로 돈다.
- 저장소의 다른 게임과 같은 방식(`extends SceneTree` 스크립트)이라 읽는 사람이 하나만 알면 된다.

규칙(`tests/framework/test_case.gd`):
- 테스트 파일은 `extends "res://tests/framework/test_case.gd"`. `class_name`을 쓰지 않는다(테스트는 export에서
  빠지므로 전역 클래스로 등록되면 안 된다).
- `func test_*()` 하나가 한 케이스. `await` 가능. `before_each`/`after_each`.
- 실패 = 단언 실패 **또는** 케이스 도중 엔진 오류. `tools/test.sh`는 출력의 SCRIPT ERROR·누수 경고도 실패로 센다.
- 씬을 띄운 테스트는 끝에 `queue_free()` 후 한 프레임을 준다(누수 경고가 실패이므로).

## 결정성

같은 명령을 같은 시각에 주면 같은 세계가 된다. `tests/unit/sim/test_simulation.gd`가
16ms·17ms·1s·95s 조각으로 진행한 이력을 비교하고, 저장→로드 뒤 두 세계가 같은 이력으로 이어지는지 본다.
새 시스템도 이 성질을 지켜야 한다: 시간은 `sim.now_ms()`만, 난수는 시뮬레이션 상태에 시드를 둔 RNG만.

## CI가 하지 않는 것

E2E 스위트는 CI에서 돌리지 않는다(마일스톤 Step에서만 사람이 아닌 개발 루프가 한 번 실행). CI의
브라우저 검사는 스모크 하나뿐이다.

## 함정

- **GDScript 람다는 지역 변수를 값으로 붙잡는다.** 람다 안에서 `flag = true`를 해도 바깥의 `flag`는 그대로다. 실제로
  "밤에는 시작하지 않는다" 검사가 이것 때문에 무엇을 하든 통과하고 있었다(Step 19에서 발견). 람다가 바꿔야 하는 값은
  배열·딕셔너리에 담는다(`var n := [0]` → `n[0] += 1`).
- **`sim.bus`에 연결한 람다가 `sim`을 붙잡으면 순환 참조로 누수**된다. `sim.clock`처럼 하위 객체만 붙잡는다.
- 씬을 띄운 테스트에서 입력은 `viewport.push_input(event, true)`(뷰포트 좌표)로 보낸다. 헤드리스에서는 창 크기가 0이라
  `Input.parse_input_event`의 좌표가 틀어진다. 실제 기기 순서(터치 → 합성 마우스)를 흉내 내야 할 때는 둘 다 보낸다.
- **덩어리 걸음은 목표 시간을 넘긴다.** `while t < T: advance_ms(chunk); t += chunk`는 chunk가 T를 나누지 않으면 T보다
  더 진행한다(9,999ms × 91 = 909,909 > 900,000). 걸음 크기 결정성 테스트가 "10초 걸음만 다르다"로 실패했는데 시뮬레이션은
  멀쩡했고 10초를 더 돌린 것이었다. 앞서 통과하던 같은 모양의 테스트들은 넘친 구간에 우연히 사건이 없었을 뿐이다.
  마지막 걸음은 `mini(chunk, T - t)`.
