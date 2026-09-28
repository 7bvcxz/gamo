extends SceneTree

## A night in the four by four hut and the morning after (World Visual Pass 01).
##
## In at the door, to bed, the night passes, she gets up in the room, and out
## through the door she stands on the doorstep -- outside the hut's sixteen
## cells, on ground she can stand on -- with the day running. The cats that
## slept inside come out and go back to their posts.

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_test_night()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_sleep_wake_after_shelter_resize")
	else:
		print("FAIL test_sleep_wake_after_shelter_resize (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_night() -> void:
	main.clear_save()
	main._start_run(4242)
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim: Sim = main.sim
	var node: Vector2i = sim.core_cell + Sim.STARTER_PATCH[1]
	sim.unlocked[Defs.M_MINER] = true
	sim.stock[Defs.ITEM_HEATSTONE] = 50
	sim.stock[Defs.ITEM_COPPER] = 50
	_assert(sim.build(Defs.M_MINER, node, Vector2i.UP), "채굴기가 선다")
	sim.cats.clear()
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[0]
	sim.place_cat(node)
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	var dt := 1.0 / 30.0
	for step in 12:
		main._process_play(dt)
	# Home: the cat walks, she goes in.
	for step in int(40.0 / dt):
		main.player.warmth = 100.0
		main._process_play(dt)
		if sim.cats[0].state == Defs.CAT_ASLEEP:
			break
	_assert(sim.cats[0].state == Defs.CAT_ASLEEP, "고양이가 숙소에 들어가 잔다")
	main.player.position = main.shelter_doorstep()
	main.open_room()
	_assert(main.room_open and sim.indoors, "그녀도 들어간다")
	main.player.position = main.room_sleep_point()
	main.room_sleeping = true
	main.player.locked = true
	var steps := 0
	while main.state == main.State.PLAY and steps < 600:
		main._process(dt)
		steps += 1
	_assert(main.state == main.State.DAYBREAK, "밤이 간다")
	steps = 0
	while main.state == main.State.DAYBREAK and steps < 900:
		main._process(dt)
		steps += 1
	_assert(main.state == main.State.PLAY and not main.player.locked, "아침이 온다")
	_assert(sim.indoors, "아침에는 방 안에서 일어난다")
	main.close_room()
	var hut: Rect2 = Grid.rect_px(sim.shelter_rect())
	var at: Vector2 = main.player.position
	_assert(not sim.indoors, "문을 나선다")
	_assert(not hut.has_point(at), "숙소 밖에 선다 (%s, 숙소 %s)" % [at, hut])
	_assert(not sim.blocks_player(sim.cell_of(at)), "설 수 있는 땅에 선다")
	var back := false
	for step in int(30.0 / dt):
		main.player.warmth = 100.0
		main._process_play(dt)
		if sim.cats[0].state == Defs.CAT_WORKING:
			back = true
			break
	_assert(back, "고양이도 나와서 제 채굴기로 돌아가 일한다")
