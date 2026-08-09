extends RefCounted

## 손으로 설계한 고정 맵.
##
## GOAL.md가 절차 생성을 금지한다. 좌표도 색도 여기 적힌 값이 전부이고, 실행마다
## 달라지는 것은 없다 — 미니맵 없이 머릿속에 지도를 그리는 것이 이 게임의 가설인데,
## 매번 바뀌는 맵은 그릴 지도가 없다.
##
## 좌표는 방 단위 격자다. Vector2i(1, 0)은 시작 방의 동쪽, Vector2i(0, -1)은 북쪽.

const START := Vector2i(0, 0)

## 방 하나의 크기. 이 값이 곧 화면 하나다 (16 x 60 = 960, 9 x 60 = 540).
const COLS := 16
const ROWS := 9
const TILE := 60

## 18개 방. 배치는 이렇게 생겼다 (가로 = 동쪽, 세로 = 남쪽):
##
##                                (2,-3)
##          (-1,-2) (0,-2) (1,-2) (2,-2)
##          (-1,-1)               (2,-1)
##   (-2,0) (-1,0) ( 0,0) (1,0)   (2,0)  (3,0)
##                  (0,1)         (2,1)
##          (-1,2)  (0,2) (1,2)
##
## 큰 고리가 하나 있다: 시작 방에서 서쪽으로 나가 북쪽으로 돌아 동쪽으로 내려오면
## 다시 시작 방 옆으로 나온다. 미니맵이 없으니 이 고리를 스스로 알아채는 것이
## 이 게임에서 지도를 "그렸다"는 유일한 증거다. 막다른 방 다섯 개는 그 고리에서
## 벗어나는 선택이고, 벗어난 만큼 되돌아와야 한다.
##
## `mark`는 바닥 무늬다. 색만으로는 18개를 구분하기 어렵고, 색이 비슷한 두 방은
## 반드시 무늬가 다르다(`tests/test_map.gd`가 강제한다).
const ROOMS := {
	Vector2i(0, 0): {
		"name": "ATRIUM", "mark": "ring",
		"floor": Color(0.200, 0.100, 0.100), "accent": Color(0.620, 0.335, 0.335),
	},
	Vector2i(1, 0): {
		"name": "EAST HALL", "mark": "lanes",
		"floor": Color(0.120, 0.173, 0.300), "accent": Color(0.323, 0.439, 0.720),
	},
	Vector2i(2, 0): {
		"name": "CROSSING", "mark": "cross",
		"floor": Color(0.283, 0.400, 0.120), "accent": Color(0.600, 0.820, 0.292),
	},
	Vector2i(3, 0): {
		"name": "SECOND SEAL", "mark": "shards",
		"floor": Color(0.200, 0.040, 0.180), "accent": Color(0.620, 0.211, 0.569),
	},
	Vector2i(2, -1): {
		"name": "NORTH RUN", "mark": "lanes",
		"floor": Color(0.150, 0.300, 0.275), "accent": Color(0.389, 0.720, 0.665),
	},
	Vector2i(2, -2): {
		"name": "HIGH JUNCTION", "mark": "pillars",
		"floor": Color(0.400, 0.290, 0.160), "accent": Color(0.820, 0.612, 0.367),
	},
	Vector2i(2, -3): {
		"name": "THE VAULT", "mark": "arc",
		"floor": Color(0.095, 0.060, 0.200), "accent": Color(0.320, 0.221, 0.620),
	},
	Vector2i(1, -2): {
		"name": "LONG GALLERY", "mark": "alcoves",
		"floor": Color(0.070, 0.300, 0.060), "accent": Color(0.265, 0.720, 0.245),
	},
	Vector2i(0, -2): {
		"name": "COLD CORRIDOR", "mark": "steps",
		"floor": Color(0.400, 0.200, 0.267), "accent": Color(0.820, 0.443, 0.569),
	},
	Vector2i(-1, -2): {
		"name": "NORTHWEST TURN", "mark": "rubble",
		"floor": Color(0.080, 0.155, 0.200), "accent": Color(0.278, 0.492, 0.620),
	},
	Vector2i(-1, -1): {
		"name": "WEST RUN", "mark": "lanes",
		"floor": Color(0.283, 0.300, 0.090), "accent": Color(0.682, 0.720, 0.256),
	},
	Vector2i(-1, 0): {
		"name": "WEST HALL", "mark": "pillars",
		"floor": Color(0.333, 0.080, 0.400), "accent": Color(0.706, 0.279, 0.820),
	},
	Vector2i(-2, 0): {
		"name": "RELIQUARY", "mark": "pool",
		"floor": Color(0.100, 0.200, 0.150), "accent": Color(0.335, 0.620, 0.477),
	},
	Vector2i(0, 1): {
		"name": "SOUTH STEPS", "mark": "steps",
		"floor": Color(0.300, 0.157, 0.120), "accent": Color(0.720, 0.405, 0.323),
	},
	Vector2i(0, 2): {
		"name": "LOW JUNCTION", "mark": "cross",
		"floor": Color(0.120, 0.144, 0.400), "accent": Color(0.292, 0.337, 0.820),
	},
	Vector2i(-1, 2): {
		"name": "CISTERN", "mark": "checker",
		"floor": Color(0.100, 0.200, 0.040), "accent": Color(0.365, 0.620, 0.211),
	},
	Vector2i(1, 2): {
		"name": "KILN", "mark": "rubble",
		"floor": Color(0.300, 0.150, 0.250), "accent": Color(0.720, 0.389, 0.610),
	},
	Vector2i(2, 1): {
		"name": "FIRST SEAL", "mark": "arc",
		"floor": Color(0.160, 0.391, 0.400), "accent": Color(0.367, 0.802, 0.820),
	},
}

