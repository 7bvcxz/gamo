extends SceneTree

## "특정 방 몇개는 단계적인 입장 순서가 존재"를 검사한다.
##
## 사슬은 인장 → 첫 봉인 → 둘째 봉인 → (둘 다) 금고다. 여기서 조용히 틀리는 방법은
## 사슬이 사슬이 아니게 되는 것이다 -- 인장 하나로 셋이 다 열리거나, 순서를 건너뛰어도
## 들어가지거나. 그러면 조건은 "잠긴 방이 있다"로 줄어들고 단계는 사라진다.
##
## 그리고 더 위험한 실수: 잠긴 문 뒤에 열쇠를 두는 것. 그러면 게임이 완주 불가능해지고
## "모든 방 발견" 클리어가 영영 오지 않는다. 마지막 검사가 그것을 막는다.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")
const Rooms := preload("res://scripts/Rooms.gd")

const FRAME := 0.016
const FIRST := Vector2i(2, 1)
const SECOND := Vector2i(3, 0)
const VAULT := Vector2i(2, -3)

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	# `_init` 시점에는 root Window 자체가 아직 트리에 없어서 `_ready`가 미뤄진다.
	main._ready()

	failures += _test_chain_is_ordered(main)
	failures += _test_sigil_needs_walking(main)
	failures += _test_sealed_door_blocks_for_real(main)
	failures += _test_chain_is_completable(main)

	main.free()
	print("GATE: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## 단계마다 정확히 하나씩 열려야 한다. 앞 단계를 건너뛰면 잠겨 있어야 한다.
func _test_chain_is_ordered(main: Node2D) -> int:
	var failures: int = 0

	# 아무것도 없는 상태: 셋 다 잠겨 있다.
	_state(main, false, [])
	failures += _expect(main.call("can_enter", FIRST), false, "인장 없이 첫 봉인은 잠김")
	failures += _expect(main.call("can_enter", SECOND), false, "인장 없이 둘째 봉인은 잠김")
	failures += _expect(main.call("can_enter", VAULT), false, "인장 없이 금고는 잠김")

	# 인장만: 첫 봉인만 열린다. 여기서 셋 다 열리면 사슬이 아니라 스위치다.
	_state(main, true, [])
	failures += _expect(main.call("can_enter", FIRST), true, "인장이 있으면 첫 봉인이 열린다")
	failures += _expect(main.call("can_enter", SECOND), false, "인장만으로 둘째는 안 열린다")
	failures += _expect(main.call("can_enter", VAULT), false, "인장만으로 금고는 안 열린다")

	# 첫 봉인까지 봤다: 둘째가 열리고 금고는 아직이다.
	_state(main, true, [FIRST])
	failures += _expect(main.call("can_enter", SECOND), true, "첫 봉인을 본 뒤 둘째가 열린다")
	failures += _expect(main.call("can_enter", VAULT), false, "하나만으로 금고는 안 열린다")

	# 둘째만 보고 첫째를 건너뛴 상태는 만들 수 없어야 정상이지만, 만들어도 금고는 잠긴다.
	_state(main, true, [SECOND])
	failures += _expect(main.call("can_enter", VAULT), false, "둘째만으로도 금고는 잠김")

	# 둘 다 본 뒤에야 금고가 열린다.
	_state(main, true, [FIRST, SECOND])
	failures += _expect(main.call("can_enter", VAULT), true, "둘 다 본 뒤 금고가 열린다")

	# 봉인이 아닌 방은 언제나 열려 있다.
	_state(main, false, [])
	var open_rooms: int = 0
	for coord: Vector2i in Rooms.ROOMS.keys():
		if not Rooms.is_gated(coord):
			failures += _expect(main.call("can_enter", coord), true,
				"%s 는 봉인이 아니다" % coord)
			open_rooms += 1
	failures += _expect(open_rooms, Rooms.count() - Rooms.GATES.size(),
		"봉인은 %d개뿐이다" % Rooms.GATES.size())
	return failures

## 인장은 방에 들어서는 것만으로는 얻어지지 않는다. 앞까지 걸어가야 한다.
func _test_sigil_needs_walking(main: Node2D) -> int:
	var failures: int = 0
	_state(main, false, [])
	main.set("current_room", Rooms.SIGIL_ROOM)
	# 방 구석. 들어서기만 한 상태다.
	main.set("player_pos", Vector2(120.0, 120.0))
	main.call("try_take_sigil")
	failures += _expect(main.get("has_sigil"), false, "방에 들어선 것만으로는 안 주워진다")

	main.set("player_pos", Rooms.room_rect().get_center())
	var took: bool = main.call("try_take_sigil")
	failures += _expect(took, true, "인장 앞까지 걸어가면 주워진다")
	failures += _expect(main.get("has_sigil"), true, "인장을 가졌다")
	failures += _expect(main.get("sigil_timer") > 0.0, true, "주웠다는 표시가 뜬다")

	# 두 번 주워지지 않는다.
	failures += _expect(main.call("try_take_sigil"), false, "이미 가진 인장은 다시 안 주워진다")

	# 다른 방 한가운데에는 인장이 없다.
	main.set("has_sigil", false)
	main.set("current_room", Rooms.START)
	main.set("player_pos", Rooms.room_rect().get_center())
	failures += _expect(main.call("try_take_sigil"), false, "다른 방에는 인장이 없다")
	return failures

## 잠긴 문은 실제로 걸어서 막혀야 한다. `can_enter`만 맞고 통행이 뚫려 있으면 소용없다.
func _test_sealed_door_blocks_for_real(main: Node2D) -> int:
	var failures: int = 0
	_state(main, false, [])
	# 첫 봉인 바로 위 방에서 아래로 걸어 내려간다.
	main.set("current_room", Vector2i(2, 0))
	main.set("player_pos", Rooms.room_rect().get_center())
	main.set("sealed_timer", 0.0)

	for i in range(250):
		main.call("step", Vector2.DOWN * MainScript.SPEED * FRAME)
	failures += _expect(main.get("current_room"), Vector2i(2, 0), "봉인된 문으로는 못 넘어간다")
	failures += _expect(main.get("sealed_timer") > 0.0, true, "막혔다는 안내가 뜬다")

	# 밀려난 자리가 방 안쪽이어야 한다. 문턱에 박혀 있으면 안내가 매 프레임 깜빡인다.
	var pos: Vector2 = main.get("player_pos")
	var rect: Rect2 = Rooms.room_rect()
	var inner: float = float(Rooms.TILE) + MainScript.PLAYER_RADIUS
	failures += _expect(pos.y <= rect.size.y - inner, true, "봉인 앞에서 밀려난다 (%s)" % pos)

	# 문은 봉인으로 보여야 한다. 잠긴 것이 안 보이면 열쇠를 찾으러 가지 않는다.
	failures += _expect(main.call("door_look", Vector2i(2, 0), Vector2i.DOWN),
		MainScript.DoorLook.SEALED, "봉인된 문은 봉인으로 보인다")

	# 조건을 갖추면 같은 문이 열린다.
	_state(main, true, [])
	main.set("current_room", Vector2i(2, 0))
	main.set("player_pos", Rooms.room_rect().get_center())
	for i in range(250):
		main.call("step", Vector2.DOWN * MainScript.SPEED * FRAME)
		if main.get("current_room") == FIRST:
			break
	failures += _expect(main.get("current_room"), FIRST, "인장을 얻으면 같은 문이 열린다")
	return failures

## **가장 중요한 검사**: 잠긴 문 뒤에 열쇠가 있으면 게임이 완주 불가능해진다.
## 사슬을 순서대로 따라가면 18개 방이 전부 열리는지 실제로 밟아 확인한다.
func _test_chain_is_completable(main: Node2D) -> int:
	var failures: int = 0
	_state(main, false, [])

	# 인장 방은 아무 봉인도 지나지 않고 갈 수 있어야 한다.
	failures += _expect(_reachable_without_gates(main, Rooms.SIGIL_ROOM), true,
		"인장 방은 봉인 없이 갈 수 있다")
	# 각 봉인의 문 앞까지도 봉인 없이 갈 수 있어야 한다.
	for gate: Vector2i in Rooms.GATES.keys():
		var approach: bool = false
		for dir: Vector2i in Rooms.real_exits(gate):
			if _reachable_without_gates(main, gate + dir):
				approach = true
		failures += _expect(approach, true, "%s 의 문 앞까지 봉인 없이 갈 수 있다" % gate)

	# 사슬을 순서대로 밟는다.
	main.set("has_sigil", true)
	var opened: Array[Vector2i] = [FIRST, SECOND, VAULT]
	var seen: Dictionary = main.get("discovered")
	for gate: Vector2i in opened:
		failures += _expect(main.call("can_enter", gate), true,
			"순서대로 오면 %s 가 열린다" % gate)
		seen[gate] = true
		main.set("discovered", seen)

	# 그리고 그 결과 18개가 전부 발견 가능한 상태다.
	var everything: int = 0
	for coord: Vector2i in Rooms.ROOMS.keys():
		if main.call("can_enter", coord):
			everything += 1
	failures += _expect(everything, Rooms.count(),
		"사슬을 다 따라가면 %d개 방이 전부 열린다" % Rooms.count())
	return failures

## 봉인된 방을 지나지 않고 목표에 닿는가.
func _reachable_without_gates(main: Node2D, goal: Vector2i) -> bool:
	var seen := {Rooms.START: true}
	var queue: Array[Vector2i] = [Rooms.START]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if at == goal:
			return true
		for dir: Vector2i in Rooms.real_exits(at):
			var next: Vector2i = at + dir
			if seen.has(next) or Rooms.is_gated(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen.has(goal)

func _state(main: Node2D, sigil: bool, seen: Array[Vector2i]) -> void:
	var found := {Rooms.START: true}
	for coord: Vector2i in seen:
		found[coord] = true
	main.set("discovered", found)
	main.set("has_sigil", sigil)
	main.set("recall_timer", 0.0)
	main.set("recall_pending", false)

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
