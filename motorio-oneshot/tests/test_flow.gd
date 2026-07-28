extends SceneTree

## Exercises the state machine of the real Main scene: title, play, pause,
## end-of-run and restart. Running a full five-minute day per check is not
## practical, so the clock is advanced directly.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame

	_assert(main.state == main.State.TITLE, "the game opens on the title screen")
	_assert(main.hud.get("main") == main, "the HUD is wired to the orchestrator")
	_assert(main.sim.machine_at(main.sim.core_cell) != null, "the core exists at run start")

	# Any key starts the run.
	_press(main, KEY_SPACE)
	_assert(main.state == main.State.PLAY, "any key leaves the title screen")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS), "the run starts with a full day")

	# Pause and resume.
	_press(main, KEY_ESCAPE)
	_assert(main.state == main.State.PAUSED, "Esc pauses")
	var frozen: float = main.time_left
	main._process(0.5)
	_assert(is_equal_approx(main.time_left, frozen), "the clock stops while paused")
	_press(main, KEY_ESCAPE)
	_assert(main.state == main.State.PLAY, "Esc resumes")
	main._process(0.25)
	_assert(main.time_left < frozen, "the clock runs again after resuming")

	# Build selection and rotation are reflected in the preview.
	_press(main, KEY_2)
	_assert(main.selected_type() == Defs.M_BELT, "number keys pick a machine")
	var before_dir: Vector2i = main.build_dir
	_press(main, KEY_R)
	_assert(main.build_dir != before_dir, "R rotates the build direction")

	# End of run.
	main.sim.total_heat = 140
	main.time_left = 0.05
	main._process(0.2)
	_assert(main.state == main.State.RESULT, "the run ends when the clock reaches zero")
	_assert(main.best_heat == 140, "the session best records the finished run")
	_assert(main.player.locked, "the player is locked once the run is over")

	# Restart.
	_press(main, KEY_ENTER)
	_assert(main.state == main.State.PLAY, "Enter starts a fresh run")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS), "the new run has a full clock")
	_assert(main.sim.total_heat == 0 and main.sim.heat == Defs.START_HEAT, "the economy resets")
	_assert(not main.player.locked, "the player can move again")
	_assert(main.best_heat == 140, "the session best survives a restart")

	# A second, worse run must not lower the recorded best.
	main.sim.total_heat = 20
	main.time_left = 0.05
	main._process(0.2)
	_assert(main.best_heat == 140, "a worse run does not overwrite the best score")

	if failures == 0:
		print("FLOW_TEST: PASS")
	quit(failures)

func _press(main: Node2D, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	main._unhandled_input(event)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FLOW_TEST: FAIL - " + message)
		failures += 1
