# Android (Step 44)

## 요약

| 항목 | 값 |
|---|---|
| 패키지 ID | `com.heydive.momonium` (**스토어 등록 전 확정 필요** — 한 번 올리면 바꿀 수 없다) |
| 앱 이름 | Momonium |
| 버전 | 이름 = `config/version`(비워 두면 Godot이 쓴다), 코드 = `major×10000 + minor×100 + patch`(0.44.0 → 4400, `tools/android/build.sh`가 빌드 때만 적는다) |
| 아키텍처 | arm64-v8a (64비트 기기 전용. 2019년 이후 Play 요구 사항) |
| 렌더러 | Compatibility(OpenGL ES 3) — 웹과 같다 |
| 화면 | 세로 고정, immersive + edge-to-edge, HUD는 안전 영역(카메라 구멍·제스처 바) 안쪽 |
| 권한 | 없음 (인터넷도 쓰지 않는다 — 로컬 우선 혼자 하는 게임) |
| 저장 | `user://` = 앱 내부 저장소. 업데이트해도 유지, `user_data_backup/allow=true`로 기기 백업 대상 |
| 크기 | 디버그 APK 33.6 MB, 릴리스 APK 31.8 MB |

## 준비 (이 머신은 이미 됨)

- JDK 21, Android SDK(`build-tools` 35+, `platform-tools`)
- Godot 에디터 설정: `export/android/android_sdk_path`, `java_sdk_path`, `debug_keystore`
- Godot 4.7 **Android 템플릿**: `python3 momonium/tools/android/fetch_templates.py`
  - 1.3 GB 템플릿 묶음 전체가 아니라, HTTP 범위 요청으로 `android_debug.apk`·`android_release.apk` 두 파일(~230 MB)만 받는다.
- 프로젝트 설정 `rendering/textures/vram_compression/import_etc2_astc=true`: Android export의 필수 조건이다. 텍스처가 무손실 import라 웹 빌드는 그대로다.

## 빌드

```bash
momonium/tools/android/build.sh debug     # 디버그 키로 서명된 APK → momonium/build/android/
momonium/tools/android/build.sh release   # 릴리스 키로 서명된 APK
```

릴리스 키는 **저장소에 들어오지 않는다.** Godot이 환경 변수에서 읽는다.

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/안전한/곳/momonium-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=momonium
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...   # CI라면 시크릿
```

- 환경 변수가 없으면 `build.sh release`는 바로 멈춘다(확인함).
- Step 44에서는 스크래치 폴더의 임시 키로 릴리스 서명이 되는지만 확인하고 그 키를 지웠다.
- `export_credentials.cfg`는 `.gitignore`에 있다.
- 키 만들기(처음 한 번, 저장소 밖에서 보관 — 잃어버리면 같은 앱으로 업데이트할 수 없다):
  ```bash
  keytool -genkeypair -v -keystore momonium-release.keystore -alias momonium -keyalg RSA -keysize 4096 -validity 10000
  ```

## Play Store용 AAB (문서화된 절차, 아직 실행하지 않음)

AAB는 Godot의 **Gradle 빌드**가 필요하다(prebuilt 템플릿은 APK만 만든다). 디스크에 여유가 생기면 다음 순서로 한다.
1. Android 소스 템플릿을 받는다: `python3 momonium/tools/android/fetch_templates.py templates/android_source.zip`
2. 프로젝트에 설치한다: Godot 에디터 › 프로젝트 › **Android 빌드 템플릿 설치**. 그러면 `momonium/android/`가 생기고, 이것은 커밋 대상이다(`.gdignore` 포함).
3. 프리셋에서 `gradle_build/use_gradle_build=true`, `gradle_build/export_format=1`(AAB)로 바꾼다.
4. 위 릴리스 환경 변수를 두고 `godot --headless --path momonium --export-release Android build/android/momonium.aab`를 실행한다. 첫 실행 때 Gradle이 의존성을 받는다(수백 MB).
5. Play Console › 내부 테스트 트랙에 올린다. Play 앱 서명을 켜면 위 키는 '업로드 키'가 된다.

## 생명주기와 저장

| 일 | 처리 |
|---|---|
| 앱이 백그라운드로 (`NOTIFICATION_APPLICATION_PAUSED`·포커스 잃음) | 즉시 저장 |
| 앱이 닫힘 (`WM_CLOSE_REQUEST`) | 즉시 저장 |
| 돌아옴 | 프레임 루프가 멈춘 시간을 보고 오프라인 따라잡기(같은 규칙, 최대 8시간·이벤트 4만) |
| 백그라운드 소리 | '백그라운드에서는 조용히'(기본 켬) |
| 15초마다 | 자동 저장 |

## 실기기 검증 — Galaxy S23 (SM-S911N, Android 15), 2026-10-25

`~/Workspace/tools/coordination/resources/s23.md` 절차로 기기를 확보했고, 끝나면 앱을 지우고 기준 상태로 돌려 반납했다.

| 확인 | 결과 |
|---|---|
| 설치·실행 | `adb install` 2.0 s, 활동 시작 0.49 s(콜드), 튜토리얼 첫 단계까지 정상. 세로 고정, v0.44.0 표시 |
| 안전 영역 | 상단 HUD가 기본 여백보다 약 80 px 아래(카메라 구멍 아래)에 놓임 |
| 실제 탭 플레이 | 빈 칸 탭 → 5개 선택지 → 밭($10 → $0, +5 EXP) → 씨 뿌리기(+1 EXP, Step 42 단계 보상) |
| 저장·복원 | 홈 → `am force-stop` → 다시 실행: 씨 뿌린 밭·EXP 6·$0 그대로, 튜토리얼 다시 안 나옴, 지난 시간만큼 날짜 진행 |
| 백그라운드 → 복귀 | 75초 뒤(화면 꺼짐 포함) 복귀: Day 3 0:11 → Day 6 0:26, 섬이 이어서 돎 |
| 성능 (성능 표시) | 기본 섬 **120 fps**(디스플레이 120 Hz), 시뮬 0.02 ms, draw 199, 메모리 108 MB |
| 큰 섬 데모 (건물 192·모모 64, 전체 보기) | **104 fps**, draw 412, 메모리 114 MB |
| 배터리 절약 | 켜면 **30 fps** 고정(큰 섬에서도) |

## 알려진 한계

- 패키지 ID는 임시다. AAB와 Play 업로드는 절차만 있고 실행하지 않았다(디스크 여유 3.6 GB, Gradle 의존성).
- 배터리 소모는 USB 충전 중이라 직접 재지 못했다. 대리 지표는 30 fps 모드, 화면 밖 정지(Step 41), 백그라운드 무음이다.
- 기기 백업은 Android 정책(사용자 설정, 25 MB 한도)에 따른다. 세이브는 수십 KB다.
- 결제(Accelerator)는 넣지 않았다 — `design/RELEASE_CHECKLIST.md`의 '수익화(계획)'.
