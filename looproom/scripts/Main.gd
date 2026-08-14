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
const SEAL := Color(0.780, 0.310, 0.290)
const SIGIL := Color(0.988, 0.831, 0.361)
const PLAYER_BODY := Color(0.898, 0.906, 0.941)
const PLAYER_DARK := Color(0.235, 0.243, 0.318)
const STICK_RING := Color(1.0, 1.0, 1.0, 0.16)
const STICK_KNOB := Color(1.0, 1.0, 1.0, 0.34)

const PLAYER_RADIUS := 16.0
const SPEED := 260.0

## 주인공은 Motorio: One Shot의 Grim이다. 이 게임에서 유일하게 도형이 아닌 것이고,
## GOAL.md가 정확히 그것 하나만 허용한다.
##
## 시트는 이미 정규화되어 있다: 128px 셀 8프레임 한 줄, 모든 프레임에서 발이 같은 자리.
## 그래서 프레임마다 보정할 것이 없고, 서쪽은 시트 없이 동쪽을 뒤집어 쓴다 -- 기준점 x가
## 셀 정중앙이라 반전이 정확하다.
##
## 파일은 `looproom/assets/` 안으로 복사했다. `../motorio`을 상대 경로로 가리키면
## `res://` 밖이라 Web export에 들어가지 않고, 처음 clone한 상태에서 실행되지도 않는다.
const CELL := 128.0
const SHEET_FRAMES := 8
const FOOT_ANCHOR := Vector2(64.0, 104.0)
## 원본은 셀 128을 0.5배로 그려 몸통이 32 논리px, 즉 그 게임의 한 타일이 되게 했다.
## 여기 타일은 60이므로 같은 관계를 유지하려면 0.5 x 60/32 = 0.94다. 0.9로 둔다.
##
## 처음에 0.58로 두고 헤드리스와 픽셀 수 검사를 통과시켰는데, 실제 폰 화면을 보니
## 주인공이 방 안의 점처럼 보였다. 색이 몇 가지인지 세는 것으로는 알 수 없는 종류의
## 문제이고, 스크린샷을 보지 않았으면 그대로 넘어갔을 것이다.
const SPRITE_SCALE := 0.9
## 발이 주인공 좌표보다 얼마나 아래에 서는지.
const FOOT_DROP := 9.0
## 8프레임을 초당 10장. 원본과 같은 보폭이다.
const ANIM_FPS := 10.0

const IDLE_S: Texture2D = preload("res://assets/characters/grim_idle_s.png")
const WALK_S: Texture2D = preload("res://assets/characters/grim_walk_s.png")
const WALK_E: Texture2D = preload("res://assets/characters/grim_walk_e.png")
const WALK_N: Texture2D = preload("res://assets/characters/grim_walk_n.png")

## 새 방에 들어설 때 문 안쪽 몇 px 지점에 놓을지. 0이면 들어서자마자 반대쪽 전환이
## 다시 걸려 두 방 사이를 오간다.
const ENTER_INSET := 18.0

## 손가락이 이만큼 움직이기 전에는 방향으로 치지 않는다. 누르기만 한 것과 미는 것을
## 가르는 값이다.
const STICK_DEADZONE := 12.0
const STICK_MAX := 68.0

var current_room: Vector2i = Rooms.START
## 방 안에서의 위치를 픽셀로 잰다. 방이 바뀌면 이 값도 새 방 기준으로 다시 쓰인다.
var player_pos: Vector2 = Vector2.ZERO
## 마지막으로 향한 방향. 어느 시트를 그릴지가 여기서 정해진다.
var facing: Vector2 = Vector2.DOWN
## 애니메이션 시계. 멈춰 있어도 흐른다 -- 남쪽 대기도 8장짜리 호흡이라 시계가 필요하다.
var anim_time: float = 0.0
var moving: bool = false

var touch_index: int = -1
var touch_origin: Vector2 = Vector2.ZERO
var touch_at: Vector2 = Vector2.ZERO

## 회귀 연출. 0.5초를 넘겨야 한다는 것이 완료 조건이지만, 길이보다 중요한 것은
## 무슨 일이 일어났는지 읽히는 것이다: 함정 방이 그 방 색으로 번쩍이고, 사방에서
## 셔터가 닫히고, 다시 열리면 시작 방이다.
const RECALL_TIME := 0.95
## 셔터가 완전히 닫히는 지점(진행도 0~1 기준). 방이 바뀌는 순간이기도 하다.
const RECALL_CLOSE := 0.38
var recall_timer: float = 0.0
var recall_pending: bool = false
var recall_from: Vector2i = Rooms.START

## 발견한 방. 미니맵은 금지지만 숫자는 진행도이지 지도가 아니다 -- 몇 개를 찾았는지는
## 알려주되 그것들이 어디에 어떻게 붙어 있는지는 끝까지 말해 주지 않는다.
var discovered: Dictionary = {}
## 새 방에 처음 들어섰을 때 뜨는 표시의 남은 시간.
const DISCOVER_TIME := 1.5
var discover_timer: float = 0.0

