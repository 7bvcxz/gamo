extends SceneTree

## "방향키/조이스틱으로 이동, 방 가장자리를 넘으면 인접한 방으로 전환된다"를 검사한다.
##
## 세 가지가 각각 따로 틀릴 수 있다: 키가 아예 매핑되지 않는 것, 벽을 통과하는 것,
## 문을 지나도 방이 바뀌지 않는 것. 그리고 터치는 손을 뗐을 때 멈추는지가 핵심이다 --
## 눌린 채로 남는 조이스틱은 화면상 멀쩡해 보이고 플레이할 때만 드러난다.

const MainScene := preload("res://scenes/Main.tscn")
const Rooms := preload("res://scripts/Rooms.gd")
## 상수는 인스턴스가 아니라 스크립트를 통해 읽는다 -- `get()`은 const를 보지 못한다.
const MainScript := preload("res://scripts/Main.gd")

const FRAME := 0.016

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	# `_init` 시점에는 root Window 자체가 아직 트리에 없어서 `_ready`가 다음 프레임으로
	# 미뤄진다. 테스트는 그 프레임까지 가지 않고 끝나므로 직접 부른다 -- 이걸 빼면
	# `_ready`가 하는 초기화(시작 방 발견, 시작 위치)가 통째로 검사되지 않는다.
	main._ready()

	failures += _test_keymap()
	failures += _test_walls(main)
	failures += _test_transition(main)
	failures += _test_return(main)
	failures += _test_diagonal(main)
	failures += _test_touch(main)

	main.free()
	print("MOVE: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## 숫자를 손으로 적었으니 상수와 대조한다. 이 저장소에는 화살표라고 적어 둔 값이
## 실제로는 Home/Page Up이었던 전례가 있다.
func _test_keymap() -> int:
	var failures: int = 0
	var want := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
	}
	for action: String in want.keys():
		failures += _expect(InputMap.has_action(action), true, "%s 액션 존재" % action)
		if not InputMap.has_action(action):
			continue
		var codes: Array[int] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				codes.append((event as InputEventKey).keycode)
		for code: int in want[action]:
			failures += _expect(codes.has(code), true,
				"%s 에 keycode %d 매핑" % [action, code])
	return failures

## 이웃 방이 없는 벽은 막혀야 한다. 어느 벽이 막혀 있는지는 맵에서 직접 읽는다 --
## 좌표를 손으로 적어 두면 맵을 넓힐 때마다 테스트가 옛 맵을 설명하게 된다.
func _test_walls(main: Node2D) -> int:
	var failures: int = 0
	var inner: float = float(Rooms.TILE) + MainScript.PLAYER_RADIUS
	var checked: int = 0

	for coord: Vector2i in Rooms.ROOMS.keys():
		var open: Array[Vector2i] = Rooms.exits(coord)
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if open.has(dir):
				continue
			_place(main, coord, Rooms.room_rect().get_center())
			_walk(main, Vector2(dir), 3.0)
			failures += _expect(main.get("current_room"), coord,
				"%s 의 막힌 %s 벽에서 방 유지" % [coord, dir])
			var pos: Vector2 = main.get("player_pos")
			var rect: Rect2 = Rooms.room_rect()
			var within: bool = (pos.x >= inner - 0.01 and pos.y >= inner - 0.01
				and pos.x <= rect.size.x - inner + 0.01
				and pos.y <= rect.size.y - inner + 0.01)
			failures += _expect(within, true,
				"%s 의 %s 벽을 통과하지 않는다 (%s)" % [coord, dir, pos])
			checked += 1

	# 막힌 벽이 하나도 없으면 위 반복이 통째로 비고 검사한 것이 없어진다.
	failures += _expect(checked >= 10, true, "막힌 벽을 %d개 검사했다" % checked)
	return failures

