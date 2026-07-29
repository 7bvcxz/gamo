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

	# Mobile: a tap must be able to start the game, pick a machine and rotate it.
	# Without these the pad has no way to reach half the verbs.
	main.state = main.State.TITLE
	_assert(main.touch_anywhere_starts(), "a tap anywhere leaves the title on a phone")
	main.touch_primary()
	_assert(main.state == main.State.PLAY, "touch start actually begins the run")
	main._process(0.0)
	_assert(main.hud.hotbar_rects.size() == Defs.BUILDABLE.size(), "the HUD publishes a rect per machine slot")
	main.selected_index = 0
	_assert(main.touch_hud((main.hud.hotbar_rects[2] as Rect2).get_center()),
		"tapping a hotbar card is handled")
	_assert(main.selected_index == 2, "tapping a hotbar card selects that machine")
	var dir_before: Vector2i = main.build_dir
	_assert(main.touch_hud((main.hud.direction_rect as Rect2).get_center()),
		"tapping the direction chip is handled")
	_assert(main.build_dir != dir_before, "tapping the direction chip rotates the output")
	_assert(not main.touch_hud(Vector2(-500, -500)), "taps outside the HUD fall through to the pad")

	# Night: the warm pool alone must stop being enough, which is what sends the
	# player indoors instead of camping next to the core.
	main.sim.build(Defs.M_BELT, Vector2i(0, 2), Vector2i.UP)
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	_assert(main.is_night(), "night begins before the clock runs out")
	main.player.position = Vector2(main.sim.core_cell) * float(Defs.TILE)
	_assert(main.sim.is_warm(main.player.cell()), "the test stands the player inside the warm radius")
	main.player.warmth = 100.0
	main._update_warmth(1.0)
	_assert(main.player.warmth < 100.0, "at night even the warm radius loses body heat")

	# Standing at the shelter slows the loss but does not stop it.
	main.player.position = main.shelter_position()
	_assert(main.shelter_nearby(), "the shelter is reachable beside the core")
	var near_loss: float = main.player.warmth
	main._update_warmth(1.0)
	_assert(main.player.warmth < near_loss, "the shelter porch is still cold")
	_assert(main.sleep_available(), "Z offers sleep once night has fallen and you are home")

	main.sim.total_heat = 140
	main._sleep()
	_assert(main.state == main.State.RESULT, "sleeping ends the day")
	_assert(main.day_heat() == 140, "the summary reports what this day earned")
	_assert(main.player.locked, "the player is locked while the day summary is up")

	# Continuing must carry the world forward, not restart it: that is the whole
	# point of days accumulating.
	var radius_before: float = main.sim.warm_radius
	_press(main, KEY_ENTER)
	_assert(main.state == main.State.PLAY, "Enter begins the next morning")
	_assert(main.day_number == 2, "the day counter advances")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS), "the new day has a full clock")
	_assert(main.sim.total_heat == 140, "cumulative heat carries into the next day")
	_assert(is_equal_approx(main.sim.warm_radius, radius_before), "the warm radius carries over")
	_assert(main.sim.machine_at(Vector2i(0, 2)) != null, "the factory survives the night")
	_assert(not main.player.locked, "the player can move again in the morning")
	_assert(main.day_heat() == 0, "the daily total starts fresh each morning")

	# Daytime inside the warm radius must still recover heat, or the night rule
	# would simply be a permanent drain.
	main.player.position = Vector2(main.sim.core_cell) * float(Defs.TILE)
	main.player.warmth = 50.0
	main._update_warmth(1.0)
	_assert(main.player.warmth > 50.0, "daylight inside the warm radius restores body heat")
	_assert(not main.sleep_available(), "you cannot go to bed in the middle of the day")

	# A weaker second day must not lower the recorded best day.
	main.sim.total_heat = 160
	main.time_left = 0.05
	main._process(0.2)
	_assert(main.day_heat() == 20, "the second day counts only its own earnings")
	_assert(main.best_day_heat == 140, "a worse day does not overwrite the best day")

	# N starts a genuinely fresh game.
	_press(main, KEY_N)
	_assert(main.state == main.State.PLAY and main.day_number == 1, "N restarts at day one")
	_assert(main.sim.total_heat == 0 and main.sim.heat == Defs.START_HEAT, "a fresh game resets the economy")
	_assert(main.sim.machine_at(Vector2i(0, 2)) == null, "a fresh game clears the old factory")

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
