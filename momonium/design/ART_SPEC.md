# Momonium 아트 사양과 파이프라인 (Step 04)

참조: `~/Workspace/download/momonium_*.png` (저장소 밖. 레퍼런스이지 스프라이트가 아니다).
수치는 `data/art.json`이 원본이고, `tests/unit/render`·`tests/unit/data`가 지켜지는지 검사한다.

## 1. 시점과 투영 — 모든 것의 공통 격자

- 논리 격자는 **정사각 타일**. 화면은 **45° 회전 + 지평선 위 50°**에서 내려다본 2.5D다(`projection.elevation_deg`).
  참조 이미지는 약 43°로 보이지만 Step 04 사양(50~60°)을 따른다 — 조금 더 위에서 보는 만큼 폰에서 탭할 면이 넓다.
- 타일 하나는 마름모: 폭 `tile_width` **128px**, 높이 `128·sin 50° ≈ 98px`(짝수로 반올림해 꼭짓점이 정수 픽셀).
- 수직 1(타일 한 변의 길이만큼의 높이)은 `128/√2 · cos 50° ≈ 58px`. 절벽 높이는 **0.62**(약 36px).
- 변환은 `src/render/projection.gd`(`IsoProjection`) **하나**가 한다. 섬·건물·모모·입력·카메라가 모두 이것을 쓴다.
  - `to_screen(논리, z)`, `to_logical(화면)`, `cell_at(화면)`, `cell_center(칸)`, `cell_corners(칸)`(북·동·남·서)
  - 이웃 칸은 **같은 꼭짓점을 비트 단위로 공유**한다 → 타일 이음매가 생기지 않는다(테스트).
  - 깊이 순서는 `x + y`. 화면 y와 같은 방향이라, 서 있는 점(origin 피벗) 기준 y-정렬과 일치한다.

## 2. 레이어 (뒤 → 앞)

`sky` → `ocean` → `island_ground` → `ground_decals`(밭 흙, 길) → `world_entities`(건물·모모·소품, **origin 기준 y-정렬**)
→ `effects` → `hud` → `panels` → `modal` (`art.layers.order`)

## 3. 팔레트 (`art.palette`)

참조 이미지에서 실제 픽셀을 샘플링해 정했다(낮·노을·밤 하늘, 바다 4단, 잔디 3단, 흙·돌, UI 패널, 모모).

| 대상 | 핵심 색 |
|---|---|
| 낮 하늘 | `#2693f8` → `#45b0fd` → 지평선 `#c0ddfc` |
| 노을 하늘 | `#8c6fb8` → `#dd8478` → `#fda35f` |
| 밤 하늘 | `#071a4f` → `#0e2f7c` → `#496dc3`, 달 `#fdecba` 계열 |
| 낮 바다 | 먼 바다 `#68b7fc`, 중간 `#2fb6f8`, 섬 가까이 `#139fe0`, 얕은 곳 `#2cd6dc` |
| 섬 | 잔디 `#a6d64b`/`#8cc63f`/`#6fae33`, 테두리 `#c8e86a`, 흙 `#c99a63`, 돌 `#c3bcb4` |
| UI | 남색 반투명 판 `#163f78` @ 62%, 흰 글자, 강조 `#ffd34d` |
| 모모 | 털 `#fffcf4`, 그늘 `#ebe3da`, 멜빵 `#f4dec5`, 볼 `#ffb7b0`, 눈 `#3b2620`, 윤곽 `#61504f`, 단추 `#d19363` |

## 4. 모모 — 지켜야 할 특징

흰 **늘어진 귀**(머리 옆으로 내려와 뺨 아래까지), 머리 위 **작은 털 뭉치**(새싹이 아니다), **갈색 눈**과 흰 하이라이트,
**분홍 볼**, **크림색 멜빵바지**와 단추 두 개, **바느질 선이 있는 앞주머니**. 작은 장식(참)은 없다.
갈색 윤곽선(`#61504f`). 특수 복장은 미래 직업용으로 남겨 둔다. 샘플: `assets/src/svg/momo_front.svg`.

## 5. 파이프라인

```
assets/src/svg/*.svg ──(tools/art/build_atlas.gd)──► assets/atlas/sprites.png + sprites.json
  assets/sprites.json (스케일·피벗)                       (영역, 피벗[px], 원본 해시, world_scale)
data/art.json 팔레트 ──(tools/art/build_textures.gd)──► assets/textures/{grass,dirt,stone}.png
```

1. **원본은 SVG**(벡터). 손으로 그리거나 다듬고, 래스터는 도구가 만든다. `assets/src/`는 `.gdignore`라 게임에 실리지 않는다.
2. **피벗에 이름이 있다.** 모든 월드 스프라이트에 `origin`(땅에 닿는 점)이 있어야 하고(테스트), 필요하면 `head`·`hand_r`·
   `center` 등을 더한다. 코드는 스프라이트를 왼쪽 위가 아니라 **서 있는 점**으로 놓는다(`SpriteLibrary.place`).
3. **아틀라스**: 투명 테두리를 잘라내고 선반(shelf) 방식으로 패킹한다. 2px 여백에는 가장자리 색을 알파 0으로 채워
   선형 필터·밉맵이 이웃 스프라이트를 끌어오지 않게 한다. JSON에 원본 SVG 해시를 적고, 원본이 바뀌었는데 다시
   빌드하지 않으면 테스트가 실패한다.
