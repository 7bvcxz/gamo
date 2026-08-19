extends SceneTree

## The hut's inside, which is a place on the world grid rather than a panel.
##
## That is the whole design of it: the same character node walks in here, with
## the same speed, the same sheets, the same collision and the same wander the
## cats use outside. There is no second implementation to keep in step -- which
## is what the panel version needed, and where it went wrong (she walked right
## while facing left, and moved faster indoors than out, both from numbers and
## rules copied rather than shared).

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_the_floor_plan()
	await _test_the_door_and_the_bed()
	await _test_walking()
	await _test_collision()
	await _test_the_cats()
	await _test_sleeping()
	await _test_warm_and_saved()
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
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	return main

## The room, as a table. Five pieces on the floor, a window in the wall, nothing
## overlapping and the bed on the right where it was asked to be.
func _test_the_floor_plan() -> void:
	_assert(Defs.ROOM_PIECES.size() == 5, "바닥에 놓인 것이 다섯이다")
	var ids := {}
	for piece: Dictionary in Defs.ROOM_PIECES:
		ids[int(piece["id"])] = true
		var cell: Vector2i = piece["cell"]
		var span: Vector2i = piece["size"]
		_assert(cell.x >= 0 and cell.y >= 0 and cell.x + span.x <= Defs.ROOM_CELLS.x
			and cell.y + span.y <= Defs.ROOM_CELLS.y,
			"%s 가 8x6 안에 있다" % String(piece["name"]))
		for y in range(cell.y, cell.y + span.y):
			for x in range(cell.x, cell.x + span.x):
				_assert(not Defs.room_walkable(Vector2i(x, y)),
					"%s 위는 밟을 수 없다" % String(piece["name"]))
	_assert(ids.size() == 5, "벽난로·소파 둘·침대·문이 각각 하나씩")
	# Entry and wake are floor, or she starts inside the furniture.
	_assert(Defs.room_walkable(Defs.ROOM_ENTRY), "들어서는 자리는 바닥이다")
	_assert(Defs.room_walkable(Defs.ROOM_WAKE), "깨어나는 자리도 바닥이다")
	# And the round trip between the two coordinate systems.
	var probe := Vector2i(3, 4)
	_assert(Defs.world_to_room(Defs.room_to_world(probe)) == probe, "좌표 변환이 돌아온다")
	_assert(Defs.in_room(Defs.room_to_world(probe)), "방 안은 방 안이다")
	_assert(not Defs.in_room(Vector2i.ZERO), "기지는 방 밖이다")

## Z acts on the cell she is facing, which is the same cell it is outside.
func _test_the_door_and_the_bed() -> void:
	var main: Node2D = await _main()
	var sim = main.sim
	main.player.position = main.shelter_doorstep()
	_assert(main.sleep_available(), "밤에 문 앞이면 들어갈 수 있다")
	main._primary_action()
	_assert(main.room_open and sim.indoors, "Z 가 방으로 들여보낸다")
	_assert(Defs.in_room(main.player.cell()),
		"그리고 그녀는 방 안에 서 있다: %s" % str(main.player.cell()))

	# The fireplace answers nothing: furniture that replies is a caption.
	main.player.position = sim.cell_centre(Defs.room_to_world(Vector2i(1, 2)))
	main.player.facing = Vector2i.UP
	main.room_confirm()
	_assert(main.room_open and main.state == main.State.PLAY, "벽난로는 아무 일도 하지 않는다")

	# The door goes back outside.
	main.player.position = sim.cell_centre(Defs.room_to_world(Defs.ROOM_ENTRY))
	main.player.facing = Vector2i.DOWN
	var facing: int = main.room_facing_piece()
	_assert(facing >= 0 and int(Defs.ROOM_PIECES[facing]["id"]) == Defs.ROOM_DOOR,
		"들어선 자리에서는 문을 보고 있다")
	main.room_confirm()
	_assert(not main.room_open and not sim.indoors, "문으로 나간다")
	_assert(main.player.position.distance_to(main.shelter_doorstep()) < 1.0,
		"그리고 숙소 문 앞에 선다")
	main.clear_save()
	main.free()

## The arrow keys move her in there.
##
## They stopped working the moment the room became a place: the room was still
## listed as a modal, a modal switches off the character's own input poll, and
## the collision test below missed it because it drove `_physics_process`
## directly -- `player.modal` is written by Main once a frame, so a test that
## skips the frame never sees the thing that was switched off. This one runs the
## frame.
func _test_walking() -> void:
	var main: Node2D = await _main()
	var sim = main.sim
	main.open_room()
	_assert(not main.modal_open(), "방은 창이 아니다 — 창이면 발이 멈춘다")
	main.player.position = sim.cell_centre(Defs.room_to_world(Defs.ROOM_ENTRY))
	var before: Vector2 = main.player.position
	main.player.touch_direction = Vector2(-1, 0)
	for step in 60:
		main._process(1.0 / 60.0)
		main.player._physics_process(1.0 / 60.0)
	main.player.touch_direction = Vector2.ZERO
	_assert(not main.player.modal, "프레임을 돌려도 modal 이 아니고")
	_assert(main.player.position.distance_to(before) > float(Defs.TILE) * 0.5,
		"실제로 걸어간다: %.1fpx" % main.player.position.distance_to(before))
	_assert(Defs.in_room(main.player.cell()), "그리고 방 안이다")
	main.clear_save()
	main.free()

