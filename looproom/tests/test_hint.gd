extends SceneTree

## "함정 출구는 진입 전에 완전히는 알 수 없지만, 최소 1가지 시각적 힌트가 존재한다"를
## 검사한다.
##
## 이 조건은 양쪽으로 틀릴 수 있고 두 실패가 정반대다. 힌트가 없으면 함정은 그냥
## 불공평한 벌이고, 힌트가 완벽하면 함정은 아무 일도 아니게 된다. 그래서 여기서는
## "힌트가 있다"와 "그 힌트로 함정을 지목할 수 없다"를 **둘 다** 강제한다.
##
## 힌트는 두 겹이다:
##  1) 방 단위 -- 가짜 문이 있는 방에는 찬 바람 자국이 깔린다. 어느 문인지는 모른다.
##  2) 문 단위 -- 가 본 방으로 이어지는 문에만 그 방 색이 비친다. 안전은 증명되지만
##     위험은 증명되지 않는다.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")
const Rooms := preload("res://scripts/Rooms.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	# `_init` 시점에는 root Window 자체가 아직 트리에 없어서 `_ready`가 다음 프레임으로
	# 미뤄진다. 테스트는 그 프레임까지 가지 않고 끝나므로 직접 부른다.
	main._ready()

	failures += _test_room_hint_exists()
	failures += _test_trap_never_looks_different(main)
	failures += _test_known_doors_are_readable(main)
	failures += _test_choice_stays_a_guess(main)

	main.free()
	print("HINT: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## 방 단위 힌트가 실제로 갈라져야 한다. 모든 방에 뜨거나 아무 방에도 안 뜨면 정보가 0이다.
func _test_room_hint_exists() -> int:
	var marked: int = 0
	for coord: Vector2i in Rooms.ROOMS.keys():
		if Rooms.has_trap(coord):
			marked += 1
	var failures: int = _expect(marked >= 1, true, "찬 바람이 도는 방이 있다 (%d개)" % marked)
	failures += _expect(marked < Rooms.count(), true, "찬 바람이 없는 방도 있다")

	# 힌트는 정확해야 한다. 함정이 없는 방에 뜨면 거짓말이고, 있는 방에 안 뜨면 누락이다.
	for coord: Vector2i in Rooms.ROOMS.keys():
		failures += _expect(Rooms.has_trap(coord), not Rooms.trap_exits(coord).is_empty(),
			"%s 의 찬 바람 표시가 실제 함정 유무와 일치" % coord)
	return failures

## **핵심 불변식**: 가짜 문은 아직 못 가 본 진짜 문과 언제나 똑같이 보인다.
## 이게 깨지면 함정은 이름표가 붙은 것과 같다.
func _test_trap_never_looks_different(main: Node2D) -> int:
	var failures: int = 0
	# 발견 상태를 여러 단계로 바꿔 가며 확인한다. 어느 상태에서도 갈라지면 안 된다.
	for revealed: int in [0, 1, 5, Rooms.count()]:
		main.set("discovered", _discover_first(revealed))
		for coord: Vector2i in Rooms.ROOMS.keys():
			for dir: Vector2i in Rooms.trap_exits(coord):
				failures += _expect(main.call("door_look", coord, dir),
					MainScript.DoorLook.UNKNOWN,
					"%s 의 %s 가짜 문은 %d개 발견 상태에서도 UNKNOWN" % [coord, dir, revealed])
	return failures

## 가 본 방으로 이어지는 문은 읽혀야 한다. 전부 UNKNOWN이면 힌트가 아예 없는 것과 같다.
func _test_known_doors_are_readable(main: Node2D) -> int:
	var failures: int = 0
	main.set("discovered", _discover_first(Rooms.count()))
	var known: int = 0
	for coord: Vector2i in Rooms.ROOMS.keys():
		for dir: Vector2i in Rooms.real_exits(coord):
			if main.call("door_look", coord, dir) == MainScript.DoorLook.KNOWN:
				known += 1
	failures += _expect(known > 0, true, "전부 발견하면 읽히는 문이 생긴다 (%d개)" % known)

	# 아무것도 발견하지 않은 상태에서는 읽히는 문이 없어야 한다. 첫 화면에서 이미
	# 안전한 문을 알 수 있으면 탐험이 아니라 안내다.
	main.set("discovered", {Rooms.START: true})
	var early: int = 0
	for dir: Vector2i in Rooms.real_exits(Rooms.START):
		if main.call("door_look", Rooms.START, dir) == MainScript.DoorLook.KNOWN:
			early += 1
	failures += _expect(early, 0, "시작 방의 문은 처음에 전부 미지다")
	return failures

## **핵심 불변식 2**: 함정 방에 처음 들어선 순간, 모르는 문이 항상 둘 이상 남는다.
## 하나만 남으면 방 단위 힌트와 합쳐져 함정이 완전히 지목된다.
func _test_choice_stays_a_guess(main: Node2D) -> int:
	var failures: int = 0
	for coord: Vector2i in Rooms.TRAPS.keys():
		# 최단 경로로 처음 도달했다고 보고, 지나온 방들만 발견 상태로 둔다.
		var path: Array[Vector2i] = _shortest_path(coord)
		failures += _expect(path.size() > 0, true, "%s 로 가는 길이 있다" % coord)
		var seen := {}
		for step: Vector2i in path:
			seen[step] = true
		main.set("discovered", seen)

		var unknown: int = 0
		for dir: Vector2i in Rooms.exits(coord):
			if main.call("door_look", coord, dir) == MainScript.DoorLook.UNKNOWN:
				unknown += 1
		failures += _expect(unknown >= 2, true,
			"%s 에 처음 왔을 때 모르는 문이 %d개 (2개 이상이어야 한다)" % [coord, unknown])

		# 그리고 그중 하나는 반드시 진짜 방으로 이어져야 한다. 모르는 문이 전부
		# 함정이면 개수만 둘일 뿐 선택은 없다.
		var unknown_real: int = 0
		for dir: Vector2i in Rooms.real_exits(coord):
			if main.call("door_look", coord, dir) == MainScript.DoorLook.UNKNOWN:
				unknown_real += 1
		failures += _expect(unknown_real >= 1, true,
			"%s 의 모르는 문 중 진짜가 %d개" % [coord, unknown_real])
	return failures

## 시작 방에서 목표 방까지 최단 경로(지나는 방 전부).
func _shortest_path(goal: Vector2i) -> Array[Vector2i]:
	var prev := {Rooms.START: Rooms.START}
	var queue: Array[Vector2i] = [Rooms.START]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if at == goal:
			break
		for dir: Vector2i in Rooms.real_exits(at):
			var next: Vector2i = at + dir
			if not prev.has(next):
				prev[next] = at
				queue.append(next)
	if not prev.has(goal):
		return [] as Array[Vector2i]
	var path: Array[Vector2i] = []
	var walk: Vector2i = goal
	while walk != Rooms.START:
		path.append(walk)
		walk = prev[walk]
	path.append(Rooms.START)
	return path

## 시작 방에서 가까운 순으로 n개를 발견한 상태를 만든다.
func _discover_first(n: int) -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = [Rooms.START]
	var order: Array[Vector2i] = []
	var visited := {Rooms.START: true}
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		order.append(at)
		for dir: Vector2i in Rooms.real_exits(at):
			var next: Vector2i = at + dir
			if not visited.has(next):
				visited[next] = true
				queue.append(next)
	for i: int in range(mini(n, order.size())):
		seen[order[i]] = true
	return seen

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
