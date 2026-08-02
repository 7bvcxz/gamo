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
	var blob: String = str(raw.get_value("motorio_oneshot", "state", {}))
	_assert(blob.find("time_scale") < 0 and blob.find("speed_index") < 0,
		"and it carries no trace of the debug speed")

	Engine.time_scale = 1.0
	main.clear_save()

	if failures == 0:
		print("DEBUG_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("DEBUG_TEST: FAIL - " + message)
		failures += 1