## 방 안쪽을 픽셀로 잰 사각형. 화면 원점에 고정된다 — 카메라가 따라다니지 않는
## 것이 "한 화면 = 한 방"의 실제 구현이다.
static func room_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(COLS * TILE), float(ROWS * TILE))

static func exists(coord: Vector2i) -> bool:
	return ROOMS.has(coord)

## 함정 출구 — 벽에 문이 그려져 있지만 뒤에 방이 없는 가짜 문. 지나가면 시작 방으로
## 돌아간다.
##
## 함정을 "진짜 방으로 가는 문"이 아니라 "아무 데도 가지 않는 문"으로 만든 이유가 있다.
## 진짜 문에 함정을 걸면 그 너머 방은 영영 발견할 수 없고, 모든 방 발견이라는 클리어
## 조건과 정면으로 부딪힌다. 가짜 문은 잃는 것이 위치와 시간뿐이라 벌은 주되 막지는
## 않는다. `tests/test_trap.gd`가 함정 방향에 진짜 이웃이 없음을 강제한다.
##
## 자리는 전부 "여기서 더 이어질 것 같은" 벽이다. 아무도 열어 보지 않을 문은 함정이
## 아니라 장식이다.
## 네 방 모두 진짜 출구가 2개다. 이건 우연이 아니라 조건이다 — 막다른 방에 함정을 두면
## 미탐색 문이 그것 하나뿐이라, "이 방에 가짜 문이 있다"는 방 단위 힌트와 합쳐지는 순간
## 함정이 완전히 지목된다. 진짜 출구가 2개면 처음 들어온 방에서 모르는 문이 항상 둘 이상
## 남고, 선택은 정보가 있는 추측으로 남는다. `tests/test_hint.gd`가 이 조건을 강제한다.
const TRAPS := {
	Vector2i(0, -2): [Vector2i.UP],      # 북쪽 복도에서 더 북쪽으로 갈 것 같은 문
	Vector2i(-1, -1): [Vector2i.LEFT],   # 서쪽으로 한 갈래 더 있을 것 같은 문
	Vector2i(0, 1): [Vector2i.RIGHT],    # 시작 바로 아래. 싸게 규칙을 가르치는 자리다
	Vector2i(1, -2): [Vector2i.UP],      # 긴 회랑 북쪽, 고리를 도는 중에 만난다
}

