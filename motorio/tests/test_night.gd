extends SceneTree

## The night sequence: the workforce walks home, the hut lights up with everyone's
## shadow on the wall, and five seconds later it is morning and they walk back out
## to the posts they had.
##
## The risk in a cinematic is that it stops being a cinematic and becomes a hang.
## Every phase here advances on a timer as well as on its condition, and most of
## this file is about proving that -- including the case the timers exist for, a
## cat that can never reach the hut.

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
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim = main.sim

	# Three cats, scattered and working, so there is something to call home.
	sim.cats.clear()
	for index in 3:
		var cat = sim.Cat.new()
		cat.pos = sim.cell_centre(sim.core_cell + Vector2i(4 + index, 5))
		cat.state = Defs.CAT_IDLE
		sim.cats.append(cat)
	var far = sim.cats[2]

	# --- Nightfall -------------------------------------------------------------
	main.time_left = 1.0
	main._sleep()
	_assert(main.state == main.State.NIGHTFALL, "sleeping starts the sequence")
	_assert(main.night_phase == main.Phase.GATHER, "which opens by calling everyone home")
	for cat in sim.cats:
		_assert(cat.state == Defs.CAT_TO_SHELTER, "every cat is walking home")
	_assert(not sim.cats_all_home(), "and none of them is there yet")
	# They walk. The world is not asleep during this: the cats have to cross the
	# ground they were working on, which is what makes it read as going home
	# rather than as a fade.
	var before: float = far.pos.distance_to(sim.cell_centre(sim.shelter_cell))
	main._process(0.4)
	_assert(far.pos.distance_to(sim.cell_centre(sim.shelter_cell)) < before,
		"and they get closer to the hut as time passes")

	# The factory stops because its workers left, not because anything switched
	# it off. This is the one consequence of nightfall the player can see in the
	# machines themselves.
	for cell: Vector2i in sim.machines:
		if sim.machines[cell].type == Defs.M_MINER:
			_assert(not sim.machines[cell].operated,
				"a miner whose cat has walked out is no longer being worked")

	_assert(_settle(main, main.State.RESULT), "the sequence reaches the day summary")
	_assert(sim.cats_all_home(), "with everybody indoors")
	for cat in sim.cats:
		_assert(cat.state == Defs.CAT_ASLEEP, "and asleep rather than milling about outside")
	_assert(main.indoors(), "the player is inside too, not standing in the snow")
	_assert(main.shelter_glow() > 0.0, "so the hut is lit from within")
	_assert(main.night_level() >= 0.99,
		"and the sky is still night even though the clock has run out")

	# --- Daybreak --------------------------------------------------------------
	main._begin_next_day()
	_assert(main.state == main.State.DAYBREAK, "the summary hands over to the morning")
	_assert(main.player.locked, "which holds the player until the sun is up")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS), "the clock is already full")
	# Five minutes as of 1.0.2. Dusk and night are counted back from the end, so
	# they have to fit inside it with daylight left in front of them -- and the
	# order matters too, because night starting before dusk would mean the lamps
	# come on into a bright sky.
	_assert(is_equal_approx(Defs.DAY_SECONDS, 300.0), "a day is five minutes")
	_assert(Defs.DUSK_SECONDS < Defs.DAY_SECONDS * 0.5,
		"dusk is the tail of the day, not half of it")
	_assert(Defs.NIGHT_SECONDS < Defs.DUSK_SECONDS, "night falls after dusk begins")
	_assert(main.night_level() >= 0.99,
		"but the sky is still dark -- the clock cannot be what decides that")

	# Five seconds of sunrise, and it has to actually be gradual: a cut would not
	# need a timer at all.
	main._process(Defs.DAWN_SECONDS * 0.5)
	var halfway: float = main.night_level()
	_assert(halfway > 0.2 and halfway < 0.8,
		"halfway through the dawn the sky is halfway lit: %.2f" % halfway)
	_assert(main.indoors(), "and everyone is still inside while it happens")

	# The door opens on the frame the phase turns, not the frame after. Visibility
	# used to be decided before the state machine ran, so on the step from DAWN to
	# SPILL she was still being hidden by a phase that had just ended -- the door
	# opened on an empty doorstep for one frame, and a playtest screenshot landed
	# on exactly that frame.
	var stepped_into_spill := false
	for _frame in 200:
		main._process(0.05)
		if main.night_phase == main.Phase.SPILL and main.state == main.State.DAYBREAK:
			stepped_into_spill = true
			_assert(not main.indoors(), "the spill is outdoors by definition")
			_assert(main.player.visible,
				"and she is drawn on the very frame the door opens")
			break
	_assert(stepped_into_spill, "the sequence reaches the spill")

	_assert(_settle(main, main.State.PLAY), "the morning ends in play")
	_assert(is_zero_approx(main.night_level()), "fully lit")
	_assert(not main.player.locked, "and the player has control")
	_assert(main.night_override < 0.0,
		"with the sky handed back to the clock rather than pinned")
	_assert(main.player.position.distance_to(main.shelter_doorstep()) < 1.0,
		"everyone comes out of the same door")
	for cat in sim.cats:
		_assert(cat.state != Defs.CAT_ASLEEP, "no cat is left inside")
		_assert(cat.pos.distance_to(main.shelter_doorstep()) < 40.0,
			"and they all start on the doorstep")

	# --- Assignments survive the night -----------------------------------------
	# The point of morning is that the factory the player arranged is still
	# arranged. A cat that had a post walks back to it; one that did not goes
	# looking for work.
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		seam = cell
		break
	sim.stock[Defs.ITEM_CRYSTAL] = 100
	sim.stock[Defs.ITEM_HEATSTONE] = 100
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.build(Defs.M_MINER, seam, Vector2i.RIGHT)
	_assert(sim.machine_at(seam) != null, "there is a miner to be assigned to")
	sim.cats[0].assigned = seam
	sim.cats[0].state = Defs.CAT_WORKING
	sim.cats[0].pos = sim.cell_centre(seam)

	main._sleep()
	_assert(_settle(main, main.State.RESULT), "a second night runs through")
	main._begin_next_day()
	_assert(_settle(main, main.State.PLAY), "and a second morning")
	_assert(sim.cats[0].assigned == seam, "the assigned cat kept its post overnight")
	_assert(sim.cats[0].state == Defs.CAT_TO_MINER, "and is walking back to it")
	_assert(sim.cats[1].state != Defs.CAT_TO_MINER, "an unassigned cat has nowhere to walk back to")

	# --- The sequence cannot hang ----------------------------------------------
	# The reason every phase has a timeout: a cat that can never arrive. Pin it
	# far outside the world and refuse to let it move, which is the shape of the
	# bug -- boxed in by a factory built around it -- without needing to build one.
	sim.cats[1].pos = Vector2(90000.0, 90000.0)
	main.state = main.State.PLAY
	main._sleep()
	var stuck: int = 0
	while main.state != main.State.RESULT and stuck < 1200:
		sim.cats[1].pos = Vector2(90000.0, 90000.0)   # never gets any closer
		main._process(0.05)
		stuck += 1
	_assert(main.state == main.State.RESULT,
		"a cat that can never reach the hut does not hold the night open")
	_assert(float(stuck) * 0.05 <= Defs.NIGHT_GATHER_MAX + Defs.NIGHT_GLOW_SECONDS + 1.0,
		"and the door closes on schedule rather than eventually: %.1fs" % (float(stuck) * 0.05))
	_assert(sim.cats_all_home(), "the straggler is indoors regardless")

	main.clear_save()
	if failures == 0:
		print("NIGHT_TEST: PASS")
	quit(failures)

## The sequence advances on _process, so a test cannot skip past it by calling
## the transition directly -- and must not be able to, since the whole point of
## the phase timers is that the sequence always terminates on its own.
func _settle(main: Node2D, want: int) -> bool:
	for step in 600:
		if main.state == want:
			return true
		main._process(0.05)
	return main.state == want

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("NIGHT_TEST: FAIL - " + message)
		failures += 1
