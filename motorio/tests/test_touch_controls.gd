extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame

	var player: Node = main.get_node("Player")
	var controls := main.get_node("UI/TouchControls") as TouchControls
	controls.set_controls_visible(true)
	await process_frame

	_assert(controls.get_button_count() == 4, "RUN, Z, X, and MODE buttons exist")
	_assert(controls.joystick_center.x > controls.size.x * 0.5, "movement wheel is on the right")
	_assert(controls.button_centers[0].x < controls.size.x * 0.5, "action buttons are on the left")

	var move_press := InputEventScreenTouch.new()
	move_press.index = 1
	move_press.position = controls.joystick_center + Vector2(controls.JOYSTICK_RADIUS, 0)
	move_press.pressed = true
	controls._input(move_press)
	var move_direction: Vector2 = player.get("touch_direction")
	_assert(move_direction.x > 0.95, "wheel produces right movement")
	controls._end_touch(1)
	_assert(player.get("touch_direction") == Vector2.ZERO, "wheel release stops movement")

	var run_press := InputEventScreenTouch.new()
	run_press.index = 2
	run_press.position = controls.button_centers[0]
	run_press.pressed = true
	controls._input(run_press)
	_assert(bool(player.get("touch_sprint")), "RUN button enables sprint")
	controls._end_touch(2)
	_assert(not bool(player.get("touch_sprint")), "RUN release disables sprint")

	var previous_mode: int = main.get("interaction_mode")
	var mode_press := InputEventScreenTouch.new()
	mode_press.index = 3
	mode_press.position = controls.button_centers[3]
	mode_press.pressed = true
	controls._input(mode_press)
	_assert(main.get("interaction_mode") != previous_mode, "MODE button toggles interaction mode")
	controls._end_touch(3)

	print("TOUCH_CONTROLS_TEST: PASS")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("TOUCH_CONTROLS_TEST: FAIL - " + message)
		quit(1)