## 이 방 어딘가에 가짜 문이 있는가. 어느 문인지는 말하지 않는다.
static func has_trap(coord: Vector2i) -> bool:
	return TRAPS.has(coord) and not TRAPS[coord].is_empty()

## 단계적 입장. 인장이 있어야 첫 봉인이 열리고, 첫 봉인을 본 뒤에 둘째가 열리고,
## 둘 다 본 뒤에야 금고가 열린다.
##
## 이 사슬이 미니맵 없는 탐험에 방향을 준다. 열쇠가 어디 있었는지, 봉인이 어느 쪽이었는지를
## 기억으로 이어 붙이는 것이 곧 지도를 그리는 일이다. 세 방 모두 잠기지 않은 길로 문
## 앞까지는 갈 수 있다 — 잠긴 문 뒤에 열쇠를 두면 게임이 끝난다.
const SIGIL_ROOM := Vector2i(-2, 0)

const GATES := {
	Vector2i(2, 1): {"sigil": true, "rooms": []},
	Vector2i(3, 0): {"sigil": false, "rooms": [Vector2i(2, 1)]},
	Vector2i(2, -3): {"sigil": false, "rooms": [Vector2i(2, 1), Vector2i(3, 0)]},
}

static func is_gated(coord: Vector2i) -> bool:
	return GATES.has(coord)

## 진짜 이웃 방이 있는 방향.
static func real_exits(coord: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		if exists(coord + dir):
			found.append(dir)
	return found

static func trap_exits(coord: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if TRAPS.has(coord):
		for dir: Vector2i in TRAPS[coord]:
			found.append(dir)
	return found

static func is_trap(coord: Vector2i, dir: Vector2i) -> bool:
	return TRAPS.has(coord) and TRAPS[coord].has(dir)

## 문이 그려지고 지나갈 수 있는 모든 방향. 진짜와 가짜를 여기서 합치는 것이 핵심이다 --
## 겉보기로 갈라지면 함정이 아니게 된다.
static func exits(coord: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = real_exits(coord)
	for dir: Vector2i in trap_exits(coord):
		if not found.has(dir):
			found.append(dir)
	return found

static func count() -> int:
	return ROOMS.size()

## 문의 폭. 가로벽·세로벽 모두 가운데 3칸이 열린다.
const DOOR_SPAN := 3

## 문이 어디인지는 여기 한 곳에서만 정한다. 그리는 쪽과 부딪히는 쪽이 각자 계산하면
## 언젠가 어긋나고, 그 증상은 "보이는데 못 지나가는 문"이나 "벽인데 통과되는 자리"다.
static func is_doorway(col: int, row: int, open: Array[Vector2i]) -> bool:
	var half: int = DOOR_SPAN / 2
	var in_col_band: bool = absi(col - COLS / 2) <= half
	var in_row_band: bool = absi(row - ROWS / 2) <= half
	if row == 0 and in_col_band:
		return open.has(Vector2i.UP)
	if row == ROWS - 1 and in_col_band:
		return open.has(Vector2i.DOWN)
	if col == 0 and in_row_band:
		return open.has(Vector2i.LEFT)
	if col == COLS - 1 and in_row_band:
		return open.has(Vector2i.RIGHT)
	return false

## 좌·우 문이 차지하는 세로 구간을 픽셀로. x=위쪽 경계, y=아래쪽 경계.
static func door_band_v() -> Vector2:
	var half: int = DOOR_SPAN / 2
	var first: int = ROWS / 2 - half
	return Vector2(float(first * TILE), float((first + DOOR_SPAN) * TILE))

## 위·아래 문이 차지하는 가로 구간을 픽셀로.
static func door_band_h() -> Vector2:
	var half: int = DOOR_SPAN / 2
	var first: int = COLS / 2 - half
	return Vector2(float(first * TILE), float((first + DOOR_SPAN) * TILE))