## 인장. 주우면 첫 봉인이 열린다. 되돌릴 수 없는 상태만 열쇠로 쓰는 것이 원칙이다.
var has_sigil: bool = false
const SIGIL_RADIUS := 22.0
var sigil_timer: float = 0.0
const SIGIL_TIME := 2.0

## 봉인된 문에 부딪혔을 때 뜨는 안내의 남은 시간.
const SEALED_TIME := 1.4
var sealed_timer: float = 0.0

## 소요 시간. 프레임 수가 아니라 실제 경과 시간을 쌓는다 -- 60fps를 가정하고 프레임을
## 세면 느린 기기에서 같은 플레이가 더 빠른 기록으로 나온다.
##
## 함정에 걸린 시간도 여기 포함된다. 그게 함정의 값이다: 진행은 안 빼앗고 시간만 가져간다.
var elapsed: float = 0.0
var cleared: bool = false
var clear_time: float = 0.0

func _ready() -> void:
	player_pos = Rooms.room_rect().get_center()
	# 시작 방도 발견한 방이다. 세지 않으면 카운터가 영영 1개 모자란 채로 끝난다.
	arrive(Rooms.START)
	discover_timer = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not cleared:
		elapsed += delta
	discover_timer = maxf(0.0, discover_timer - delta)
	sealed_timer = maxf(0.0, sealed_timer - delta)
	sigil_timer = maxf(0.0, sigil_timer - delta)
	advance_recall(delta)
	anim_time += delta
	moving = false
	if not is_locked():
		var dir: Vector2 = input_direction()
		if dir != Vector2.ZERO:
			facing = dir
			moving = true
			step(dir * SPEED * delta)
	try_take_sigil()
	queue_redraw()

## 인장은 방에 들어서는 것이 아니라 그 앞까지 걸어가야 주워진다. 방에 들어서기만 하면
## 얻는 물건은 물건이 아니라 문턱이고, 주우러 갔다는 기억이 남지 않는다.
func try_take_sigil() -> bool:
	if has_sigil or current_room != Rooms.SIGIL_ROOM:
		return false
	if player_pos.distance_to(Rooms.room_rect().get_center()) > SIGIL_RADIUS + PLAYER_RADIUS:
		return false
	has_sigil = true
	sigil_timer = SIGIL_TIME
	return true

## 연출이 도는 동안에는 걸을 수 없다. 화면이 닫혀 있는데 조작이 살아 있으면 보이지
## 않는 곳으로 걸어가 있게 되고, 연출이 끝난 자리가 어디인지 알 수 없다.
func is_locked() -> bool:
	return recall_timer > 0.0 or cleared

## 회귀 연출을 진행시킨다. 방을 옮기는 순간은 화면이 완전히 닫힌 시점이다 --
## 먼저 옮기고 나서 닫으면 함정 방이 아니라 시작 방이 어두워지는 것이 보이고,
## 그러면 "돌려보내졌다"가 아니라 "화면이 깜빡였다"가 된다.
func advance_recall(delta: float) -> void:
	if recall_timer <= 0.0:
		return
	recall_timer = maxf(0.0, recall_timer - delta)
	if recall_pending and recall_progress() >= RECALL_CLOSE:
		recall_pending = false
		current_room = Rooms.START
		player_pos = Rooms.room_rect().get_center()
		arrive(current_room)

## 0에서 1로 흐르는 연출 진행도.
func recall_progress() -> float:
	if recall_timer <= 0.0:
		return 1.0
	return 1.0 - recall_timer / RECALL_TIME

# --- 입력 -------------------------------------------------------------------

## 터치 조이스틱과 키보드를 하나의 방향으로 합친다. 대각선이 빠르지 않도록 길이는
## 언제나 1 이하로 맞춘다.
func input_direction() -> Vector2:
	if touch_index != -1:
		var delta: Vector2 = touch_at - touch_origin
		if delta.length() < STICK_DEADZONE:
			return Vector2.ZERO
		return delta.normalized()
	var keys: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	if keys.length() > 1.0:
		return keys.normalized()
	return keys

## 조이스틱은 손가락이 닿은 자리에 생긴다. 화면 한쪽을 미리 차지하면 작은 폰에서
## 그 영역을 피해 누르게 되고, 세로 폰에서 그럴 여유는 없다.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if touch_index == -1:
				touch_index = touch.index
				touch_origin = touch.position
				touch_at = touch.position
		elif touch.index == touch_index:
			# 뗀 처리는 누른 처리 안에 중첩하지 않는다. 중첩하면 릴리스가 여기까지
			# 오지 못해 손을 떼도 계속 걸어가고, 이 저장소가 겪은 실제 결함이다.
			touch_index = -1
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == touch_index:
			touch_at = drag.position

