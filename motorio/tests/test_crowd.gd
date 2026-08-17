extends SceneTree

## Eight cats, working, eating and going home, measured every tick.
##
## The reported symptom was the gauge, the body and the shadow drifting apart
## whenever a cat crossed the map. All three are positioned from one cat, so they
## can only disagree if something in the chain depends on where the cat is -- and
## something did: the breathing phase and the walk frame were offset by
## cat.pos.x. Breathing scales the sprite, whatever hangs over the cat is placed
## from the scaled height, and the shadow is not scaled, so the gauge slid
## against the shadow at walking speed.
##
## test_animation pins that with a synthetic walk. This runs the real thing: the
## crowded scenario, real ticks, cats deciding on their own to leave a miner for
## the bowl and to head home at dusk. Those transitions are where it was seen, so
## they are what is measured -- and screenshots cannot do it, because eight cats
## in one base put a dozen shadows under any gauge you try to measure against.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	# The title, then out of the opening. Skipping the second half left the run
	# sitting in State.OPENING, where the per-frame play code does not run: the
	# cats still walked, because the sim is ticked by hand here, but nothing that
	# lives outside sim.tick happened and the crew never got hungry.
	#
	# The tutorial is finished on *this* side of the title. Taking 처음부터 builds
	# a fresh world, which is the point of it, so anything set up before the tap
	# is thrown away with the world it was set up in.
	main.touch_primary()
	main._end_cutscene()
	main.finish_tutorial()
	# The bin is built now rather than standing from the first frame, and this
	# run is supposed to contain a cat walking off to eat.
	main.sim.stock[Defs.ITEM_HEATSTONE] = 20
	main.sim.craft_food_bin()
	# And they start part-hungry, staggered. A fed cat now works twelve minutes
	# and this run is two hundred seconds, so waiting for hunger to arrive on its
	# own would be waiting for a thing the file is not about -- test_workers owns
	# the rate. Staggered so the crew does not leave for the bowl in one block.
	main.debug_crowd()
	main.process_mode = Node.PROCESS_MODE_DISABLED   # one source of ticks, not two

	var sim = main.sim
	_assert(sim.cats.size() >= 8, "고양이 8마리 이상 (%d)" % sim.cats.size())
	for index in sim.cats.size():
		sim.cats[index].hunger = 0.02 + 0.03 * float(index)
	var working: int = 0
	for cat: Sim.Cat in sim.cats:
		if cat.has_job():
			working += 1
	_assert(working >= 2, "여러 마리가 채굴기에서 일한다 (%d)" % working)

	# Measured on the real views, not on geometry helpers. A cat is a node with
	# children now, so what "coming apart" would mean is one of those children
	# moving in its parent's frame -- and that is what is watched, on the same
	# nodes the game is drawing with.
	var pool: Node2D = main.get_node("Cats")
	var clock: float = 5.0
	var base_local: Dictionary[String, Vector2] = {}
	var worst_local: float = 0.0
	var worst_height: float = 0.0
	var base_height: Dictionary[int, float] = {}
	var states_seen: Dictionary[int, bool] = {}
	var travelled: float = 0.0
	var trespass: Array[String] = []
	var blocked_seen: int = 0
	var cells: Dictionary[int, Vector2i] = {}

	var step: float = 1.0 / 30.0
	var elapsed: float = 0.0
	var last: Dictionary[int, Vector2] = {}
	while elapsed < 200.0:
		main._process(step)
		# The pool has to be ticked too. Disabling processing on Main stops its
		# children as well, so without this the views are never synced and the
		# check below passes because nothing ever moved -- which is not the same
		# as nothing moving that should not. The breathing assertion at the end
		# exists to catch exactly that: it fails when the views are asleep.
		pool._process(step)
		if main.state == main.State.RESULT:
			main.touch_primary()
		elapsed += step
		for index in sim.cats.size():
			var cat: Sim.Cat = sim.cats[index]
			states_seen[cat.state] = true
			if last.has(index):
				travelled += cat.pos.distance_to(last[index])
			last[index] = cat.pos
			# Entering, not standing. "Cannot pass through" is a rule about
			# crossing into a cell: a cat that has just delivered onto the core is
			# standing on one legitimately and has to be allowed to walk out
			# again. The first version of this check counted those frames and
			# reported sixteen hundred violations that were all one cat leaving.
			var here: Vector2i = sim.cell_of(cat.pos)
			var before: Vector2i = cells.get(index, here)
			cells[index] = here
			if sim.blocks_player(here):
				blocked_seen += 1
				var goal_cell: Vector2i = sim.cell_of(cat.path_goal) \
					if cat.path_goal.x < 1e19 else here
				if here != before and here != goal_cell and cat != sim.carried_cat:
					trespass.append("%.1f초 %d번 %s 진입 (상태 %d, 목표 %s)"
						% [elapsed, index, str(here), cat.state, str(goal_cell)])
			if index >= pool.get_child_count():
				continue
			var view: CatView = pool.get_child(index)
			if not view.visible:
				continue
			for part: Node2D in view.get_children():
				if part == view._tool:
					continue          # the drill moves on purpose
				var key: String = "%d:%d" % [index, part.get_index()]
				if not base_local.has(key):
					base_local[key] = part.position
				worst_local = maxf(worst_local, part.position.distance_to(base_local[key]))
			var height: float = view._body.scale.y
			if not base_height.has(index):
				base_height[index] = height
			worst_height = maxf(worst_height, absf(height - base_height[index]))

	# --- The rule, on every cat, on every tick ---------------------------------
	# A cat may stand on the structure it is going to -- it works on its miner,
	# eats at the bin, sleeps in the hut, delivers onto the core -- and may not
	# stand on any other. Checked here rather than in the mover because a check
	# inside the thing being checked proves only that the code agrees with
	# itself, and because "every case of cat movement" is a claim about the whole
	# run rather than about one function.
	_assert(trespass.is_empty(), "지나갈 수 없는 곳을 밟은 고양이가 없다. %d건: %s"
		% [trespass.size(), "; ".join(trespass.slice(0, 5))])
	_assert(blocked_seen > 0,
		"막힌 칸 옆을 지나는 상황이 실제로 있었다 (%d틱)" % blocked_seen)

	# The run has to have actually contained the thing being tested.
	_assert(travelled > 2000.0, "고양이들이 실제로 돌아다녔다 (%.0fpx)" % travelled)
	_assert(states_seen.has(Defs.CAT_TO_FOOD) or states_seen.has(Defs.CAT_EATING),
		"밥을 먹으러 가는 구간이 포함됐다")
	_assert(states_seen.has(Defs.CAT_TO_SHELTER) or states_seen.has(Defs.CAT_ASLEEP),
		"귀가하는 구간이 포함됐다")

	_assert(worst_local < 0.01,
		"고양이의 어떤 부분도 부모 안에서 움직이지 않았다 (%.4fpx)" % worst_local)
	# Breathing is the one thing that changes, and it changes the body alone.
	_assert(worst_height > 0.0001, "몸은 여전히 호흡한다 (%.5f)" % worst_height)

	print("CROWD: 고양이 %d마리, %.0f초, 이동 %.0fpx, 상태 %d종"
		% [sim.cats.size(), elapsed, travelled, states_seen.size()])
	main.clear_save()
	if failures == 0:
		print("CROWD_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("  FAIL: ", message)
		failures += 1
