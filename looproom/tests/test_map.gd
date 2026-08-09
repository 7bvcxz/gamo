extends SceneTree

## "방은 최소 15개 존재하고, 각 방은 색/구조로 구분 가능하다"를 검사한다.
##
## 방 개수는 세면 되지만 나머지 둘은 세는 것으로 안 된다. 어느 한 방에도 갈 수 없으면
## 그 방은 없는 것과 같고(모든 방 발견이 영영 불가능해진다), 두 방이 똑같이 생겼으면
## 미니맵 없이 머릿속에 지도를 그린다는 전제가 무너진다.

const Rooms := preload("res://scripts/Rooms.gd")

## 두 방의 바닥색이 이보다 가까우면 무늬가 달라야 한다. RGB 유클리드 거리.
const MIN_COLOR_GAP := 0.12

func _init() -> void:
	var failures: int = 0

	failures += _expect(Rooms.count() >= 15, true, "방이 15개 이상 (%d개)" % Rooms.count())
	failures += _test_reachable()
	failures += _test_distinct()
	failures += _test_shape()

	print("MAP: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## 시작 방에서 문만 따라가 전부 닿을 수 있어야 한다.
func _test_reachable() -> int:
	var seen := {}
	var queue: Array[Vector2i] = [Rooms.START]
	seen[Rooms.START] = true
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		# 진짜 이웃만 따라간다. 함정은 가짜 문이라 그 방향으로는 아무 데도 가지 않는다.
		for dir: Vector2i in Rooms.real_exits(at):
			var next: Vector2i = at + dir
			if not seen.has(next):
				seen[next] = true
				queue.append(next)

	var failures: int = _expect(seen.size(), Rooms.count(),
		"시작 방에서 모든 방에 닿는다")
	for coord: Vector2i in Rooms.ROOMS.keys():
		if not seen.has(coord):
			print("    닿지 않는 방: %s (%s)" % [coord, Rooms.ROOMS[coord]["name"]])
	return failures

## 색이 비슷하면 무늬가 달라야 한다. 둘 다 같으면 두 방은 같은 방으로 보인다.
func _test_distinct() -> int:
	var failures: int = 0
	var coords: Array = Rooms.ROOMS.keys()
	var names := {}
	for coord: Vector2i in coords:
		var label: String = Rooms.ROOMS[coord]["name"]
		failures += _expect(names.has(label), false, "이름 %s 가 유일하다" % label)
		names[label] = true

	for i: int in range(coords.size()):
		for j: int in range(i + 1, coords.size()):
			var a: Dictionary = Rooms.ROOMS[coords[i]]
			var b: Dictionary = Rooms.ROOMS[coords[j]]
			var gap: float = _gap(a["floor"], b["floor"])
			if gap >= MIN_COLOR_GAP:
				continue
			if a["mark"] != b["mark"]:
				continue
			failures += _expect(false, true,
				"%s 와 %s 는 색(%.3f)도 무늬(%s)도 같다" % [a["name"], b["name"], gap, a["mark"]])
	return failures

## 방 하나가 갖춰야 할 것들. 빠진 키는 그리는 시점에 터진다.
func _test_shape() -> int:
	var failures: int = 0
	for coord: Vector2i in Rooms.ROOMS.keys():
		var data: Dictionary = Rooms.ROOMS[coord]
		for key: String in ["name", "mark", "floor", "accent"]:
			failures += _expect(data.has(key), true, "%s 에 %s 가 있다" % [coord, key])
		# 벽이 없는 방은 만들 수 없다: 사방이 전부 문이면 그릴 벽이 없다.
		failures += _expect(Rooms.exits(coord).size() <= 4, true, "%s 출구 수" % coord)
		# 진짜 출구가 없고 함정만 있는 방은 감옥이다.
		failures += _expect(Rooms.real_exits(coord).size() >= 1, true,
			"%s 는 고립되지 않았다" % coord)
	return failures

func _gap(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
