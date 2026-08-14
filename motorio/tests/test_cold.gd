extends SceneTree

## Cold has to be a slope the player feels early, and losing consciousness has
## to leave a window to run for the shelter rather than ending instantly.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	# Main loads any save it finds on _ready, and sibling tests leave them behind.
	# Absolute day numbers and a clean factory both depend on starting fresh.
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY

	# Movement degrades continuously, not only at zero.
	var speeds: Array[float] = []
	for warmth: float in [100.0, 80.0, 50.0, 20.0, 0.0]:
		speeds.append(lerpf(Defs.COLD_SPEED_FLOOR, 1.0, clampf(warmth / 100.0, 0.0, 1.0)))
	for index in range(1, speeds.size()):
		_assert(speeds[index] < speeds[index - 1], "warmth %d moves slower than the step above" % index)
	_assert(is_equal_approx(speeds[0], 1.0), "full warmth means full speed")
	_assert(speeds[4] <= 0.11, "zero warmth is roughly a ninety percent slowdown")

	# The blackout only runs after the fall, and it must actually reach full dark
	# before the day is handed over.
	_assert(main.blackout <= 0.0, "the screen is clear while the player is upright")

	# Three frost stages, and they must be ordered.
	_assert(Defs.FROST_STAGES.size() == 3, "there are three frost stages")
	for index in range(1, 3):
		_assert(Defs.FROST_STAGES[index] < Defs.FROST_STAGES[index - 1], "frost stages descend")

	# Zero warmth grants a grace period instead of an immediate blackout.
	main.player.warmth = 0.0
	main.collapse_timer = -1.0
	main.player.collapse = 0.0
	main._begin_rescue()
	_assert(is_equal_approx(main.collapse_timer, Defs.COLLAPSE_GRACE), "hitting zero starts the grace timer")
	_assert(not main.player.locked, "the player can still run during the grace period")

	# And it has to name the place that actually saves you. This is the daytime
	# path -- _update_warmth calls it only when it is not night -- and what
	# cancels the collapse is warmth above zero, which the whole warm radius
	# restores. It said "숙소로" while the objective card, on screen at the same
	# instant, said "온기 반경 안으로": the two most urgent lines in the game
	# pointing at different places, at the one moment there is no time to read
	# twice.
	_assert(String(main.message).find("숙소") < 0,
		"낮의 동결 경고가 숙소를 가리키지 않는다: '%s'" % main.message)
	_assert(String(main.message).find("온기 반경") >= 0,
		"온기 반경을 가리킨다: '%s'" % main.message)
	_assert(String(main.objective()).find("온기 반경") >= 0,
		"목표 카드도 같은 곳을 가리킨다: '%s'" % main.objective())

	# Reaching warmth again inside the window cancels the collapse.
	main.player.warmth = 30.0
	main._update_collapse(0.5)
	_assert(main.collapse_timer < 0.0, "getting warm in time cancels the collapse")
	_assert(not main.player.locked, "and control is never taken away")

	# Staying cold runs the timer out, then plays the fall, then ends the day.
	# Stepped at frame-sized deltas so the intermediate states are observable,
	# which is also how the game actually runs it.
	main.player.warmth = 0.0
	main._begin_rescue()
	var grace_steps := 0
	while main.collapse_timer > 0.0 and grace_steps < 200:
		main._update_collapse(0.1)
		grace_steps += 1
	_assert(grace_steps >= int(Defs.COLLAPSE_GRACE / 0.1) - 1,
		"the player stays upright for the whole grace period")
	_assert(main.player.locked, "the fall takes control")
	_assert(main.player.collapse > 0.0 and main.player.collapse < 1.0,
		"the collapse animation is midway rather than instant")
	for step in 60:
		if main.state == main.State.RESULT:
			break
		main._update_collapse(0.1)
	_assert(main.state == main.State.RESULT, "collapsing ends the day")
	_assert(main.blackout >= 1.0, "the world had gone fully dark before the day ended")
	_assert(main.rescued_tonight, "the summary records that the player was carried in")

	# Morning restores an upright, warm player at the shelter. It is a five-second
	# sequence -- the sun comes up, then everyone walks out of the hut -- so
	# control comes back at the end of it rather than the instant it starts.
	main._begin_next_day()
	_assert(main.state == main.State.DAYBREAK, "the morning opens with the daybreak sequence")
	_assert(main.player.locked, "and holds the player until the sun is actually up")
	var morning_steps := 0
	while main.state != main.State.PLAY and morning_steps < 500:
		main._process(0.05)
		morning_steps += 1
	_assert(main.state == main.State.PLAY, "which always terminates and hands control back")
	_assert(is_equal_approx(main.player.warmth, 100.0), "the player wakes warm")
	_assert(is_zero_approx(main.player.collapse) and not main.player.locked, "the player wakes upright")
	_assert(is_zero_approx(main.blackout), "and the screen is clear again")
	_assert(main.player.position.distance_to(main.shelter_doorstep()) < 1.0, "the player wakes at the shelter door")
	_assert(not main.sim.blocks_player(main.player.cell()),
		"and never inside the hut itself")
	_assert(main.shelter_nearby(), "close enough to the door to sleep again")

	# --- The real per-frame path ---------------------------------------------
	# Everything above drives _update_collapse directly, which is why it never
	# caught this: _update_warmth runs the collapse *and then* re-checks warmth,
	# and the re-check used to re-arm the grace timer because it had gone
	# negative. The player fell for one frame every five seconds, forever.
	main._begin_next_day()
	main.state = main.State.PLAY
	main.player.locked = false
	main.player.collapse = 0.0
	main.collapse_timer = -1.0
	main.blackout = 0.0
	main.rescued_tonight = false
	# Far outside the warm radius, in daylight, with no warmth left.
	main.player.position = main.sim.cell_centre(main.sim.core_cell + Vector2i(60, 0))
	main.player.warmth = 0.0
	main.time_left = Defs.DAY_SECONDS

	var rearmed := 0
	var elapsed := 0.0
	var last_timer: float = main.collapse_timer
	while elapsed < 60.0 and main.state == main.State.PLAY:
		var falling_before: bool = main.player.collapse > 0.0
		main._update_warmth(0.1)
		elapsed += 0.1
		# A re-arm is the grace timer jumping back to a positive value while the
		# player is already going down. The first arm and the reset at the end of
		# the collapse are both legitimate and must not be counted.
		if falling_before and main.collapse_timer > 0.0 and main.collapse_timer > last_timer:
			rearmed += 1
		last_timer = main.collapse_timer
	_assert(rearmed == 0, "the grace timer is never re-armed once the fall begins (%d times)" % rearmed)
	_assert(main.state == main.State.RESULT,
		"freezing outside actually ends the day instead of looping (%.1fs)" % elapsed)
	_assert(elapsed < Defs.COLLAPSE_GRACE + Defs.COLLAPSE_FALL + Defs.BLACKOUT_SECONDS + 2.0,
		"and it takes about grace + fall + blackout, not longer (%.1fs)" % elapsed)

	main._begin_next_day()
	_assert(main.player.position.distance_to(main.shelter_doorstep()) < 1.0,
		"the player wakes at the shelter door after freezing")
	_assert(not main.sim.blocks_player(main.player.cell()), "and not inside the hut")

	if failures == 0:
		print("COLD_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("COLD_TEST: FAIL - " + message)
		failures += 1