## The furniture is solid, to the same mover that walks her round a miner.
func _test_collision() -> void:
	var main: Node2D = await _main()
	var sim = main.sim
	main.open_room()
	for piece: Dictionary in Defs.ROOM_PIECES:
		var cell: Vector2i = Defs.room_to_world(piece["cell"])
		_assert(sim.blocks_player(cell),
			"%s 는 겹칠 수 없다" % String(piece["name"]))
	_assert(sim.blocks_player(Defs.room_to_world(Vector2i(-1, 2))), "왼쪽 벽도 막는다")
	_assert(sim.blocks_player(Defs.room_to_world(Vector2i(3, Defs.ROOM_CELLS.y))),
		"아래쪽 벽도 막는다")
	_assert(not sim.blocks_player(Defs.room_to_world(Defs.ROOM_ENTRY)), "바닥은 지나간다")
	# Through the mover, not just the predicate: she is a body with a collision
	# callable, and walking her into the bed has to stop her.
	main.player.position = sim.cell_centre(Defs.room_to_world(Defs.ROOM_WAKE))
	main.player.touch_direction = Vector2(1, 0)
	for step in 120:
		main.player._physics_process(1.0 / 60.0)
	main.player.touch_direction = Vector2.ZERO
	_assert(Defs.in_room(main.player.cell()), "침대를 향해 걸어도 방 안에 있다")
	_assert(Defs.room_walkable(Defs.world_to_room(main.player.cell())),
		"가구 위에 서 있지 않다: %s" % str(Defs.world_to_room(main.player.cell())))
	main.clear_save()
	main.free()

## Awake and strolling, and none of them leaves.
func _test_the_cats() -> void:
	var main: Node2D = await _main()
	var sim = main.sim
	sim.grant_cats(4)
	main.open_room()
	for cat in sim.cats:
		_assert(cat.state == Defs.CAT_IDLE, "들어오면 깨어 있다")
		_assert(Defs.in_room(sim.cell_of(cat.pos)), "그리고 방 안에 있다")
	var moved := false
	var before: Array[Vector2] = []
	for cat in sim.cats:
		before.append(cat.pos)
	for step in 600:
		sim.tick(1.0 / 60.0)
	for index in sim.cats.size():
		var cat = sim.cats[index]
		if cat.pos.distance_to(before[index]) > 4.0:
			moved = true
		_assert(Defs.in_room(sim.cell_of(cat.pos)),
			"십 초를 돌아다녀도 방을 벗어나지 않는다: %s" % str(sim.cell_of(cat.pos)))
		_assert(Defs.room_walkable(Defs.world_to_room(sim.cell_of(cat.pos))),
			"가구 위에 올라가지도 않는다: %s" % str(Defs.world_to_room(sim.cell_of(cat.pos))))
	_assert(moved, "그리고 실제로 돌아다닌다")
	main.clear_save()
	main.free()

## She lies down and everyone drops off on the same frame.
func _test_sleeping() -> void:
	var main: Node2D = await _main()
	var sim = main.sim
	sim.grant_cats(3)
	main.open_room()
	main.player.position = sim.cell_centre(Defs.room_to_world(Defs.ROOM_WAKE))
	main.player.facing = Vector2i.RIGHT
	var facing: int = main.room_facing_piece()
	_assert(facing >= 0 and int(Defs.ROOM_PIECES[facing]["id"]) == Defs.ROOM_BED,
		"깨어나는 자리에서는 침대를 보고 있다")
	main.room_confirm()
	_assert(main.room_sleeping, "눕기 시작한다")
	for cat in sim.cats:
		_assert(cat.state == Defs.CAT_ASLEEP, "고양이들이 일제히 잠든다")
	var spent := 0.0
	while main.room_sleeping and spent < 8.0:
		main._update_room(1.0 / 60.0)
		spent += 1.0 / 60.0
	_assert(is_equal_approx(main.room_fade, 1.0), "화면이 완전히 검어지고")
	_assert(main.state == main.State.RESULT, "그 다음에 하루 정리가 나온다")
	main.clear_save()
	main.free()


## Two things the room has to get right about the world outside it.
func _test_warm_and_saved() -> void:
	var main: Node2D = await _main()
	var sim = main.sim
	main.open_room()
	# Warm. The room is six hundred cells from the fire, so `is_warm` says no --
	# and she was freezing to death in her own hut with the bar ticking down
	# behind the sofa.
	main.player.warmth = 40.0
	for step in 60:
		main._update_warmth(1.0 / 60.0)
	_assert(main.player.warmth > 40.0, "안에서는 체온이 오른다: %.0f" % main.player.warmth)

	# And a run saved in here comes back outside: `indoors` is a moment, not a
	# fact about the world, so it is not saved -- and loading into the room
	# without it drops her into an unlit void.
	sim.grant_cats(2)
	main.save_game(false)
	main.close_room()
	_assert(main.load_game(), "방 안에서 저장한 회차가 불러와진다")
	_assert(not Defs.in_room(main.player.cell()),
		"그리고 밖에서 시작한다: %s" % str(main.player.cell()))
	for cat in sim.cats:
		_assert(not Defs.in_room(sim.cell_of(cat.pos)), "고양이도 밖에 있다")
	main.clear_save()
	main.free()