# --- 이동과 방 전환 ---------------------------------------------------------

func step(offset: Vector2) -> void:
	player_pos += offset
	if _try_transition():
		return
	_clamp_to_room()

## 방 가장자리를 넘었고 그 벽에 문이 있으면 이웃 방으로 넘어간다. 다른 축은 그대로
## 두어 문을 지난 자리에서 이어 걷는 느낌이 유지된다.
func _try_transition() -> bool:
	var rect: Rect2 = Rooms.room_rect()
	var open: Array[Vector2i] = Rooms.exits(current_room)
	if player_pos.x >= rect.size.x and open.has(Vector2i.RIGHT) and passable(Vector2i.RIGHT) and _in_v_door():
		return _enter(Vector2i.RIGHT)
	if player_pos.x <= 0.0 and open.has(Vector2i.LEFT) and passable(Vector2i.LEFT) and _in_v_door():
		return _enter(Vector2i.LEFT)
	if player_pos.y >= rect.size.y and open.has(Vector2i.DOWN) and passable(Vector2i.DOWN) and _in_h_door():
		return _enter(Vector2i.DOWN)
	if player_pos.y <= 0.0 and open.has(Vector2i.UP) and passable(Vector2i.UP) and _in_h_door():
		return _enter(Vector2i.UP)
	return false

## 이 문을 지금 지나갈 수 있는가. 봉인은 **통행상 벽으로 다룬다**.
##
## 처음에는 문턱을 넘게 두고 되밀었는데, 봉인을 향해 계속 걸으면 넘고-밀리고를 반복해
## 주인공이 78px씩 떨었다. 막힌 것은 막힌 것처럼 서 있어야 한다. 대신 벽이 아니라
## 빗장으로 그려서, 지금은 못 가지만 언젠가 간다는 것은 그대로 보인다.
func passable(dir: Vector2i) -> bool:
	if Rooms.is_trap(current_room, dir):
		return true
	return Rooms.exists(current_room + dir) and can_enter(current_room + dir)

## 함정 문을 지나면 시작 방 한가운데로 돌아온다. 잃는 것은 위치와 시간이지 진행이
## 아니다 -- 발견한 방을 도로 빼앗으면 벌이 아니라 취소가 되고, 그러면 다시 걸어올
## 이유가 아니라 그만둘 이유가 된다.
##
## 여기서는 연출을 시작만 한다. 실제로 방이 바뀌는 것은 화면이 다 닫힌 뒤다.
func recall() -> void:
	if recall_timer > 0.0:
		return
	recall_from = current_room
	recall_timer = RECALL_TIME
	recall_pending = true

## 방에 도착했다는 사실은 한 곳에서만 기록한다. 문으로 들어올 때와 회귀로 돌아올 때
## 각각 세면 언젠가 한쪽을 빠뜨리고, 그 증상은 "분명히 갔는데 숫자가 안 오른다"다.
func arrive(coord: Vector2i) -> void:
	if discovered.has(coord):
		return
	discovered[coord] = true
	discover_timer = DISCOVER_TIME
	# 마지막 한 방이 채워지는 순간이 클리어다. 시계는 여기서 멈춘다.
	if not cleared and discovered_count() >= Rooms.count():
		cleared = true
		clear_time = elapsed

func discovered_count() -> int:
	return discovered.size()

## 분:초.십분의일. 초만 쓰면 3분짜리 플레이가 "184.3"으로 나와 읽히지 않는다.
static func format_time(seconds: float) -> String:
	var whole: int = int(seconds)
	return "%d:%02d.%01d" % [whole / 60, whole % 60, int((seconds - float(whole)) * 10.0)]

## 봉인된 방에 들어갈 수 있는가. 조건은 전부 이미 한 일들이다 — 인장을 주웠는가,
## 그 방을 봤는가. 되돌릴 수 없는 것만 조건으로 쓰면 잠긴 문 앞에서 영영 막히는 상태가
## 만들어지지 않는다.
func can_enter(coord: Vector2i) -> bool:
	if not Rooms.is_gated(coord):
		return true
	var gate: Dictionary = Rooms.GATES[coord]
	if bool(gate["sigil"]) and not has_sigil:
		return false
	for needed: Vector2i in gate["rooms"]:
		if not discovered.has(needed):
			return false
	return true

## 방을 옮겼으면 true. 봉인에 막혔으면 false를 돌려 호출한 쪽이 위치를 되돌리게 한다.
func _enter(dir: Vector2i) -> bool:
	if Rooms.is_trap(current_room, dir):
		recall()
		return true
	# 봉인은 `passable()`이 이미 걸러 여기까지 오지 않는다.
	var target: Vector2i = current_room + dir
	current_room = target
	_place_after_entry(dir)
	arrive(current_room)
	return true