## 문이 있는 벽으로 걸으면 방이 바뀌고, 다른 축은 이어진다.
func _test_transition(main: Node2D) -> int:
	var failures: int = 0
	var start_y: float = Rooms.room_rect().get_center().y

	_place(main, Rooms.START, Rooms.room_rect().get_center())
	_walk_to_door(main, Vector2.RIGHT, 4.0)
	failures += _expect(main.get("current_room"), Vector2i(1, 0), "동쪽 문으로 이웃 방 진입")
	# 넘어간 그 순간의 자리를 잰다. 계속 걸은 뒤에 재면 진입 위치가 아니라 그 뒤
	# 위치를 재게 되고, 문이 어디에 놓였는지는 아무것도 말해 주지 않는다.
	failures += _expect(main.get("player_pos").x < float(Rooms.TILE), true,
		"새 방의 문 안쪽에 놓인다 (x=%.1f)" % main.get("player_pos").x)
	failures += _expect(absf(main.get("player_pos").y - start_y) < 1.0, true,
		"넘어갈 때 다른 축은 이어진다")

	_place(main, Rooms.START, Rooms.room_rect().get_center())
	_walk_to_door(main, Vector2.DOWN, 3.0)
	failures += _expect(main.get("current_room"), Vector2i(0, 1), "남쪽 문으로 이웃 방 진입")

	# 맵의 모든 문이 실제로 지나갈 수 있어야 한다. 그려는 놓고 못 지나가는 문이
	# 하나라도 있으면 그 너머 방은 영영 발견되지 않는다.
	_unlock_all(main)
	for coord: Vector2i in Rooms.ROOMS.keys():
		for dir: Vector2i in Rooms.real_exits(coord):
			_place(main, coord, Rooms.room_rect().get_center())
			_walk_to_door(main, Vector2(dir), 4.0)
			failures += _expect(main.get("current_room"), coord + dir,
				"%s 에서 %s 문을 지나 %s 로" % [coord, dir, coord + dir])
	return failures

## 들어간 문으로 되돌아 나올 수 있어야 한다. 새 방에 놓이는 위치가 문 바깥이면
## 들어서자마자 되돌아가거나, 반대로 영영 못 나온다.
func _test_return(main: Node2D) -> int:
	var failures: int = 0
	_place(main, Rooms.START, Rooms.room_rect().get_center())
	_walk_to_door(main, Vector2.RIGHT, 4.0)
	failures += _expect(main.get("current_room"), Vector2i(1, 0), "동쪽 방에 있다")

	# 한 프레임만으로 곧바로 되돌아가면 두 방 사이에서 튕긴다.
	main.call("step", Vector2.RIGHT * 1.0)
	failures += _expect(main.get("current_room"), Vector2i(1, 0), "진입 직후 튕기지 않는다")

	_walk_to_door(main, Vector2.LEFT, 4.0)
	failures += _expect(main.get("current_room"), Rooms.START, "왔던 문으로 되돌아 나온다")
	return failures

## 대각선이 직선보다 빠르면 안 된다.
func _test_diagonal(main: Node2D) -> int:
	Input.action_press("move_right")
	Input.action_press("move_up")
	var diagonal: float = main.call("input_direction").length()
	Input.action_release("move_right")
	Input.action_release("move_up")
	return _expect(diagonal <= 1.0001, true, "대각선 입력 길이 %.3f <= 1" % diagonal)

## 진짜 터치 이벤트로 밀고, 떼면 멈추는지 본다.
func _test_touch(main: Node2D) -> int:
	var failures: int = 0
	_place(main, Rooms.START, Rooms.room_rect().get_center())

	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(200.0, 400.0)
	main._input(press)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(280.0, 400.0)
	main._input(drag)

	failures += _expect(main.call("input_direction").x > 0.9, true, "오른쪽으로 민 조이스틱")
	var before: float = main.get("player_pos").x
	for i in range(20):
		main._process(FRAME)
	failures += _expect(main.get("player_pos").x > before, true, "터치로 실제 이동")

	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = Vector2(280.0, 400.0)
	main._input(release)

	failures += _expect(main.call("input_direction"), Vector2.ZERO, "손을 떼면 입력이 0")
	var settled: float = main.get("player_pos").x
	for i in range(20):
		main._process(FRAME)
	failures += _expect(main.get("player_pos").x, settled, "손을 뗀 뒤에는 멈춰 있다")
	return failures

func _place(main: Node2D, room: Vector2i, at: Vector2) -> void:
	main.set("current_room", room)
	main.set("player_pos", at)

func _walk(main: Node2D, dir: Vector2, seconds: float) -> void:
	var frames: int = int(seconds / FRAME)
	for i in range(frames):
		main.call("step", dir * MainScript.SPEED * FRAME)

## 방이 바뀌는 순간 멈춘다. 문을 지난 직후의 자리를 재려면 거기서 멈춰야 한다.
func _walk_to_door(main: Node2D, dir: Vector2, limit: float) -> bool:
	var from: Vector2i = main.get("current_room")
	var frames: int = int(limit / FRAME)
	for i in range(frames):
		main.call("step", dir * MainScript.SPEED * FRAME)
		if main.get("current_room") != from:
			return true
	return false

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1

## 봉인은 이 파일의 주제가 아니다. 문이 물리적으로 지나갈 수 있는지를 보려면 잠금을
## 먼저 풀어야 한다 -- 안 그러면 봉인된 문 세 개 때문에 이동 자체가 실패로 보인다.
func _unlock_all(main: Node2D) -> void:
	var everything := {}
	for coord: Vector2i in Rooms.ROOMS.keys():
		everything[coord] = true
	main.set("discovered", everything)
	main.set("has_sigil", true)
