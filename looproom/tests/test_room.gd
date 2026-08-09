extends SceneTree

## "화면에는 항상 1개의 방만 표시된다"를 실제로 검사한다.
##
## 헤드리스가 깨끗하다는 것은 스크립트가 파싱된다는 뜻이지 한 방만 보인다는 뜻이
## 아니다. 이 규칙이 깨지는 방법은 둘이다: 여러 방을 한꺼번에 그리거나, 주인공을
## 따라다니는 카메라가 벽 너머를 미리 보여주거나. 둘 다 여기서 막는다.

const MainScene := preload("res://scenes/Main.tscn")
const Rooms := preload("res://scripts/Rooms.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	# `_init` 시점에는 root Window 자체가 아직 트리에 없어서 `_ready`가 다음 프레임으로
	# 미뤄진다. 테스트는 그 프레임까지 가지 않고 끝나므로 직접 부른다 -- 이걸 빼면
	# `_ready`가 하는 초기화(시작 방 발견, 시작 위치)가 통째로 검사되지 않는다.
	main._ready()

	# 방 = 고정 크기 그리드. 그리고 그 크기가 곧 화면 하나다.
	var rect: Rect2 = Rooms.room_rect()
	failures += _expect(rect.size, Vector2(960.0, 540.0), "방 하나가 뷰포트 하나다")
	failures += _expect(rect.size.x, float(Rooms.COLS * Rooms.TILE), "가로가 칸 수 x 타일")
	failures += _expect(rect.size.y, float(Rooms.ROWS * Rooms.TILE), "세로가 칸 수 x 타일")

	# 어느 방에 있든 보이는 방은 하나다.
	for coord: Vector2i in Rooms.ROOMS.keys():
		main.set("current_room", coord)
		var shown: Array = main.call("visible_rooms")
		failures += _expect(shown.size(), 1, "%s 에서 보이는 방 수" % coord)
		failures += _expect(shown[0], coord, "%s 에서 보이는 방은 자기 자신" % coord)

	# 카메라가 따라오지 않는다. 주인공을 방 네 귀퉁이로 보내도 그리는 원점이 같아야
	# 한다 -- 여기가 움직이면 벽 너머가 보이기 시작하고 발견이라는 것이 없어진다.
	main.set("current_room", Rooms.START)
	var baseline: Vector2 = main.call("room_origin")
	for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(959.0, 0.0),
			Vector2(0.0, 539.0), Vector2(959.0, 539.0), rect.get_center()]:
		main.set("player_pos", corner)
		failures += _expect(main.call("room_origin"), baseline,
			"주인공이 %s 에 있어도 원점 고정" % corner)

	# Camera2D 한 개면 위의 검사가 전부 무의미해진다. 노드로도 막아 둔다.
	failures += _expect(_has_camera(main), false, "씬에 Camera2D가 없다")

	main.free()
	print("ROOM: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _has_camera(node: Node) -> bool:
	if node is Camera2D:
		return true
	for child: Node in node.get_children():
		if _has_camera(child):
			return true
	return false

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