## 새 방에 들어선 자리. 지나온 문의 반대편 문간에 놓이고 다른 축은 그대로 유지된다.
func _place_after_entry(dir: Vector2i) -> void:
	var rect: Rect2 = Rooms.room_rect()
	if dir == Vector2i.RIGHT:
		player_pos = Vector2(ENTER_INSET, player_pos.y)
	elif dir == Vector2i.LEFT:
		player_pos = Vector2(rect.size.x - ENTER_INSET, player_pos.y)
	elif dir == Vector2i.DOWN:
		player_pos = Vector2(player_pos.x, ENTER_INSET)
	else:
		player_pos = Vector2(player_pos.x, rect.size.y - ENTER_INSET)

func _in_v_door() -> bool:
	var band: Vector2 = Rooms.door_band_v()
	return player_pos.y - PLAYER_RADIUS >= band.x and player_pos.y + PLAYER_RADIUS <= band.y

func _in_h_door() -> bool:
	var band: Vector2 = Rooms.door_band_h()
	return player_pos.x - PLAYER_RADIUS >= band.x and player_pos.x + PLAYER_RADIUS <= band.y

## 벽은 한 칸 두께의 테두리다. 문이 있는 벽은 문 폭 안에서만 열리고, 문 통로에
## 들어선 동안에는 반대 축을 통로 폭으로 묶어 벽 안으로 새지 않게 한다.
func _clamp_to_room() -> void:
	var rect: Rect2 = Rooms.room_rect()
	var open: Array[Vector2i] = Rooms.exits(current_room)
	var t: float = float(Rooms.TILE)
	var r: float = PLAYER_RADIUS
	var band_v: Vector2 = Rooms.door_band_v()
	var band_h: Vector2 = Rooms.door_band_h()

	var min_x: float = t + r
	var max_x: float = rect.size.x - t - r
	if _in_v_door():
		if open.has(Vector2i.LEFT):
			if passable(Vector2i.LEFT):
				min_x = 0.0
			elif player_pos.x < min_x:
				sealed_timer = SEALED_TIME
		if open.has(Vector2i.RIGHT):
			if passable(Vector2i.RIGHT):
				max_x = rect.size.x
			elif player_pos.x > max_x:
				sealed_timer = SEALED_TIME

	var min_y: float = t + r
	var max_y: float = rect.size.y - t - r
	if _in_h_door():
		if open.has(Vector2i.UP):
			if passable(Vector2i.UP):
				min_y = 0.0
			elif player_pos.y < min_y:
				sealed_timer = SEALED_TIME
		if open.has(Vector2i.DOWN):
			if passable(Vector2i.DOWN):
				max_y = rect.size.y
			elif player_pos.y > max_y:
				sealed_timer = SEALED_TIME

	player_pos.x = clampf(player_pos.x, min_x, max_x)
	player_pos.y = clampf(player_pos.y, min_y, max_y)

	if player_pos.x < t + r or player_pos.x > rect.size.x - t - r:
		player_pos.y = clampf(player_pos.y, band_v.x + r, band_v.y - r)
	if player_pos.y < t + r or player_pos.y > rect.size.y - t - r:
		player_pos.x = clampf(player_pos.x, band_h.x + r, band_h.y - r)

# --- 그리기 -----------------------------------------------------------------

## 지금 화면에 그려지는 방들. 언제나 정확히 하나여야 한다.
func visible_rooms() -> Array[Vector2i]:
	return [current_room]

## 방을 그리기 시작하는 화면 좌표. 상수라는 것이 곧 "카메라가 없다"는 뜻이다.
func room_origin() -> Vector2:
	return Vector2.ZERO

func _draw() -> void:
	for coord: Vector2i in visible_rooms():
		_draw_room(coord)
	_draw_sigil()
	_draw_player()
	_draw_stick()
	_draw_counter()
	_draw_notice()
	_draw_discovery()
	_draw_recall()
	_draw_clear()

## 클리어 화면. 18개를 다 찾았다는 것과 얼마나 걸렸는지, 그 둘만 말한다.
func _draw_clear() -> void:
	if not cleared:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var rect: Rect2 = Rooms.room_rect()
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.031, 0.027, 0.043, 0.90))

	_draw_centered(font, "ALL ROOMS FOUND", 46, rect.size.y * 0.5 - 42.0,
		Color(0.945, 0.878, 0.639))
	_draw_centered(font, format_time(clear_time), 62, rect.size.y * 0.5 + 40.0,
		Color(0.988, 0.831, 0.361))
	_draw_centered(font, "%d ROOMS" % Rooms.count(), 22, rect.size.y * 0.5 + 92.0,
		Color(0.945, 0.878, 0.639, 0.55))

func _draw_centered(font: Font, text: String, size: int, y: float, tint: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2((Rooms.room_rect().size.x - width) * 0.5, y),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, tint)

