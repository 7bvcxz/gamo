extends SceneTree

## "처음 도달한 방에는 발견 표시가 뜨고, 화면 구석에 발견한 방 수 / 전체 방 수가
## 표시된다"를 검사한다.
##
## 여기서 조용히 틀리는 방법이 둘 있다. 시작 방을 세지 않아 카운터가 끝까지 1개
## 모자란 것, 그리고 다시 들어온 방을 또 세어 전체 수를 넘기는 것. 둘 다 화면은
## 멀쩡해 보이고 마지막 한 방을 찾을 때가 되어서야 드러난다.

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

	failures += _test_start_counts(main)
	failures += _test_first_entry_only(main)
	failures += _test_walk_the_whole_map(main)
	failures += _test_recall_does_not_recount(main)

	main.free()
	print("DISCOVERY: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _test_start_counts(main: Node2D) -> int:
	var failures: int = _expect(main.call("discovered_count"), 1,
		"시작하자마자 시작 방 1개가 세어져 있다")
	failures += _expect(main.get("discovered").has(Rooms.START), true,
		"세어진 것이 시작 방이다")
	# 첫 화면부터 표시가 떠 있으면 그건 발견이 아니라 안내다.
	failures += _expect(main.get("discover_timer"), 0.0, "시작 화면에는 표시가 없다")
	return failures

## 처음 들어갈 때만 표시가 뜨고 숫자가 오른다.
func _test_first_entry_only(main: Node2D) -> int:
	var failures: int = 0
	_reset(main)

	var before: int = main.call("discovered_count")
	_walk_to(main, Vector2.RIGHT)
	failures += _expect(main.get("current_room"), Vector2i(1, 0), "동쪽 방에 들어갔다")
	failures += _expect(main.call("discovered_count"), before + 1, "새 방이 세어졌다")
	failures += _expect(main.get("discover_timer") > 0.0, true, "발견 표시가 떴다")
	failures += _expect(MainScript.DISCOVER_TIME > 0.0, true, "표시 시간이 0이 아니다")

	# 표시를 끝까지 흘려보내고 같은 방에 다시 들어간다.
	main.set("discover_timer", 0.0)
	var count: int = main.call("discovered_count")
	_walk_to(main, Vector2.LEFT)
	_walk_to(main, Vector2.RIGHT)
	failures += _expect(main.get("current_room"), Vector2i(1, 0), "같은 방에 다시 왔다")
	failures += _expect(main.call("discovered_count"), count, "두 번째 방문은 세지 않는다")
	failures += _expect(main.get("discover_timer"), 0.0, "두 번째 방문에는 표시가 없다")
	return failures

## 맵 전체를 실제로 걸어 전부 발견되는지, 그리고 전체 수를 넘지 않는지 본다.
func _test_walk_the_whole_map(main: Node2D) -> int:
	_reset(main)
	var order: Array[Vector2i] = _route()
	for coord: Vector2i in order:
		main.set("current_room", coord)
		main.call("arrive", coord)

	var failures: int = _expect(main.call("discovered_count"), Rooms.count(),
		"전부 걸으면 %d개가 다 세어진다" % Rooms.count())
	failures += _expect(main.call("discovered_count") <= Rooms.count(), true,
		"전체 수를 넘지 않는다")
	return failures

## 회귀로 시작 방에 돌아오는 것은 새 발견이 아니다.
func _test_recall_does_not_recount(main: Node2D) -> int:
	_reset(main)
	_walk_to(main, Vector2.RIGHT)
	var count: int = main.call("discovered_count")
	main.set("discover_timer", 0.0)

	main.call("recall")
	var guard: int = 0
	while main.get("recall_timer") > 0.0 and guard < 1000:
		main.call("advance_recall", FRAME)
		guard += 1

	var failures: int = _expect(main.get("current_room"), Rooms.START, "회귀로 시작 방")
	failures += _expect(main.call("discovered_count"), count, "회귀는 숫자를 올리지 않는다")
	failures += _expect(main.get("discover_timer"), 0.0, "회귀에는 발견 표시가 없다")
	return failures

## 시작 방에서 진짜 문만 따라 전 방을 도는 순서.
func _route() -> Array[Vector2i]:
	var order: Array[Vector2i] = []
	var seen := {Rooms.START: true}
	var queue: Array[Vector2i] = [Rooms.START]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		order.append(at)
		for dir: Vector2i in Rooms.real_exits(at):
			var next: Vector2i = at + dir
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return order

func _reset(main: Node2D) -> void:
	main.set("current_room", Rooms.START)
	main.set("player_pos", Rooms.room_rect().get_center())
	main.set("discovered", {Rooms.START: true})
	main.set("discover_timer", 0.0)
	main.set("recall_timer", 0.0)
	main.set("recall_pending", false)

func _walk_to(main: Node2D, dir: Vector2) -> void:
	var from: Vector2i = main.get("current_room")
	for i in range(250):
		main.call("step", dir * MainScript.SPEED * FRAME)
		if main.get("current_room") != from:
			return

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
