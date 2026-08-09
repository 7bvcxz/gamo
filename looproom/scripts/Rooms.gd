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

const ROOMS := {
	Vector2i(0, 0): {
		"name": "ATRIUM",
		"floor": Color(0.184, 0.196, 0.259),
		"accent": Color(0.412, 0.443, 0.573),
	},
	Vector2i(1, 0): {
		"name": "EAST HALL",
		"floor": Color(0.204, 0.180, 0.161),
		"accent": Color(0.510, 0.435, 0.353),
	},
	Vector2i(0, -1): {
		"name": "NORTH STAIR",
		"floor": Color(0.153, 0.204, 0.196),
		"accent": Color(0.353, 0.510, 0.475),
	},
}

## 방 안쪽을 픽셀로 잰 사각형. 화면 원점에 고정된다 — 카메라가 따라다니지 않는
## 것이 "한 화면 = 한 방"의 실제 구현이다.
static func room_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(COLS * TILE), float(ROWS * TILE))

static func exists(coord: Vector2i) -> bool:
	return ROOMS.has(coord)

## 그 방에서 실제로 나갈 수 있는 방향. 이웃 방이 맵에 있으면 문이 있고, 없으면 벽이다.
## 문을 따로 적지 않는 것은 맵과 문이 어긋날 수 없게 하려는 것이다.
static func exits(coord: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		if exists(coord + dir):
			found.append(dir)
	return found

static func count() -> int:
	return ROOMS.size()