## 구석의 발견 수 / 전체 수. 이것은 지도가 아니다 -- 몇 개가 남았는지는 알려주되
## 그 방들이 어디에 붙어 있는지는 끝까지 말하지 않는다. 남은 개수를 아는 것과
## 어디 있는지 아는 것 사이의 거리가 이 게임이다.
func _draw_counter() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var rect: Rect2 = Rooms.room_rect()
	var text := "%d / %d" % [discovered_count(), Rooms.count()]
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22)
	var at := Vector2(rect.size.x - size.x - 22.0, 38.0)
	draw_rect(Rect2(at + Vector2(-12.0, -24.0), size + Vector2(24.0, 32.0)),
		Color(0.031, 0.027, 0.043, 0.55))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22,
		Color(0.945, 0.878, 0.639, 0.92))

## 처음 들어온 방에서만 뜨는 표시. 두 번째부터 뜨지 않는 것이 핵심이다 -- 늘 뜨면
## 그것은 발견이 아니라 방 이름표다.
func _draw_discovery() -> void:
	if discover_timer <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var rect: Rect2 = Rooms.room_rect()
	# 끝의 0.4초 동안만 사라진다. 그 전에는 또렷하게 남아 읽을 시간을 준다.
	var fade: float = clampf(discover_timer / 0.4, 0.0, 1.0)
	var label := "DISCOVERED"
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30).x
	var band := Rect2(0.0, rect.size.y * 0.5 - 96.0, rect.size.x, 56.0)
	draw_rect(band, Color(0.031, 0.027, 0.043, 0.62 * fade))
	draw_string(font, Vector2((rect.size.x - width) * 0.5, band.position.y + 39.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30,
		Color(0.945, 0.878, 0.639, fade))

## 회귀 연출. 함정 방의 색으로 한 번 번쩍이고, 사방에서 셔터가 닫혔다가, 시작 방에서
## 열린다. 닫히는 동안 조작이 잠겨 있으므로 플레이어가 할 일은 보는 것뿐이고, 그래서
## 이 0.95초는 "무슨 일이 일어났는지" 말할 시간이 된다.
func _draw_recall() -> void:
	if recall_timer <= 0.0:
		return
	var rect: Rect2 = Rooms.room_rect()
	var t: float = recall_progress()

	# 셔터. 닫힐 때는 빠르게, 열릴 때는 느리게 -- 빼앗기는 것은 순식간이고 되돌아오는
	# 데는 시간이 걸린다는 것이 이 게임이 말하려는 것이다.
	var shut: float = 0.0
	if t < RECALL_CLOSE:
		shut = ease(t / RECALL_CLOSE, 2.4)
	else:
		shut = 1.0 - ease((t - RECALL_CLOSE) / (1.0 - RECALL_CLOSE), 0.45)
	shut = clampf(shut, 0.0, 1.0)

	var curtain := Color(0.031, 0.027, 0.043)
	var half_y: float = rect.size.y * 0.5 * shut
	var half_x: float = rect.size.x * 0.5 * shut
	draw_rect(Rect2(0.0, 0.0, rect.size.x, half_y), curtain)
	draw_rect(Rect2(0.0, rect.size.y - half_y, rect.size.x, half_y), curtain)
	draw_rect(Rect2(0.0, 0.0, half_x, rect.size.y), curtain)
	draw_rect(Rect2(rect.size.x - half_x, 0.0, half_x, rect.size.y), curtain)

	# 함정을 밟은 그 방의 색으로 번쩍인다. 어느 문이 함정이었는지 기억에 붙여 두는
	# 것이 다음 판을 다르게 만든다.
	if t < 0.18:
		var flash: Color = Rooms.ROOMS[recall_from]["accent"]
		draw_rect(Rect2(Vector2.ZERO, rect.size), Color(flash, 0.55 * (1.0 - t / 0.18)))

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	# 문구는 셔터가 닫힌 구간에만. 열리는 화면 위에 겹치면 방을 가린다.
	var show: float = 1.0 - absf(t - RECALL_CLOSE) / RECALL_CLOSE
	if show <= 0.0:
		return
	var label := "SENT BACK"
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34).x
	draw_string(font, Vector2((rect.size.x - width) * 0.5, rect.size.y * 0.5 + 12.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34,
		Color(0.945, 0.878, 0.639, clampf(show, 0.0, 1.0)))

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

	_draw_mark(String(data["mark"]), origin, accent)
	_draw_draught(coord)

	var open: Array[Vector2i] = Rooms.exits(coord)
	for col: int in range(Rooms.COLS):
		for row: int in range(Rooms.ROWS):
			if not _is_border(col, row):
				continue
			var cell: Rect2 = Rect2(
				origin + Vector2(float(col) * t, float(row) * t), Vector2(t, t))
			if Rooms.is_doorway(col, row, open):
				draw_rect(cell, floor_color)
				# 문턱 색이 힌트다. 가 본 방으로 이어지는 문에만 그 방의 색이 비치고,
				# 나머지는 전부 같은 중립색이다 -- 아직 못 가 본 진짜 방과 가짜 문이
				# 여기서 정확히 같아 보이는 것이 설계의 핵심이다.
				var dir: Vector2i = _door_dir(col, row)
				var look: int = door_look(coord, dir)
				var tint: Color = DOOR
				if look == DoorLook.KNOWN:
					tint = Rooms.ROOMS[coord + dir]["accent"]
				elif look == DoorLook.SEALED:
					tint = SEAL
				draw_rect(_threshold(col, row, cell), tint)
				if look == DoorLook.SEALED:
					_draw_seal(col, row, cell)
			else:
				draw_rect(cell, WALL)
				draw_rect(Rect2(cell.position, Vector2(t, 3.0)), accent)

	_draw_room_name(String(data["name"]), origin, rect, accent)

## 바닥 무늬. 색만으로 18개 방을 구분하기는 어렵고, 무늬는 색맹인 경우에도 남는
## 단서다. 전부 고정 좌표다 — 무작위였다면 같은 방이 매번 달라 보이고, 머릿속에
## 지도를 그린다는 이 게임의 전제가 무너진다.
##
## 충돌은 없다. 무늬는 길을 막지 않는다 — 막는 순간 방마다 별도의 통행 규칙이 생겨
## "문을 지나면 옆 방"이라는 단순한 규칙이 흐려진다.
func _draw_mark(mark: String, origin: Vector2, accent: Color) -> void:
	var t: float = float(Rooms.TILE)
	var inner: Rect2 = Rect2(origin + Vector2(t, t),
		Vector2(float(Rooms.COLS - 2) * t, float(Rooms.ROWS - 2) * t))
	var mid: Vector2 = inner.get_center()
	var ink: Color = Color(accent, 0.13)
	var deep: Color = Color(accent, 0.20)

	match mark:
		"ring":
			draw_arc(mid, 118.0, 0.0, TAU, 64, deep, 5.0)
			draw_arc(mid, 74.0, 0.0, TAU, 48, ink, 3.0)
		"lanes":
			for i: int in range(3):
				var y: float = inner.position.y + inner.size.y * (0.25 + 0.25 * float(i))
				draw_rect(Rect2(inner.position.x + 40.0, y - 7.0,
					inner.size.x - 80.0, 14.0), ink)
		"cross":
			draw_rect(Rect2(mid.x - 26.0, inner.position.y + 30.0,
				52.0, inner.size.y - 60.0), ink)
			draw_rect(Rect2(inner.position.x + 30.0, mid.y - 26.0,
				inner.size.x - 60.0, 52.0), ink)
		"pillars":
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var at: Vector2 = mid + Vector2(sx * 210.0, sy * 108.0)
					draw_rect(Rect2(at - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), deep)
					draw_rect(Rect2(at - Vector2(16.0, 16.0), Vector2(32.0, 32.0)), ink)
		"pool":
			draw_rect(Rect2(mid - Vector2(190.0, 96.0), Vector2(380.0, 192.0)), deep)
			draw_rect(Rect2(mid - Vector2(168.0, 78.0), Vector2(336.0, 156.0)), ink)
		"steps":
			for i: int in range(5):
				var w: float = 90.0 + 52.0 * float(i)
				draw_rect(Rect2(mid.x - w * 0.5, inner.position.y + 34.0 + 46.0 * float(i),
					w, 22.0), ink)
		"alcoves":
			for i: int in range(4):
				var y: float = inner.position.y + 34.0 + 82.0 * float(i)
				draw_rect(Rect2(inner.position.x, y, 46.0, 52.0), deep)
				draw_rect(Rect2(inner.end.x - 46.0, y, 46.0, 52.0), deep)
		"rubble":
			for spot: Vector2 in RUBBLE:
				draw_rect(Rect2(inner.position + spot * inner.size - Vector2(15.0, 12.0),
					Vector2(30.0, 24.0)), ink)
		"shards":
			for spot: Vector2 in SHARDS:
				var at: Vector2 = inner.position + spot * inner.size
				draw_polygon(PackedVector2Array([
					at + Vector2(0.0, -22.0), at + Vector2(17.0, 0.0),
					at + Vector2(0.0, 22.0), at + Vector2(-17.0, 0.0)]),
					PackedColorArray([deep, deep, deep, deep]))
		"arc":
			draw_arc(Vector2(mid.x, inner.end.y - 24.0), 176.0, PI, TAU, 64, deep, 7.0)
			draw_arc(Vector2(mid.x, inner.end.y - 24.0), 118.0, PI, TAU, 48, ink, 5.0)
		"checker":
			for col: int in range(Rooms.COLS - 2):
				for row: int in range(Rooms.ROWS - 2):
					if (col + row) % 2 == 1:
						continue
					draw_rect(Rect2(inner.position + Vector2(float(col) * t, float(row) * t),
						Vector2(t, t)), ink)

## 무늬용 고정 좌표. 방 안쪽 사각형에 대한 비율이라 타일 크기를 바꿔도 따라간다.
const RUBBLE: Array[Vector2] = [
	Vector2(0.16, 0.22), Vector2(0.31, 0.71), Vector2(0.48, 0.34),
	Vector2(0.57, 0.82), Vector2(0.72, 0.19), Vector2(0.79, 0.61),
	Vector2(0.88, 0.38), Vector2(0.23, 0.52),
]
const SHARDS: Array[Vector2] = [
	Vector2(0.22, 0.32), Vector2(0.38, 0.68), Vector2(0.52, 0.24),
	Vector2(0.66, 0.62), Vector2(0.81, 0.40),
]

func _draw_room_name(label: String, origin: Vector2, rect: Rect2, accent: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
	var at: Vector2 = origin + Vector2(
		(rect.size.x - width) * 0.5, float(Rooms.TILE) * 0.5 + 8.0)
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(accent, 0.85))

## 바라보는 쪽의 시트. 서쪽 시트는 없고 동쪽을 뒤집어 쓴다.
func sheet_for(dir: Vector2) -> Texture2D:
	if absf(dir.x) > absf(dir.y):
		return WALK_E
	if dir.y < 0.0:
		return WALK_N
	# 남쪽만 대기 시트가 따로 있다. 나머지 방향은 걷기 시트의 첫 프레임으로 선다.
	if not moving:
		return IDLE_S
	return WALK_S

func flip_for(dir: Vector2) -> bool:
	return absf(dir.x) > absf(dir.y) and dir.x < 0.0

## 걸을 때만 프레임이 돈다. 남쪽 대기는 8장짜리 호흡이 따로 있어 계속 돌고, 나머지
## 방향은 서 있는 동안 첫 프레임에 머문다 -- 걷기 프레임을 제자리에서 돌리면 발이
## 땅을 긁는 것처럼 보인다.
func frame_index() -> int:
	if not moving and sheet_for(facing) != IDLE_S:
		return 0
	return int(anim_time * ANIM_FPS) % SHEET_FRAMES

## 셀을 놓아 발 기준점이 주인공 발치에 오게 한다. 모든 프레임이 같은 기준점을 쓰므로
## 프레임별 보정표가 필요 없다.
func _draw_player() -> void:
	var at: Vector2 = room_origin() + player_pos
	var feet: Vector2 = at + Vector2(0.0, FOOT_DROP)

	# 바닥 그림자. 납작한 타원이라 캐릭터가 격자 위에 떠 있지 않고 서 있게 보인다.
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, PLAYER_RADIUS * 1.45, Color(0.0, 0.0, 0.0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var sheet: Texture2D = sheet_for(facing)
	var src := Rect2(float(frame_index()) * CELL, 0.0, CELL, CELL)
	var size := Vector2(CELL, CELL) * SPRITE_SCALE
	var corner: Vector2 = -FOOT_ANCHOR * SPRITE_SCALE

	# 반전은 발 기준점을 축으로 한다. 셀 중심으로 뒤집으면 기준점 x가 중앙이 아닌
	# 만큼 발이 옆으로 밀린다.
	var flip: float = -1.0 if flip_for(facing) else 1.0
	draw_set_transform(feet, 0.0, Vector2(flip, 1.0))
	draw_texture_rect_region(sheet, Rect2(corner, size), src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_stick() -> void:
	if touch_index == -1:
		return
	var travel: Vector2 = touch_at - touch_origin
	if travel.length() > STICK_MAX:
		travel = travel.normalized() * STICK_MAX
	draw_circle(touch_origin, STICK_MAX, STICK_RING)
	draw_circle(touch_origin + travel, 26.0, STICK_KNOB)

## 문이 어떻게 보이는가. 두 가지뿐이고, 그 사이에 함정이 숨는다.
enum DoorLook {
	KNOWN,    ## 이미 가 본 방으로 이어진다. 안전하다는 것이 확실하다.
	UNKNOWN,  ## 못 가 본 진짜 방이거나, 가짜 문이거나. 둘은 구분되지 않는다.
	SEALED,   ## 봉인. 잠긴 것은 보여야 한다 -- 보이지 않는 자물쇠는 열쇠를 찾게 만들지 못한다.
}

## 이 힌트는 안전을 증명할 수는 있어도 위험을 증명하지는 못한다. 그래서 "완전히는
## 알 수 없지만 힌트는 있다"가 성립한다 -- 가 본 문을 지워 나가면 후보는 줄지만
## 마지막 선택은 끝까지 추측으로 남는다.
func door_look(coord: Vector2i, dir: Vector2i) -> DoorLook:
	if Rooms.is_trap(coord, dir):
		return DoorLook.UNKNOWN
	# 봉인은 함정과 반대다. 함정은 숨어야 하고 봉인은 보여야 한다 -- 잠긴 문을 본
	# 기억이 열쇠를 찾으러 가게 만든다.
	if not can_enter(coord + dir):
		return DoorLook.SEALED
	if discovered.has(coord + dir):
		return DoorLook.KNOWN
	return DoorLook.UNKNOWN

## 방 단위 힌트. 이 방에 가짜 문이 있으면 벽 아래로 찬 바람 자국이 깔린다. 어느 문인지는
## 말하지 않는다 -- 말하는 순간 힌트가 아니라 표지판이 되고, 고를 것이 없어진다.
func _draw_draught(coord: Vector2i) -> void:
	if not Rooms.has_trap(coord):
		return
	var t: float = float(Rooms.TILE)
	var rect: Rect2 = Rooms.room_rect()
	var cold := Color(0.741, 0.855, 0.949, 0.13)
	var wisp := Color(0.741, 0.855, 0.949, 0.08)
	for i: int in range(Rooms.COLS - 2):
		var x: float = t + float(i) * t + 8.0
		draw_rect(Rect2(x, t + 4.0, t - 16.0, 3.0), cold)
		draw_rect(Rect2(x, rect.size.y - t - 7.0, t - 16.0, 3.0), cold)
		# 안쪽으로 흘러 들어오는 짧은 자국. 길이를 칸마다 달리해 결을 만든다.
		var streak: float = 18.0 + 10.0 * float(i % 3)
		draw_rect(Rect2(x + 6.0, t + 12.0, streak, 2.0), wisp)
		draw_rect(Rect2(x + 6.0, rect.size.y - t - 15.0, streak, 2.0), wisp)
	for i: int in range(Rooms.ROWS - 2):
		var y: float = t + float(i) * t + 8.0
		draw_rect(Rect2(t + 4.0, y, 3.0, t - 16.0), cold)
		draw_rect(Rect2(rect.size.x - t - 7.0, y, 3.0, t - 16.0), cold)

## 봉인된 문에는 빗장을 그린다. 지나갈 수 없다는 것과 언젠가 지나갈 수 있다는 것을
## 동시에 말해야 해서, 벽으로 막지 않고 문 위에 덧그린다.
func _draw_seal(col: int, row: int, cell: Rect2) -> void:
	var horizontal: bool = (row == 0 or row == Rooms.ROWS - 1)
	for i: int in range(3):
		var f: float = 0.28 + 0.22 * float(i)
		if horizontal:
			var y: float = cell.position.y + cell.size.y * f
			draw_rect(Rect2(cell.position.x, y, cell.size.x, 5.0), SEAL)
		else:
			var x: float = cell.position.x + cell.size.x * f
			draw_rect(Rect2(x, cell.position.y, 5.0, cell.size.y), SEAL)

## 인장. 아직 안 주웠을 때만 그린다.
func _draw_sigil() -> void:
	if has_sigil or current_room != Rooms.SIGIL_ROOM:
		return
	var at: Vector2 = room_origin() + Rooms.room_rect().get_center()
	draw_circle(at, SIGIL_RADIUS + 12.0, Color(SIGIL, 0.16))
	draw_polygon(PackedVector2Array([
		at + Vector2(0.0, -SIGIL_RADIUS), at + Vector2(SIGIL_RADIUS * 0.72, 0.0),
		at + Vector2(0.0, SIGIL_RADIUS), at + Vector2(-SIGIL_RADIUS * 0.72, 0.0)]),
		PackedColorArray([SIGIL, SIGIL, SIGIL, SIGIL]))
	draw_circle(at, 5.0, Color(0.145, 0.106, 0.043))

## 화면 가운데 잠깐 뜨는 한 줄. 발견·인장·봉인이 같은 자리를 쓰되 서로 겹치지 않도록
## 한 번에 하나만 그린다.
func _draw_notice() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var label := ""
	var life: float = 0.0
	var tint: Color = DOOR
	if sigil_timer > 0.0:
		label = "SIGIL TAKEN"
		life = sigil_timer
		tint = SIGIL
	elif sealed_timer > 0.0:
		label = "SEALED"
		life = sealed_timer
		tint = SEAL
	if label == "":
		return
	var rect: Rect2 = Rooms.room_rect()
	var fade: float = clampf(life / 0.4, 0.0, 1.0)
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x
	var band := Rect2(0.0, rect.size.y * 0.5 - 96.0, rect.size.x, 52.0)
	draw_rect(band, Color(0.031, 0.027, 0.043, 0.62 * fade))
	draw_string(font, Vector2((rect.size.x - width) * 0.5, band.position.y + 37.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(tint, fade))

func _door_dir(col: int, row: int) -> Vector2i:
	if row == 0:
		return Vector2i.UP
	if row == Rooms.ROWS - 1:
		return Vector2i.DOWN
	if col == 0:
		return Vector2i.LEFT
	return Vector2i.RIGHT

func _is_border(col: int, row: int) -> bool:
	return col == 0 or row == 0 or col == Rooms.COLS - 1 or row == Rooms.ROWS - 1

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
