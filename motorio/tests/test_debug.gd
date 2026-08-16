extends SceneTree

## Debug tooling. This exists so that "play it to the end and see how it feels"
## is a check that can actually be performed: a day is three minutes and the
## progression is measured in days, so an honest run to copper is ten minutes of
## real time.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame

	_assert(is_equal_approx(Engine.time_scale, 1.0), "the game starts at normal speed")
	_assert(main.speed_index == 0, "and the index agrees")

	# The multipliers themselves. Four is for watching, ten is for getting to the
	# end; anything higher stops being observable.
	_assert(Defs.DEBUG_SPEEDS.size() == 3, "three settings, including normal")
	_assert(is_equal_approx(Defs.DEBUG_SPEEDS[0], 1.0), "the first is normal speed")
	_assert(is_equal_approx(Defs.DEBUG_SPEEDS[1], 4.0), "then four times")
	_assert(is_equal_approx(Defs.DEBUG_SPEEDS[2], 10.0), "then ten times")

	_assert(main.cycle_debug_speed() == 1, "F2 steps to the next setting")
	_assert(is_equal_approx(Engine.time_scale, 4.0), "and the engine follows it")
	_assert(is_equal_approx(main.debug_speed(), 4.0), "the readout agrees")
	_assert(main.cycle_debug_speed() == 2, "again")
	_assert(is_equal_approx(Engine.time_scale, 10.0), "ten times")
	_assert(main.cycle_debug_speed() == 0, "and it wraps back to normal")
	_assert(is_equal_approx(Engine.time_scale, 1.0), "leaving the engine where it started")

	# Scaling through Engine.time_scale rather than the sim tick is the whole
	# point: everything that reads delta moves together. If this were applied to
	# Sim.tick alone, the player, the day clock and every animation would keep
	# running at normal rate and the balance being observed would be a fiction.
	_assert(main.get_process_delta_time() >= 0.0, "the scene is processing")
	main.cycle_debug_speed()
	var scaled: float = Engine.time_scale
	await process_frame
	_assert(is_equal_approx(Engine.time_scale, scaled), "the scale persists across frames")

	# It must never be saved. A restored game running at ten times speed would be
	# an extremely confusing bug report.
	main.save_game(false)
	var raw := ConfigFile.new()
	_assert(raw.load(main.SAVE_PATH) == OK, "the save was written")
	var blob: String = str(raw.get_value("motorio", "state", {}))
	_assert(blob.find("time_scale") < 0 and blob.find("speed_index") < 0,
		"and it carries no trace of the debug speed")

	Engine.time_scale = 1.0

	# The scenario key. This is the arrangement TESTS.md calls `real test`, and
	# the thing worth holding is the facing: on adjacent seams a miner pointed
	# east emits into its neighbour and jams, which is a legal build that
	# produces nothing, so a rig that quietly builds it would spend twelve
	# minutes proving the game is broken.
	main.debug_scenario()
	var miners: Array[Vector2i] = []
	for cell: Vector2i in main.sim.machines:
		if main.sim.machines[cell].type == Defs.M_MINER:
			miners.append(cell)
	_assert(miners.size() >= 2, "두 대가 섰다: %d" % miners.size())
	for cell: Vector2i in miners:
		_assert(main.sim.machines[cell].dir == Vector2i(0, -1),
			"출력이 위를 본다: %s" % str(main.sim.machines[cell].dir))
		_assert(main.sim.ore.has(cell), "광맥 위에 섰다: %s" % str(cell))

	# Two working, one idle, and the two not on the same machine. The third cat
	# is part of the scenario rather than a spare: it is the one that hauls what
	# the miners drop, so a rig that assigns all three tests a different game.
	var jobs: Array[Vector2i] = []
	var idle := 0
	for cat: Sim.Cat in main.sim.cats:
		if cat.has_job():
			jobs.append(cat.assigned)
		else:
			idle += 1
	_assert(jobs.size() == 2, "두 마리가 일한다: %d" % jobs.size())
	_assert(jobs.size() < 2 or jobs[0] != jobs[1], "같은 채굴기에 겹치지 않는다")
	_assert(idle >= 1, "한 마리는 놀고 있다: %d" % idle)

	# And pressing it twice is the same arrangement, because a tester who is not
	# sure whether the key registered will press it again.
	main.debug_scenario()
	var again := 0
	for cell: Vector2i in main.sim.machines:
		if main.sim.machines[cell].type == Defs.M_MINER:
			again += 1
	_assert(again == miners.size(), "두 번 눌러도 그대로다: %d" % again)

	# F7 puts a frozen cat where she is looking, which is the only part of the
	# rescue a browser harness cannot reliably arrange for itself: the world is
	# seeded per run, so "walk four east and one north" is not a route, it is a
	# guess that fails as a broken game.
	main.sim.frozen_cats.clear()
	main.sim.carried_frozen = false
	main.player.position = main.sim.cell_centre(main.sim.core_cell + Vector2i(0, 5))
	main.player.facing = Vector2i.RIGHT
	var front: Vector2i = main.player.facing_cell()
	main.debug_rescue()
	_assert(main.sim.frozen_cats.has(front),
		"F7 은 바라보는 칸에 얼어붙은 고양이를 둔다")
	_assert(main.sim.pick_up_frozen(front), "그 자리에서 바로 들 수 있다")
	main.debug_rescue()
	_assert(main.sim.frozen_cats.is_empty(),
		"이미 안고 있으면 하나 더 만들지 않는다 — 두 번 눌러도 팔은 둘뿐이다")
	main.sim.carried_frozen = false

	# F8 stages the two arrangements that are awkward to reach by walking: a belt
	# that ends in the open, and a boulder in front of her. Both of them produce
	# nothing at all when staged slightly wrong, and nothing at all is exactly
	# what a broken feature looks like -- so what the key leaves behind is pinned
	# here rather than judged by eye in a browser.
	main.debug_spill()
	_assert(main.sim.has_rock(main.player.facing_cell()), "F8 은 바위 앞에 세운다")
	var rock_cell: Vector2i = main.player.facing_cell()
	var start: Vector2i = rock_cell + Vector2i(-6, 1)
	var belts := 0
	for index in 4:
		var cell: Vector2i = start + Vector2i(index, 0)
		var machine: Sim.Machine = main.sim.machine_at(cell)
		if machine != null and machine.type == Defs.M_BELT:
			belts += 1
	_assert(belts == 4, "벨트 넉 줄을 놓는다: %d" % belts)
	var tail: Vector2i = start + Vector2i(4, 0)
	_assert(main.sim.machine_at(tail) == null, "그리고 그 앞은 비어 있다")
	# Close enough to the boulder to be on the same screen. The first version put
	# the run beside the core and her beside a boulder twelve cells away, and the
	# screenshot showed neither.
	_assert(Vector2(tail - rock_cell).length() < 4.0,
		"쏟는 자리와 바위가 한 화면에 있다: %.1f칸" % Vector2(tail - rock_cell).length())
	# Warm and lit, or both of them are white fog.
	_assert(main.sim.warm_radius >= 15.0,
		"온기가 거기까지 닿는다: %.0f칸" % main.sim.warm_radius)
	_assert(main.player.warmth > 99.0, "그리고 체온이 가득하다")
	var loaded: Sim.Machine = main.sim.machine_at(start)
	_assert(loaded != null and loaded.items.size() == 6,
		"자원 여섯 개가 실린다: %d" % (0 if loaded == null else loaded.items.size()))
	# Spaced, not stacked -- appending six at the same t makes the mover clamp
	# them into one place, and one bead is not a pile.
	var spread := 0.0
	if loaded != null and loaded.items.size() >= 2:
		spread = absf(float(loaded.items[0]["t"]) - float(loaded.items[-1]["t"]))
	_assert(spread > 0.5, "그리고 줄지어 실린다: %.2f" % spread)
	_assert(int(main.sim.stock.get(Defs.ITEM_STONE, -1)) == 0,
		"돌은 0에서 시작한다 — 이 키가 만드는 둘 다 돌이고, 500에서는 아무것도 안 보인다")
	_assert(main.holding_pickaxe(), "곡괭이가 손에 있다")
	_assert(main.sim.can_hand_mine(main.player.facing_cell()),
		"그리고 바로 앞이 칠 수 있는 것이다")
	# Twice is the same place. A tester unsure whether the key registered presses
	# it again, and a key that walks her one cell further each time turns that
	# into a hunt.
	var stood: Vector2 = main.player.position
	main.debug_spill()
	_assert(main.player.position.distance_to(stood) < 1.0,
		"두 번 눌러도 같은 자리다")

	main.clear_save()

	if failures == 0:
		print("DEBUG_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("DEBUG_TEST: FAIL - " + message)
		failures += 1
