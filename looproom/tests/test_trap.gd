extends SceneTree

## "방 중 일부에 함정 출구가 있다: 진입 시 시작 방으로 회귀한다"를 검사한다.
##
## 함정에서 가장 위험한 실수는 진짜 문에 함정을 거는 것이다. 그러면 그 너머 방은
## 영영 발견할 수 없고, "모든 방 발견"이라는 클리어 조건이 조용히 불가능해진다.
## 화면에는 아무 이상도 나타나지 않으므로 여기서 막지 않으면 아무도 못 잡는다.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")
const Rooms := preload("res://scripts/Rooms.gd")

const FRAME := 0.016

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	# `_init` 시점에는 root Window 자체가 아직 트리에 없어서 `_ready`가 다음 프레임으로
	# 미뤄진다. 테스트는 그 프레임까지 가지 않고 끝나므로 직접 부른다 -- 이걸 빼면
	# `_ready`가 하는 초기화(시작 방 발견, 시작 위치)가 통째로 검사되지 않는다.
	main._ready()

	failures += _test_traps_are_false_doors()
	failures += _test_trap_sends_home(main)
	failures += _test_real_doors_do_not(main)
	failures += _test_lands_inside(main)

	main.free()
	print("TRAP: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## 함정은 반드시 뒤에 방이 없는 가짜 문이어야 한다. 그리고 "일부"라는 말이 성립하려면
## 함정이 있는 방과 없는 방이 둘 다 있어야 한다.
func _test_traps_are_false_doors() -> int:
	var failures: int = 0
	var rooms_with_traps: int = 0
	for coord: Vector2i in Rooms.ROOMS.keys():
		var traps: Array[Vector2i] = Rooms.trap_exits(coord)
		if not traps.is_empty():
			rooms_with_traps += 1
		for dir: Vector2i in traps:
			failures += _expect(Rooms.exists(coord + dir), false,
				"%s 의 %s 함정 뒤에는 방이 없다" % [coord, dir])
			# 그려지지 않는 함정은 밟을 수 없다.
			failures += _expect(Rooms.exits(coord).has(dir), true,
				"%s 의 %s 함정이 문으로 그려진다" % [coord, dir])

	failures += _expect(rooms_with_traps >= 2, true,
		"함정이 있는 방이 2개 이상 (%d개)" % rooms_with_traps)
	failures += _expect(rooms_with_traps < Rooms.count(), true,
		"함정이 없는 방도 있다")

	# 함정 방에도 진짜 출구가 남아 있어야 갇히지 않는다.
	for coord: Vector2i in Rooms.TRAPS.keys():
		failures += _expect(Rooms.real_exits(coord).size() >= 1, true,
			"%s 에 진짜 출구가 남아 있다" % coord)
	return failures

## 함정 문으로 걸어 들어가면 시작 방으로 돌아온다.
func _test_trap_sends_home(main: Node2D) -> int:
	var failures: int = 0
	var walked: int = 0
	for coord: Vector2i in Rooms.TRAPS.keys():
		for dir: Vector2i in Rooms.trap_exits(coord):
			main.set("current_room", coord)
			main.set("player_pos", Rooms.room_rect().get_center())
			# 회귀는 이제 연출을 거친다. 밟은 순간 방이 바뀌는 것이 아니라 연출이
			# 시작되고, 셔터가 닫힌 뒤에 옮겨진다.
			var sprung: bool = _walk_until_recall(main, Vector2(dir), 4.0)
			failures += _expect(sprung, true, "%s 의 %s 함정 문을 지났다" % [coord, dir])
			_settle(main)
			failures += _expect(main.get("current_room"), Rooms.START,
				"%s 의 %s 함정 -> 시작 방" % [coord, dir])
			walked += 1
	failures += _expect(walked >= 2, true, "함정 %d개를 실제로 밟았다" % walked)
	return failures

## 진짜 문은 회귀시키지 않는다. 함정 판정이 넓게 걸리면 멀쩡한 문도 집으로 보낸다.
func _test_real_doors_do_not(main: Node2D) -> int:
	var failures: int = 0
	_unlock_all(main)
	for coord: Vector2i in Rooms.ROOMS.keys():
		for dir: Vector2i in Rooms.real_exits(coord):
			main.set("current_room", coord)
			main.set("player_pos", Rooms.room_rect().get_center())
			_walk_until_change(main, Vector2(dir), 4.0)
			failures += _expect(main.get("current_room"), coord + dir,
				"%s 의 진짜 %s 문은 회귀시키지 않는다" % [coord, dir])
			failures += _expect(main.get("recall_timer"), 0.0,
				"%s 의 진짜 %s 문은 연출을 켜지 않는다" % [coord, dir])
	return failures

## 돌아온 자리가 벽 속이면 회귀가 아니라 끼임이다.
func _test_lands_inside(main: Node2D) -> int:
	var failures: int = 0
	main.set("current_room", Vector2i(3, 0))
	main.set("player_pos", Rooms.room_rect().get_center())
	main.call("recall")
	_settle(main)

	var pos: Vector2 = main.get("player_pos")
	var rect: Rect2 = Rooms.room_rect()
	var inner: float = float(Rooms.TILE) + MainScript.PLAYER_RADIUS
	failures += _expect(pos.x >= inner and pos.y >= inner
		and pos.x <= rect.size.x - inner and pos.y <= rect.size.y - inner, true,
		"회귀 후 시작 방 안쪽에 선다 (%s)" % pos)

	# 돌아온 직후 아무 방향으로도 즉시 다시 넘어가지 않는다.
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		main.set("current_room", Vector2i(3, 0))
		main.call("recall")
		_settle(main)
		main.call("step", dir * 2.0)
		failures += _expect(main.get("current_room"), Rooms.START,
			"회귀 직후 %s 로 한 걸음에 튕기지 않는다" % dir)
	return failures

## 함정을 밟았는지는 방이 바뀌는 것이 아니라 연출이 켜지는 것으로 안다.
func _walk_until_recall(main: Node2D, dir: Vector2, limit: float) -> bool:
	var frames: int = int(limit / FRAME)
	for i in range(frames):
		main.call("step", dir * MainScript.SPEED * FRAME)
		if main.get("recall_timer") > 0.0:
			return true
	return false

## 연출을 끝까지 돌린다. 상한을 두어 끝나지 않는 연출이 테스트를 매달지 않게 한다.
func _settle(main: Node2D) -> void:
	var guard: int = 0
	while main.get("recall_timer") > 0.0 and guard < 1000:
		main.call("advance_recall", FRAME)
		guard += 1

func _walk_until_change(main: Node2D, dir: Vector2, limit: float) -> bool:
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
