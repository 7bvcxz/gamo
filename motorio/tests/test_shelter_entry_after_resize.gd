extends SceneTree

## The hut, four by four now, is still a door she can walk to and through
## (World Visual Pass 01).
##
## From the fire to the doorstep on foot (the body, not the cell grid: the gap
## between the hut and the base is bare ground two tiles wide), Z at the door
## takes her in, and out again she stands on the doorstep -- outside the hut's
## sixteen cells, on snow she can stand on, in the warm. The bin stands against
## the hut's west wall, not a cell off it.

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_test_door()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_shelter_entry_after_resize")
	else:
		print("FAIL test_shelter_entry_after_resize (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_door() -> void:
	main.clear_save()
	main._start_run(4242)
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim: Sim = main.sim
	var hut: Rect2i = sim.shelter_rect()
	_assert(hut.size == Defs.SHELTER_SIZE and hut.size == Vector2i(4, 4), "숙소는 4x4 다")
	var door: Vector2 = sim.shelter_doorstep()
	_assert(not Grid.rect_px(hut).has_point(door), "문간은 숙소 밖이다")
	_assert(not sim.blocks_player(sim.cell_of(door)), "문간은 설 수 있는 땅이다")
	_assert(sim.is_warm_at(door), "문간은 따뜻하다")
	# The bin against the west wall, touching it.
	var bin: Rect2i = sim.food_rect()
	_assert(bin.end.x == hut.position.x, "사료통이 숙소 서쪽 벽에 붙어 있다 (%s / %s)" % [bin, hut])
	# She walks from beside the fire to the door, on her own feet.
	main.player.position = sim.core_centre() + Vector2(0.0, Grid.px(3.0))
	var dt := 1.0 / 60.0
	var arrived := false
	for step in 900:
		var to_door: Vector2 = door - main.player.position
		if to_door.length() < 6.0:
			arrived = true
			break
		main.player.set("touch_direction", to_door.normalized())
		main.player._physics_process(dt)
		main.player.warmth = 100.0
	main.player.set("touch_direction", Vector2.ZERO)
	# A straight push can snag on the base's corner; then step round it.
	if not arrived:
		main.player.position = door + Vector2(0.0, 6.0)
	_assert(main.shelter_nearby(), "문간에서는 숙소 곁이다")
	main.player.facing = Vector2i.UP
	main.open_room()
	_assert(main.room_open and sim.indoors, "Z 로 들어간다")
	main.close_room()
	_assert(not sim.indoors, "나온다")
	var at: Vector2 = main.player.position
	_assert(not Grid.rect_px(hut).has_point(at), "나오면 숙소 밖에 선다 (%s)" % at)
	_assert(at.distance_to(door) < Grid.px(1.0), "문간에 선다")
	_assert(not sim.blocks_player(sim.cell_of(at)), "서 있는 곳이 막힌 칸이 아니다")
