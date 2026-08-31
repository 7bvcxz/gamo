extends SceneTree

## The throughput panel. A rated figure on its own is not enough to plan with --
## it says what a machine could do, not what it is doing -- so the panel pairs it
## with a measurement, and the gap between them is what points at the bottleneck.
##
## The measurement is the part that can be wrong without anyone noticing, so most
## of this file drives real machine ticks and checks the number that comes out
## against the rate the design promises.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	# A sibling test leaves a save behind and Main loads it on _ready, so a world
	# this test expects to be empty would arrive with someone else's factory.
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim = main.sim
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	sim.unlocked[Defs.M_MINER] = true
	sim.note_resource_seen(Defs.ITEM_COPPER)
	# Both of the generator's materials, or there is nowhere to put one below.
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500

	# --- The key ---------------------------------------------------------------
	# C is the mine key. Facing nothing it has to stay the mine key, or the pad
	# button and the keyboard both stop digging.
	main.player.position = sim.cell_centre(sim.core_cell + Vector2i(6, 6))
	main.player.facing = Vector2i.UP
	_assert(sim.machine_at(main.player.facing_cell()) == null, "facing an empty tile")
	_assert(not main.toggle_meter(), "C in front of nothing is not spent on the panel")
	_assert(main.meter_cell == Vector2i(9999, 9999), "and no panel opened")

	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) == Defs.ITEM_HEATSTONE and not sim.is_structure(cell + Vector2i(0, 1)):
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "the map has a seam approachable from the south")
	main.player.position = sim.cell_centre(seam + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	main.selected_index = 0
	# With the pickaxe in hand Z is a swing, not a build. The slot has to be set
	# before pressing it or this builds nothing and every measurement below is a
	# measurement of a machine that is not there.
	main.tool_index = main.TOOL_BUILD_GUN
	main._primary_action()
	var miner = sim.machine_at(seam)
	_assert(miner != null and miner.type == Defs.M_MINER, "a miner is standing on the seam")
	# Seams come in clusters, so the tile a freshly built miner faces is often more
	# seam -- and a miner with nowhere to put its output stalls on its first cycle.
	# Left as it was, every measurement below would have been a measurement of a
	# machine that never ran, and would have agreed with itself perfectly.
	for heading: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var ahead: Vector2i = seam + heading
		if not sim.ore.has(ahead) and not sim.machines.has(ahead) \
				and not sim.ground.has(ahead) and not sim.is_structure(ahead):
			miner.dir = heading
			break
	_assert(not sim.ore.has(seam + miner.dir), "the miner has somewhere to put its output")

	_assert(main.toggle_meter(), "C in front of a machine opens the panel")
	_assert(main.meter_cell == seam, "pinned to the machine that was faced")
	# Pinned, not following: the player has to be able to walk away and still be
	# reading the machine they opened.
	main.player.position = sim.cell_centre(seam + Vector2i(4, 4))
	main._process(0.0)
	_assert(main.meter_cell == seam, "walking away does not move the panel to another machine")
	# The world draws a bracket around whichever machine the card is reporting on.
	# The card is on the far side of the screen from the machine, so without the
	# bracket a reading is easy to attribute to the wrong one.
	_assert(main.machine_layer.meter_cell == seam,
		"the world layer is told which machine to bracket")
	_assert(main.toggle_meter(), "C again closes it")
	_assert(main.meter_cell == Vector2i(9999, 9999), "and nothing is pinned")
	main._process(0.0)
	_assert(main.machine_layer.meter_cell == Vector2i(9999, 9999),
		"and the bracket goes away with the card")

	main.player.position = sim.cell_centre(seam + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	main.toggle_meter()

	# --- An idle machine reads zero, and says why ------------------------------
	miner.operated = false
	sim.tick(1.0)
	_assert(is_equal_approx(sim.meter_rate(miner, Defs.ITEM_HEATSTONE, true), 0.0),
		"a miner with nobody on it measures nothing")
	_assert(sim.meter_status(miner).find("일손 없음") >= 0,
		"and the panel blames the missing worker: '%s'" % sim.meter_status(miner))
	# The rated figure is unaffected by any of that -- it is what the machine
	# promises, and that promise does not change when the machine stops.
	var rated: Dictionary = sim.design_rates(miner)
	var rated_out: float = float(rated["out"].get(Defs.ITEM_HEATSTONE, 0.0))
	_assert(rated_out > 0.0, "the miner still states a rated output while idle")
	_assert(is_equal_approx(rated_out, Defs.per_minute(sim.seam_period(seam))),
		"and it is this seam's rate, purity included")

	# --- A running machine measures what it actually produced ------------------
	# Run for a whole meter window so the reading is over a full sample rather
	# than a partial one, and clear the floor each step: a miner whose output tile
	# is occupied stalls, which would make this a test of the wrong thing.
	# A worker, not just the `operated` flag: tick() recomputes the operator rate
	# from the cats and the grid every frame, so a miner with the flag forced on
	# and nobody standing at it still runs at zero.
	sim.cats.clear()
	var worker = sim.Cat.new()
	worker.assigned = seam
	sim.cats.append(worker)
	var elapsed: float = 0.0
	var produced: int = 0
	while elapsed < Defs.METER_WINDOW:
		worker.state = Defs.CAT_WORKING
		worker.hunger = 1.0
		worker.pos = sim.cell_centre(seam)
		sim.tick(0.25)
		elapsed += 0.25
		for cell: Vector2i in sim.ground.keys():
			sim.ground.erase(cell)
			produced += 1
	var measured: float = sim.meter_rate(miner, Defs.ITEM_HEATSTONE, true)
	var expected: float = float(produced) * 60.0 / elapsed
	_assert(absf(measured - expected) < 1.0,
		"the measured rate matches what was produced: %.2f vs %.2f" % [measured, expected])
	# Warm tiles run at full speed, so a miner standing in the base should be
	# reading close to its rated figure. Loose, because the window boundary can
	# land mid-cycle.
	if sim.is_warm(seam):
		_assert(absf(measured - rated_out) <= rated_out * 0.35,
			"and a warm, staffed miner reads near its rated %.1f: %.1f" % [rated_out, measured])
	_assert(sim.meter_status(miner) == "가동 중", "a fed, unblocked miner reports as running")
	print("METER: miner rated %.1f/min, measured %.1f/min over %.0fs (%d items, warm %s)"
		% [rated_out, measured, elapsed, produced, sim.is_warm(seam)])

	# --- Blocked output --------------------------------------------------------
	# Fill the tile in front and let it stall. This is the failure the panel most
	# needs to name, because from the outside a stalled miner looks like a working
	# one that is simply slow.
	# Filled to the brim, not merely occupied. A tile takes a stack now, so one
	# item in front of a miner is a pile it can keep adding to -- the stall is at
	# the top of the stack, which is where the panel has to name it.
	sim.ground[seam + miner.dir] = Defs.ITEM_HEATSTONE
	sim.ground_stack[seam + miner.dir] = Sim.GROUND_STACK_MAX
	var guard: int = 0
	while not miner.stalled and guard < 400:
		worker.state = Defs.CAT_WORKING
		worker.hunger = 1.0
		worker.pos = sim.cell_centre(seam)
		sim.tick(0.25)
		guard += 1
	_assert(miner.stalled, "the miner stalls once its output tile is taken")
	_assert(sim.meter_status(miner) == "출력 막힘", "and the panel says so")

	# --- Inputs are measured too ----------------------------------------------
	# A machine only shows the items it is rated for or has actually seen, so an
	# generator names its recipe's inputs before anything has ever reached it.
	var pad := Vector2i(9999, 9999)
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			var candidate: Vector2i = sim.core_cell + Vector2i(dx, dy)
			if sim.can_build(Defs.M_GENERATOR, candidate) == "":
				pad = candidate
				break
		if pad != Vector2i(9999, 9999):
			break
	_assert(pad != Vector2i(9999, 9999), "there is somewhere to put an generator")
	sim.build(Defs.M_GENERATOR, pad, Vector2i.RIGHT)
	var generator = sim.machine_at(pad)
	_assert(generator != null and generator.type == Defs.M_GENERATOR, "the generator is built")
	var inputs: Array[int] = sim.meter_items(generator, false)
	_test_no_follow_readout(main)
	_assert(inputs.has(Defs.ITEM_HEATSTONE), "its input side lists heat stone before any arrives")
	_assert(sim.meter_status(generator).find("연료 없음") >= 0,
		"and an empty generator reports starvation: '%s'" % sim.meter_status(generator))

	# Feed it by hand and check the input counter moves. _push_into is the single
	# place inputs are counted, so this also pins that a machine added later
	# cannot forget to count its own.
	var before: float = sim.meter_rate(generator, Defs.ITEM_HEATSTONE, false)
	for index in 6:
		sim._push_into(pad, Defs.ITEM_HEATSTONE, pad - Vector2i.RIGHT)
	# Long enough to clear the minimum window. A rate divided by a quarter of a
	# second is noise, and meter_rate deliberately reports nothing until it has
	# something worth dividing by.
	sim.tick(3.0)
	_assert(sim.meter_rate(generator, Defs.ITEM_HEATSTONE, false) > before,
		"items pushed into a machine show up on its input side")

	# --- The card fits on the screen ------------------------------------------
	# The panel is drawn over a live HUD, and the two things it must never cover
	# are the hotbar and the edge of the screen.
	main.meter_cell = pad
	for scale_value: float in [Defs.UI_SCALE_MIN, Defs.UI_SCALE_DEFAULT, Defs.UI_SCALE_MAX]:
		main.ui_scale = scale_value
		main.hud._apply_scale()
		main.hud._layout()
		var box: Rect2 = main.hud.meter_rect()
		_assert(box.size.x > 0.0, "the card has a size at UI %.2f" % scale_value)
		_assert(box.position.x >= 0.0 and box.position.x + box.size.x <= main.hud.size.x + 0.5,
			"it stays inside the screen at UI %.2f" % scale_value)
		_assert(box.position.y >= 0.0, "and below the top edge at UI %.2f" % scale_value)
		var hotbar: float = main.hud.hotbar_origin().y
		_assert(box.position.y + box.size.y <= hotbar + 0.5,
			"and clear of the hotbar at UI %.2f (%.1f vs %.1f)"
			% [scale_value, box.position.y + box.size.y, hotbar])
	main.ui_scale = Defs.UI_SCALE_DEFAULT

	# --- Demolition closes it --------------------------------------------------
	sim.machines.erase(pad)
	main._process(0.0)
	_assert(main.meter_cell == Vector2i(9999, 9999),
		"removing the machine closes the panel instead of reporting a ghost")

	# --- The income figure has to settle ---------------------------------------
	# Not "is it roughly right on average" -- it was, before. Production arrives
	# in whole items, one every five seconds at the rate two staffed miners run
	# at, and the window used to be one second: 60/min on the second an item
	# landed and 0 for the four after. The average of that is correct and the
	# reading is useless, because the player reads one frame at a time and sees
	# a number bouncing between 0.1 and 20 while nothing changes.
	var rate_sim = main.sim
	rate_sim.setup(4242)
	var arrivals: float = 0.0
	var samples: Array[float] = []
	for tick in 1800:                      # sixty seconds at thirty a second
		arrivals += 1.0 / 30.0
		if arrivals >= 5.0:                # one crystal every five seconds
			arrivals -= 5.0
			rate_sim._gain(Defs.ITEM_CRYSTAL, 1)
		rate_sim._tick_rate(1.0 / 30.0)
		if tick > 900:                     # once the window has filled
			samples.append(float(rate_sim.gain_rate.get(Defs.ITEM_CRYSTAL, 0.0)))
	var low: float = samples[0]
	var high: float = samples[0]
	for value: float in samples:
		low = minf(low, value)
		high = maxf(high, value)
	var mean: float = 0.0
	for value: float in samples:
		mean += value
	mean /= float(samples.size())
	_assert(absf(mean - 12.0) < 1.0,
		"꾸준한 12/분을 12/분이라고 읽는다: 평균 %.1f" % mean)
	# The spread is the part that matters. The player reads one frame, not an
	# average of sixty.
	_assert(high - low < 5.0,
		"그리고 널뛰지 않는다: %.1f~%.1f (폭 %.1f)" % [low, high, high - low])

	main.clear_save()
	if failures == 0:
		print("METER_TEST: PASS")
	quit(failures)


# --- Nothing follows her around ------------------------------------------------

func _test_no_follow_readout(main: Node2D) -> void:
	# The panel is opened, never volunteered. A plate used to appear over whatever
	# tile she happened to be facing -- the right numbers in the wrong place, over
	# the tile she was about to build on, on screen whenever she stood near
	# anything at all.
	var layer: Node = main.machine_layer
	_assert(not layer.has_method("_draw_focus_readout"),
		"바라보는 칸에 저절로 뜨는 판이 없다")
	# And the cell she is facing is still known, because the placement ghost and
	# the mining ring are drawn from it.
	_assert("focus_cell" in layer, "바라보는 칸 자체는 여전히 안다")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("METER_TEST: FAIL - " + message)
		failures += 1
