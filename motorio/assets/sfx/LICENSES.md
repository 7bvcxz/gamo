# 소리의 출처와 라이선스

`assets/sfx/` 의 소리는 두 종류다.

1. **합성** — `tools/build_sfx.py` 가 표준 라이브러리만으로 만든다. 외부 원본이 없고 라이선스
   문제가 없다. `cc0/` 밖의 모든 WAV.
2. **CC0 녹음 가공** — `tools/build_cc0_sfx.py` 가 아래 팩을 내려받아 **zip 안의 `License.txt`에
   `Creative Commons Zero, CC0` 가 있는지 확인한 뒤에만** 가공한다(필터·자르기·페이드·피치,
   일부는 합성 레이어를 더한다). 원본 파일은 저장소에 두지 않는다. `cc0/` 의 모든 WAV.

라이선스는 추측하지 않는다. 원본 zip의 라이선스 파일로 확인한 것만 쓴다.

## 팩

| 팩 | URL | 라이선스 (zip 안 License.txt) |
|---|---|---|
| Kenney Impact Sounds 1.0 (2019-12-19) | https://kenney.nl/assets/impact-sounds | Creative Commons Zero, CC0 — http://creativecommons.org/publicdomain/zero/1.0/ |
| Kenney RPG Audio | https://kenney.nl/assets/rpg-audio | Creative Commons Zero, CC0 — http://creativecommons.org/publicdomain/zero/1.0/ |

크레딧은 의무가 아니지만 적어 둔다: Kenney (www.kenney.nl).

## 파일

| 바꾼 파일 | 원래 파일 | 팩 | 저자 | 라이선스 | 가공 |
|---|---|---|---|---|---|
| `cc0/pick_1.wav` | `impactMining_000.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 260 Hz / LP 9000 Hz, 0.42 s, + 합성 돌 몸통, + 합성 파편 |
| `cc0/pick_2.wav` | `impactMining_001.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 260 Hz / LP 9000 Hz, 0.42 s, + 합성 돌 몸통, + 합성 파편 |
| `cc0/pick_3.wav` | `impactMining_002.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 260 Hz / LP 9000 Hz, 0.42 s, + 합성 돌 몸통, + 합성 파편 |
| `cc0/pick_4.wav` | `impactMining_003.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 260 Hz / LP 9000 Hz, 0.42 s, + 합성 돌 몸통, + 합성 파편 |
| `cc0/pick_5.wav` | `impactMining_004.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 260 Hz / LP 9000 Hz, 0.42 s, + 합성 돌 몸통, + 합성 파편 |
| `cc0/cat_tap_1.wav` | `impactMining_000.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | pitch ×1.5, HP 700 Hz / LP 7500 Hz, 0.2 s, + 합성 돌 몸통 |
| `cc0/cat_tap_2.wav` | `impactMining_002.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | pitch ×1.7, HP 700 Hz / LP 7500 Hz, 0.2 s, + 합성 돌 몸통 |
| `cc0/cat_tap_3.wav` | `impactMining_004.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | pitch ×1.4, HP 700 Hz / LP 7500 Hz, 0.2 s, + 합성 돌 몸통 |
| `cc0/step_1.wav` | `footstep_snow_000.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 140 Hz / LP 8000 Hz, 0.3 s |
| `cc0/step_2.wav` | `footstep_snow_001.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 140 Hz / LP 8000 Hz, 0.3 s |
| `cc0/step_3.wav` | `footstep_snow_002.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 140 Hz / LP 8000 Hz, 0.3 s |
| `cc0/step_4.wav` | `footstep_snow_003.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 140 Hz / LP 8000 Hz, 0.3 s |
| `cc0/step_5.wav` | `footstep_snow_004.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 140 Hz / LP 8000 Hz, 0.3 s |
| `cc0/clink_1.wav` | `impactMetal_light_000.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 300 Hz / LP 6500 Hz, 0.25 s |
| `cc0/clink_2.wav` | `impactMetal_light_002.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 300 Hz / LP 6500 Hz, 0.22 s |
| `cc0/clink_3.wav` | `impactMetal_light_004.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 300 Hz / LP 6500 Hz, 0.2 s |
| `cc0/deliver_1.wav` | `impactTin_medium_000.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 280 Hz / LP 7000 Hz, 0.16 s |
| `cc0/deliver_2.wav` | `impactTin_medium_001.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 280 Hz / LP 7000 Hz, 0.16 s |
| `cc0/deliver_3.wav` | `impactTin_medium_002.ogg` | Kenney Impact Sounds 1.0 | Kenney (www.kenney.nl) | CC0 1.0 | HP 280 Hz / LP 7000 Hz, 0.13 s |
| `cc0/latch.wav` | `metalLatch.ogg` | Kenney RPG Audio | Kenney (www.kenney.nl) | CC0 1.0 | HP 220 Hz / LP 9000 Hz, 0.26 s |
| `cc0/creak.wav` | `creak3.ogg` | Kenney RPG Audio | Kenney (www.kenney.nl) | CC0 1.0 | HP 200 Hz / LP 8000 Hz, 0.34 s |
| `cc0/rustle_1.wav` | `cloth2.ogg` | Kenney RPG Audio | Kenney (www.kenney.nl) | CC0 1.0 | HP 250 Hz / LP 7000 Hz, 0.42 s |
| `cc0/rustle_2.wav` | `cloth4.ogg` | Kenney RPG Audio | Kenney (www.kenney.nl) | CC0 1.0 | HP 250 Hz / LP 7000 Hz, 0.38 s |
