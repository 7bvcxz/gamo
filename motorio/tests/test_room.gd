extends SceneTree

## The hut has an inside now.
##
## Going to bed used to happen the moment she pressed Z at the door: night fell,
## she faced a wall, the screen cut to a summary card. The one warm place in the
## game was a button. Z opens a room instead -- a fire, two sofas, a bed -- and
## sleeping is crossing it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_the_door()
	await _test_the_bed()
	await _test_walking()
	await _test_the_cats()
	_test_the_furniture_lines_up()
	_test_the_world_is_hidden()
	await _test_the_debug_key()
	if failures == 0:
		print("ROOM: PASS")
	else:
		print("ROOM: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _main() -> Node2D:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	return main

## Night, at the door. Not before: a room she can walk into at noon is a room
## that competes with the day.
func _test_the_door() -> void:
	var main: Node2D = await _main()
	main.player.position = main.shelter_doorstep()
	main.time_left = Defs.DAY_SECONDS
	_assert(not main.sleep_available(), "낮에는 들어갈 수 없다")
	main._primary_action()
	_assert(not main.room_open, "그래서 Z 를 눌러도 열리지 않는다")

	main.time_left = Defs.NIGHT_SECONDS * 0.5
	_assert(main.sleep_available(), "밤에 문 앞이면 들어갈 수 있다")
	main._primary_action()
	_assert(main.room_open, "Z 가 방을 연다")
	_assert(main.modal_open(), "그동안 주인공은 입력을 받지 않는다")
	_assert(main.state == main.State.PLAY, "그리고 아직 잠든 것은 아니다")
	# X leaves, like every other window in this game.
	main.close_room()
	_assert(not main.room_open and not main.modal_open(), "나오면 조작이 돌아온다")
	main.clear_save()
	main.free()

## The bed and the door, reached by walking to them.
##
## The cursor is gone as of 1.0.12: she walks in there and Z acts on the cell she
## is facing, exactly as it does outside. A room whose arrow keys move a
## highlight is a menu with furniture drawn on it.
func _test_the_bed() -> void:
	var main: Node2D = await _main()
	main.player.position = main.shelter_doorstep()
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	main.open_room()
	# Facing furniture that is neither: nothing happens and nothing is said.
	main.room_pos = Vector2(1, 2)
	main.room_facing = Vector2i(0, -1)
	main.room_confirm()
	_assert(main.room_open and main.state == main.State.PLAY,
		"벽난로를 보고 눌러도 아무 일도 없다")
	# The door, which is how she gets out.
	main.room_pos = Vector2(Defs.ROOM_ENTRY)
	main.room_facing = Vector2i(0, 1)
	_assert(Defs.room_piece_on(main.room_facing_cell()) >= 0, "문을 보고 있다")
	main.room_confirm()
	_assert(not main.room_open, "문 앞에서 Z 를 누르면 나간다")
	_assert(main.state == main.State.PLAY, "그리고 밤은 그대로다")

	# And the bed, which ends it.
	main.open_room()
	main.room_pos = Vector2(Defs.ROOM_WAKE)
	main.room_facing = Vector2i(1, 0)
	var facing: int = Defs.room_piece_on(main.room_facing_cell())
	_assert(facing >= 0 and int(Defs.ROOM_PIECES[facing]["id"]) == Defs.ROOM_BED,
		"깨어나는 자리에서는 침대를 보고 있다")
	main.room_confirm()
	_assert(not main.room_open, "침대 앞에서 Z 를 누르면 방이 닫히고")
	_assert(main.state != main.State.PLAY, "밤 연출이 시작된다: %d" % main.state)
	main.clear_save()
	main.free()

## Walls stop her, and the floor does not.
func _test_walking() -> void:
	var main: Node2D = await _main()
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	main.open_room()
	# Into the bottom wall: she is at the entry cell, and below it is the door.
	main.room_pos = Vector2(Defs.ROOM_ENTRY)
	main.player.touch_direction = Vector2(0, 1)
	for step in 60:
		main._update_room(1.0 / 60.0)
	_assert(main.room_pos.y <= float(Defs.ROOM_ENTRY.y) + 0.5,
		"문은 벽이라 통과하지 않는다: y=%.2f" % main.room_pos.y)
	_assert(main.room_facing == Vector2i(0, 1), "그리고 그쪽을 보고 있다")
	# Across the floor, which she can cross.
	main.player.touch_direction = Vector2(-1, 0)
	for step in 60:
		main._update_room(1.0 / 60.0)
	_assert(main.room_pos.x < float(Defs.ROOM_ENTRY.x) - 0.5,
		"바닥은 걸어서 지나간다: x=%.2f" % main.room_pos.x)
	_assert(Defs.room_walkable(Vector2i(main.room_pos.round())),
		"그리고 가구 위에 서 있지 않다")
	main.player.touch_direction = Vector2.ZERO
	main.clear_save()
	main.free()

## The crew files in behind her, and goes back to work when she opens the door.
func _test_the_cats() -> void:
	var main: Node2D = await _main()
	main.sim.grant_cats(3)
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	main.open_room()
	_assert(main.room_cat_positions().is_empty(), "처음에는 아직 아무도 안 들어왔다")
	for step in 60:
		main._update_room(1.0 / 60.0)
	var first: int = main.room_cat_positions().size()
	_assert(first >= 1, "한 마리가 먼저 들어온다: %d" % first)
	for step in 240:
		main._update_room(1.0 / 60.0)
	_assert(main.room_cat_positions().size() == 3, "차례로 셋 다 들어온다")
	# Morning: the room holds them until the door opens.
	main.room_holds_cats = true
	main.close_room()
	_assert(not main.room_holds_cats, "문이 열리면 붙잡고 있던 것이 풀리고")
	_assert(main.room_cat_positions().is_empty(), "방 안에는 아무도 없다")
	main.clear_save()
	main.free()

## What is drawn and what is clicked are the same rectangles.
##
## A room drawn one way and hit-tested another is a room where the bed is not
## where it looks, and this repository has already shipped a window that could be
## opened on a phone and then not used.
func _test_the_furniture_lines_up() -> void:
	var hud = load("res://scripts/HUD.gd").new()
	hud.size = Vector2(1280, 720)
	var floor_rect: Rect2 = hud.room_floor()
	_assert(Defs.ROOM_PIECES.size() == 6, "방 안의 물건이 여섯이다")
	var ids := {}
	for index in Defs.ROOM_PIECES.size():
		var piece: Dictionary = Defs.ROOM_PIECES[index]
		ids[int(piece["id"])] = true
		var rect: Rect2 = hud.room_piece_rect(index)
		_assert(floor_rect.grow(1.0).encloses(rect),
			"%s 가 방 안에 있다" % String(piece["name"]))
		_assert(hud.room_piece_at(rect.get_center()) == index,
			"%s 의 가운데를 누르면 그것이 잡힌다" % String(piece["name"]))
		var cell: Vector2i = piece["cell"]
		var span: Vector2i = piece["size"]
		_assert(cell.x >= 0 and cell.y >= 0 and cell.x + span.x <= Defs.ROOM_CELLS.x
			and cell.y + span.y <= Defs.ROOM_CELLS.y,
			"%s 가 8x6 격자를 넘지 않는다" % String(piece["name"]))
	_assert(ids.size() == 6, "벽난로·소파 둘·침대·문·창문이 각각 하나씩")
	# Nothing overlaps: two pieces sharing a cell is one of them unreachable.
	for a in Defs.ROOM_PIECES.size():
		for b in range(a + 1, Defs.ROOM_PIECES.size()):
			_assert(not hud.room_piece_rect(a).intersects(hud.room_piece_rect(b)),
				"%d번과 %d번이 겹치지 않는다" % [a, b])
	# And the bed is on the right, which is where it was asked to be.
	for index in Defs.ROOM_PIECES.size():
		if int(Defs.ROOM_PIECES[index]["id"]) != Defs.ROOM_BED:
			continue
		var bed: Vector2i = Defs.ROOM_PIECES[index]["cell"]
		_assert(bed.x >= Defs.ROOM_CELLS.x / 2, "침대는 오른쪽에 있다: x=%d" % bed.x)
	# And the door is on the bottom wall, in the middle: it is the wall she came
	# through, and a way out in a corner is a way out nobody finds.
	for index in Defs.ROOM_PIECES.size():
		if int(Defs.ROOM_PIECES[index]["id"]) != Defs.ROOM_DOOR:
			continue
		var door: Dictionary = Defs.ROOM_PIECES[index]
		var cell: Vector2i = door["cell"]
		var span: Vector2i = door["size"]
		_assert(cell.y + span.y == Defs.ROOM_CELLS.y, "문은 아래쪽 벽에 있다: y=%d" % cell.y)
		var middle: float = float(cell.x) + float(span.x) * 0.5
		_assert(absf(middle - float(Defs.ROOM_CELLS.x) * 0.5) < 0.6,
			"그리고 가운데다: %.1f" % middle)
	hud.free()


## The key that opens the room without waiting for night.
##
## Pinned for the same reason the debris key is: a debug tool that quietly stops
## working puts the cost of checking back where it was, and here that cost is
## most of a day at normal speed.
func _test_the_debug_key() -> void:
	var main: Node2D = await _main()
	var key := InputEventKey.new()
	key.keycode = KEY_F11
	key.physical_keycode = KEY_F11
	key.pressed = true
	main.time_left = Defs.DAY_SECONDS
	_assert(not main.sleep_available(), "낮이고 문 앞도 아니다")
	main.open_room()
	_assert(main.room_open, "그래도 디버그로는 열린다")
	main.close_room()
	main.clear_save()
	main.free()


## And the world behind it is gone, not dimmed.
##
## Every other window here is a panel over the plateau, which is right for the
## things she does while standing outside. A room with a door is not one of
## those: snow and cats carrying on behind the wall says she never went in.
func _test_the_world_is_hidden() -> void:
	var hud = load("res://scripts/HUD.gd")
	var backdrop: Color = hud.ROOM_BACKDROP
	_assert(is_equal_approx(backdrop.a, 1.0), "뒤가 완전히 가려진다: a=%.2f" % backdrop.a)
	_assert(backdrop.r + backdrop.g + backdrop.b <= 0.06,
		"그리고 검정이다: %.2f %.2f %.2f" % [backdrop.r, backdrop.g, backdrop.b])
