extends Node2D

## 한 화면에 한 방.
##
## 카메라가 없다는 것이 이 게임의 핵심 규칙이다. 주인공을 따라다니는 카메라를 두면
## 벽 너머 다음 방이 미리 보이고, 그 순간 "새 공간을 발견한다"는 것이 사라진다.
## 그리는 원점은 항상 (0, 0)이고 주인공이 어디에 있든 바뀌지 않는다.

const Rooms := preload("res://scripts/Rooms.gd")

const WALL := Color(0.075, 0.071, 0.098)
const GRID := Color(1.0, 1.0, 1.0, 0.035)
const DOOR := Color(0.945, 0.878, 0.639)
const PLAYER_BODY := Color(0.898, 0.906, 0.941)
const PLAYER_DARK := Color(0.235, 0.243, 0.318)
const PLAYER_RADIUS := 16.0

## 문이 뚫리는 폭. 가로벽은 가운데 3칸, 세로벽은 가운데 3칸.
const DOOR_SPAN := 3

var current_room: Vector2i = Rooms.START
## 방 안에서의 위치를 픽셀로 잰다. 방이 바뀌면 이 값도 새 방 기준으로 다시 쓰인다.
var player_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	player_pos = Rooms.room_rect().get_center()
	queue_redraw()

## 지금 화면에 그려지는 방들. 언제나 정확히 하나여야 한다.
func visible_rooms() -> Array[Vector2i]:
	return [current_room]

## 방을 그리기 시작하는 화면 좌표. 상수라는 것이 곧 "카메라가 없다"는 뜻이다.
func room_origin() -> Vector2:
	return Vector2.ZERO

func _draw() -> void:
	for coord: Vector2i in visible_rooms():
		_draw_room(coord)
	_draw_player()

func _draw_room(coord: Vector2i) -> void:
	var data: Dictionary = Rooms.ROOMS[coord]
	var origin: Vector2 = room_origin()
	var rect: Rect2 = Rooms.room_rect()
	var floor_color: Color = data["floor"]
	var accent: Color = data["accent"]

	draw_rect(Rect2(origin + rect.position, rect.size), floor_color)

	# 격자. 방이 "고정 크기 그리드"라는 것을 눈으로 보이게 하는 최소한이다.
	var t: float = float(Rooms.TILE)
	for col: int in range(1, Rooms.COLS):
		var x: float = origin.x + float(col) * t
		draw_line(Vector2(x, origin.y), Vector2(x, origin.y + rect.size.y), GRID, 1.0)
	for row: int in range(1, Rooms.ROWS):
		var y: float = origin.y + float(row) * t
		draw_line(Vector2(origin.x, y), Vector2(origin.x + rect.size.x, y), GRID, 1.0)

	var open: Array[Vector2i] = Rooms.exits(coord)
	for col: int in range(Rooms.COLS):
		for row: int in range(Rooms.ROWS):
			if not _is_border(col, row):
				continue
			var cell: Rect2 = Rect2(
				origin + Vector2(float(col) * t, float(row) * t), Vector2(t, t))
			if _is_doorway(col, row, open):
				draw_rect(cell, floor_color)
				# 문턱만 밝게. 어느 벽이 열려 있는지가 이 게임의 유일한 길잡이다.
				draw_rect(_threshold(col, row, cell), DOOR)
			else:
				draw_rect(cell, WALL)
				draw_rect(Rect2(cell.position, Vector2(t, 3.0)), accent)

	_draw_room_name(String(data["name"]), origin, rect, accent)

func _draw_room_name(name: String, origin: Vector2, rect: Rect2, accent: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var at: Vector2 = origin + Vector2(rect.size.x * 0.5, float(Rooms.TILE) * 0.5 + 8.0)
	draw_string(font, at - Vector2(font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, 20).x * 0.5, 0.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20,
		Color(accent, 0.85))

func _draw_player() -> void:
	var at: Vector2 = room_origin() + player_pos
	draw_circle(at + Vector2(0.0, 4.0), PLAYER_RADIUS, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(at, PLAYER_RADIUS, PLAYER_BODY)
	draw_circle(at + Vector2(-5.0, -4.0), 2.5, PLAYER_DARK)
	draw_circle(at + Vector2(5.0, -4.0), 2.5, PLAYER_DARK)

func _is_border(col: int, row: int) -> bool:
	return col == 0 or row == 0 or col == Rooms.COLS - 1 or row == Rooms.ROWS - 1

## 문은 이웃 방이 실제로 있는 벽에만 뚫린다. 모서리는 언제나 벽이다.
func _is_doorway(col: int, row: int, open: Array[Vector2i]) -> bool:
	var mid_col: int = Rooms.COLS / 2
	var mid_row: int = Rooms.ROWS / 2
	var half: int = DOOR_SPAN / 2
	var in_col_band: bool = absi(col - mid_col) <= half
	var in_row_band: bool = absi(row - mid_row) <= half
	if row == 0 and in_col_band:
		return open.has(Vector2i.UP)
	if row == Rooms.ROWS - 1 and in_col_band:
		return open.has(Vector2i.DOWN)
	if col == 0 and in_row_band:
		return open.has(Vector2i.LEFT)
	if col == Rooms.COLS - 1 and in_row_band:
		return open.has(Vector2i.RIGHT)
	return false

## 문턱은 벽이 있던 자리의 바깥쪽 가장자리에 얇게 긋는다.
func _threshold(col: int, row: int, cell: Rect2) -> Rect2:
	var t: float = float(Rooms.TILE)
	if row == 0:
		return Rect2(cell.position, Vector2(t, 4.0))
	if row == Rooms.ROWS - 1:
		return Rect2(cell.position + Vector2(0.0, t - 4.0), Vector2(t, 4.0))
	if col == 0:
		return Rect2(cell.position, Vector2(4.0, t))
	return Rect2(cell.position + Vector2(t - 4.0, 0.0), Vector2(4.0, t))