4. **지형 텍스처**는 고정 시드의 절차 생성이라 같은 입력이면 같은 바이트다. 잔디는 상하좌우, 흙은 좌우, 돌은
   상하좌우로 이어진다(잔디 이음 테스트). 섬 렌더러가 **논리 타일 공간의 UV**로 붙이므로 투영이 일관된다.
5. **가져오기 설정**: 축소되어 그려지는 그림은 `mipmaps/generate=true` + `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`.
   밉맵 없이 이 필터를 쓰면 조용히 plain linear가 된다(테스트가 `.import`를 검사).
6. **해상도 규칙**: 텍셀/월드픽셀 ≈ 2(`sprite_texels_per_world_px`). 폰 최대 확대에서도 계단이 보이지 않을 만큼.

### 명령

```bash
godot --headless --path momonium --script res://tools/art/build_atlas.gd
godot --headless --path momonium --script res://tools/art/build_textures.gd
godot --headless --path momonium --import          # 새 png 가져오기
xvfb-run -a godot --path momonium --script res://tools/capture.gd -- \
  --scene res://scenes/dev/art_gallery.tscn --out /abs/gallery.png --size 720x640
```

새 스프라이트: SVG 추가 → `assets/sprites.json`에 `source`·`scale`·`pivots`(월드 물체는 `origin`, `world_scale`) →
build_atlas → import → `scenes/dev/art_gallery.tscn`으로 확인.

## 6. 모바일 예산 (`art.budgets`)

| 항목 | 한도 |
|---|---|
| 아틀라스 한 장 | 2048×2048 |
| 반복 텍스처 한 장 | 512×512 |
| 텍스처 메모리 합(RGBA 기준) | 16MB |
| 웹 팩 | 20MB (`tools/check.sh --export`) |

현재: 아틀라스 512×256(4 스프라이트), 텍스처 3장, 합계 약 0.8MB.

## 7. 바다와 해안 (Step 08)

- **바다는 셰이더 한 장**(`assets/shaders/ocean.gdshader`, `OceanRenderer`). 배경 레이어의 화면 크기 사각형 하나가
  지평선 아래 모든 픽셀을 그린다. 픽셀마다 역카메라 변환 → 역투영으로 **물 평면의 논리 좌표**를 구해 그 위에서
  절차적 노이즈로 너울·반짝임을 만든다. 그래서 월드에 고정돼 있고, 타일 텍스처가 아니라 이음매·반복이 없다.
- **해안은 텍스처 하나**(`ShoreField`): 칸당 1텍셀 땅 표시를 네이티브 큐빅으로 키운 그림(땅 1, 해안선 0.5, 1타일
  밖 0). 셰이더가 이것으로 얕은 물·해안선 거품·바깥으로 퍼지는 거품 고리를 그린다. 섬 크기와 무관하게 픽셀당
  텍스처 조회 1회, 텍스처는 최대 512².
- 해 반사 기둥과 반짝임은 `sun_screen`·`sun_strength`로 하늘(Step 09)이 조절한다. `quality`는 저전력 모드용.
- **섬은 메시 세 장**(절벽·윗면·오버레이)으로 구워 그린다. 즉시 모드로 칸마다 그리면 30×30에서 1.9fps였고, 구운
  뒤 같은 장면이 33~42fps다(헤드리스 Chromium 소프트웨어 GL 기준). 땅이 바뀌면 프레임당 한 번만 다시 굽는다.
- 다른 섬·육지는 없다. 셰이더에는 섬 외의 땅 개념이 없고 테스트가 해안 텍스처에 섬 밖 땅이 없는지 본다.

## 8. 하루와 하늘 (Step 09)

- 하루는 시뮬레이션 시계의 30초. **Day N, 00초는 아침 햇빛**(참조 화면과 같다). 위상은 `balance.clock.phases`:
  낮 0~0.56 → 노을 0.56~0.70 → 밤 0.70~0.92 → 새벽 0.92~1.0. 밤을 신경 쓰는 모든 것은 `DayCycle`에 묻는다.
- 색은 `art.day_cycle`의 키프레임(아침·낮·노을·밤·새벽)을 보간한 `SkyPalette`. 하늘(위·중간·지평선), 바다 4단,
  월드 빛(`CanvasModulate`), 구름·그늘, 반짝임 색과 세기, 별 밝기를 한 번에 정한다. t=1은 t=0과 이어진다.
- 해는 0.94에 떠서 자정을 넘어 0.66에 진다(아침에 이미 떠 있다), 달은 0.64~0.97. 바다 반사는 떠 있는 쪽을 따른다.
- `DayNight`가 매 프레임 **시뮬레이션 시계**를 읽어 하늘 셰이더·바다 셰이더·월드 빛에 넣는다. 구름 이동과 별
  깜박임도 시뮬레이션 시간이라, 시계를 멈추면 하늘도 멈추고 빠르게 돌리면 하늘도 빨라진다.
- 하늘은 화면 위 **2/5**(`SkyRenderer.FRACTION`), 바다는 그 아래에서 시작한다(`OceanRenderer.HORIZON_FRACTION`).

## 9. 하지 않는 것

- 참조 이미지를 잘라 스프라이트로 쓰지 않는다(조명·원근·해상도가 섞여 있다).
- 전체 화면 AI 영상 루프나 무거운 물리로 바다·하늘을 만들지 않는다(셰이더·타일로, Step 08·09).
- 다른 섬·육지를 그리지 않는다.
