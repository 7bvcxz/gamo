extends Node2D

const UNIT := 20.0
const CHAR_WIDTH := 2.0 * UNIT
const CHAR_HEIGHT := 3.0 * UNIT
const ROOM_SIZE := 16.0 * UNIT

const SPECIAL_CHANCE := 0.1
const DEFAULT_COLOR := Color(0.16, 0.18, 0.24)
const SPECIAL_COLORS := [
	Color(0.55, 0.18, 0.2),
	Color(0.2, 0.45, 0.28),
	Color(0.5, 0.32, 0.65),
	Color(0.75, 0.5, 0.15),
	Color(0.15, 0.4, 0.55),
]

var room_color: Color = DEFAULT_COLOR
var room_count: int = 1
var half_char := Vector2(CHAR_WIDTH, CHAR_HEIGHT) / 2.0

@onready var player: Node2D = $Player
@onready var room_label: Label = $UI/RoomLabel

func _ready() -> void:
	player.position = Vector2(ROOM_SIZE / 2.0, ROOM_SIZE / 2.0)
	_update_label()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(ROOM_SIZE, ROOM_SIZE)), room_color)

func _process(_delta: float) -> void:
	_check_room_edge()

func _check_room_edge() -> void:
	var pos := player.position
	var min_x := half_char.x
	var max_x := ROOM_SIZE - half_char.x
	var min_y := half_char.y
	var max_y := ROOM_SIZE - half_char.y

	if pos.x <= min_x:
		_transition(Vector2(max_x - 1.0, pos.y))
	elif pos.x >= max_x:
		_transition(Vector2(min_x + 1.0, pos.y))
	elif pos.y <= min_y:
		_transition(Vector2(pos.x, max_y - 1.0))
	elif pos.y >= max_y:
		_transition(Vector2(pos.x, min_y + 1.0))
	else:
		player.position.x = clamp(pos.x, min_x, max_x)
		player.position.y = clamp(pos.y, min_y, max_y)

func _transition(new_pos: Vector2) -> void:
	room_count += 1
	if randf() < SPECIAL_CHANCE:
		room_color = SPECIAL_COLORS[randi() % SPECIAL_COLORS.size()]
	else:
		room_color = DEFAULT_COLOR
	player.position = new_pos
	queue_redraw()
	_update_label()

func _update_label() -> void:
	room_label.text = "Room %d" % room_count
