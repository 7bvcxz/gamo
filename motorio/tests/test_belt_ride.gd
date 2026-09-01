extends SceneTree

## The floor moves.
##
## A belt carries whatever is standing on it, and the player was the one thing in
## the factory it did not touch: she could stand on a running line and the line
## pretended she was not there. Walking with it is faster, walking across it
## drifts, and standing on it is not standing still.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_drift_query()
	await _test_she_rides()
	if failures == 0:
		print("BELT_RIDE: PASS")
	else:
		print("BELT_RIDE: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- What the floor is doing --------------------------------------------------

func _test_drift_query() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.power_ever = true
	sim._check_unlocks()
	sim.stock[Defs.ITEM_COPPER] = 500
	var cell := Vector2i(14, 14)
	sim.ore.erase(cell)
	sim.mined_rocks[cell] = true
	_assert(sim.belt_drift(cell).is_zero_approx(), "빈 바닥은 아무것도 안 한다")
	_assert(sim.build(Defs.M_BELT, cell, Vector2i.RIGHT), "벨트를 놓는다")
	var drift: Vector2 = sim.belt_drift(cell)
	_assert(drift.x > 0.0 and is_zero_approx(drift.y), "벨트가 진행 방향으로 민다: %s" % str(drift))
	_assert(is_equal_approx(drift.length(), Defs.belt_carry_speed()),
		"속도는 벨트 속도에서 나온다: %.1fpx/s" % drift.length())
	# Fast enough to notice standing still, and not so fast it replaces walking.
	_assert(drift.length() > float(Defs.TILE) * 0.6,
		"가만히 서 있어도 알아챌 만큼: 초당 %.2f칸" % (drift.length() / float(Defs.TILE)))
	_assert(drift.length() < PlayerActor.SPEED,
		"걷는 것보다는 느리다: %.0f vs %.0f" % [drift.length(), PlayerActor.SPEED])
	# The core is a machine and not a belt.
	_assert(sim.belt_drift(sim.core_cell).is_zero_approx(), "다른 기계는 밀지 않는다")
	sim.free()

# --- And what it does to her --------------------------------------------------

func _test_she_rides() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim: Sim = main.sim
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.power_ever = true
	sim._check_unlocks()
	sim.stock[Defs.ITEM_COPPER] = 500

	var cell: Vector2i = sim.core_cell + Vector2i(6, 6)
	sim.ore.erase(cell)
	sim.mined_rocks[cell] = true
	_assert(sim.build(Defs.M_BELT, cell, Vector2i.RIGHT), "동쪽으로 가는 벨트를 놓는다")

	# Standing on it, hands off the keyboard.
	main.player.position = sim.cell_centre(cell)
	main.player.velocity = Vector2.ZERO
	var start: Vector2 = main.player.position
	for _step in 30:
		main.player._physics_process(1.0 / 60.0)
	var moved: Vector2 = main.player.position - start
	_assert(moved.x > 4.0, "가만히 서 있어도 실려 간다: %.1fpx" % moved.x)
	_assert(absf(moved.y) < 0.5, "옆으로는 안 밀린다: %.2fpx" % moved.y)
	# Half a second at a tile a second.
	_assert(absf(moved.x - Defs.belt_carry_speed() * 0.5) < 1.0,
		"벨트 속도만큼 정확히: %.1fpx" % moved.x)

	# Off the belt, nothing carries her.
	main.player.position = sim.cell_centre(cell + Vector2i(0, 2))
	main.player.velocity = Vector2.ZERO
	var still: Vector2 = main.player.position
	for _step in 30:
		main.player._physics_process(1.0 / 60.0)
	_assert(main.player.position.distance_to(still) < 0.01,
		"벨트 밖에서는 가만히 있는다: %.2fpx" % main.player.position.distance_to(still))

	# And it adds to walking rather than replacing it: the same key held on the
	# belt covers more ground than off it.
	main.player.position = sim.cell_centre(cell)
	main.player.velocity = Vector2(PlayerActor.SPEED, 0.0)
	var on_start: Vector2 = main.player.position
	for _step in 10:
		main.player._physics_process(1.0 / 60.0)
	var on_belt: float = main.player.position.x - on_start.x
	main.player.position = sim.cell_centre(cell + Vector2i(0, 2))
	main.player.velocity = Vector2(PlayerActor.SPEED, 0.0)
	var off_start: Vector2 = main.player.position
	for _step in 10:
		main.player._physics_process(1.0 / 60.0)
	var off_belt: float = main.player.position.x - off_start.x
	_assert(on_belt > off_belt + 3.0,
		"같은 방향으로 걸으면 더 간다: 벨트 위 %.1fpx vs 밖 %.1fpx" % [on_belt, off_belt])

	main.clear_save()
	main.free()
