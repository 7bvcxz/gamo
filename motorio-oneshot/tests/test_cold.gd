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

	# Morning restores an upright, warm player at the shelter.
	main._begin_next_day()
	_assert(is_equal_approx(main.player.warmth, 100.0), "the player wakes warm")
	_assert(is_zero_approx(main.player.collapse) and not main.player.locked, "the player wakes upright")
	_assert(is_zero_approx(main.blackout), "and the screen is clear again")
	_assert(main.player.position.distance_to(main.shelter_position()) < 1.0, "the player wakes at the shelter")

	if failures == 0:
		print("COLD_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("COLD_TEST: FAIL - " + message)
		failures += 1
