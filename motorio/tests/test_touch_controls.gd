extends SceneTree

var failures := 0

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

	_assert(controls.get_button_count() == 3, "RUN, Z, and X buttons exist without MODE")
	_assert(controls._is_top_tutorial_control(Vector2(controls.size.x * 0.5, 31.0)), "top tutorial buttons are excluded from joystick capture")
	_assert(not controls._is_top_tutorial_control(Vector2(controls.size.x * 0.5, 90.0)), "regular play area remains available to touch controls")
	var tutorial_next_touch := InputEventScreenTouch.new()
	tutorial_next_touch.index = 20
	tutorial_next_touch.position = Vector2(controls.size.x * 0.5 + 80.0, 31.0)
	tutorial_next_touch.pressed = true
	controls._input(tutorial_next_touch)
	_assert(int(main.get("tutorial_step")) == 1 and controls.joystick_touch_id == -1, "top-right touch directly advances tutorial without starting joystick")
	tutorial_next_touch.pressed = false
	controls._input(tutorial_next_touch)
	var tutorial_previous_touch := InputEventScreenTouch.new()
	tutorial_previous_touch.index = 21
	tutorial_previous_touch.position = Vector2(controls.size.x * 0.5 - 80.0, 31.0)
	tutorial_previous_touch.pressed = true
	controls._input(tutorial_previous_touch)
	_assert(int(main.get("tutorial_step")) == 0, "top-left touch directly rewinds tutorial")
	tutorial_previous_touch.pressed = false
	controls._input(tutorial_previous_touch)
	controls.last_touch_input_msec = -10000
	_assert(controls.joystick_center.x > controls.size.x * 0.5, "movement wheel is on the right")
	_assert(controls.button_centers[0].x < controls.size.x * 0.5, "action buttons are on the left")
	var diagonal: Vector2 = controls.snap_to_eight_directions(Vector2(0.8, 0.45))
	_assert(abs(diagonal.normalized().x - 0.7071) < 0.01 and abs(diagonal.normalized().y - 0.7071) < 0.01, "mobile movement snaps diagonal input to one of eight directions")
	_assert(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "game expands to fill the device aspect ratio")
	controls.size = Vector2(900, 1200)
	controls._update_layout()
	_assert(controls.joystick_center == Vector2(810, 1108), "joystick follows a tall screen bottom-right")
	_assert(controls.button_centers[0].y == 1124.0, "buttons follow a tall screen bottom-left")
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = Vector2(300, 300)
	controls._input(mouse_motion)
	_assert(not controls.visible, "mouse input hides mobile controls")
	var keyboard_press := InputEventKey.new()
	keyboard_press.keycode = KEY_RIGHT
	keyboard_press.pressed = true
	controls.set_controls_visible(true)
	controls._input(keyboard_press)
	_assert(not controls.visible, "keyboard input hides mobile controls")

	var move_press := InputEventScreenTouch.new()
	move_press.index = 1
	move_press.position = controls.joystick_center + Vector2(controls.JOYSTICK_RADIUS, 0)
	move_press.pressed = true
	controls._input(move_press)
	_assert(controls.visible, "touch input restores mobile controls")
	var move_direction: Vector2 = player.get("touch_direction")
	_assert(move_direction.x > 0.95, "wheel produces right movement")
	controls._input(mouse_motion)
	_assert(controls.visible, "synthetic mouse input after touch does not hide controls")
	_assert((player.get("touch_direction") as Vector2).x > 0.95, "synthetic mouse input does not reset joystick movement")
	controls._end_touch(1)
	_assert(player.get("touch_direction") == Vector2.ZERO, "wheel release stops movement")
	main.set("base_menu_open", true)
	player.set("controls_locked", true)
	main.set("fabricator_selection", 5)
	controls.menu_navigation_axis = 0
	controls._update_joystick(controls.joystick_center + Vector2.UP * controls.JOYSTICK_RADIUS)
	_assert(int(main.get("fabricator_selection")) == 4 and player.get("touch_direction") == Vector2.ZERO, "joystick up selects the previous fabricator item without moving")
	controls._update_joystick(controls.joystick_center)
	controls._update_joystick(controls.joystick_center + Vector2.DOWN * controls.JOYSTICK_RADIUS)
	_assert(int(main.get("fabricator_selection")) == 5, "joystick down selects the next fabricator item")
	main.call("_close_base_menu")

	var run_press := InputEventScreenTouch.new()
	run_press.index = 2
	run_press.position = controls.button_centers[0]
	run_press.pressed = true
	controls._input(run_press)
	_assert(bool(player.get("touch_sprint")), "RUN button enables sprint")
	controls._end_touch(2)
	_assert(not bool(player.get("touch_sprint")), "RUN release disables sprint")
	main.set("base_menu_open", true)
	player.set("controls_locked", true)
	controls._input(run_press)
	_assert(not bool(main.get("base_menu_open")), "RUN closes the fabricator menu on touch devices")
	_assert(not bool(player.get("touch_sprint")), "closing the menu does not start sprinting")
	controls._end_touch(2)

	var collect_press := InputEventScreenTouch.new()
	collect_press.index = 4
	collect_press.position = controls.button_centers[1]
	collect_press.pressed = true
	controls._input(collect_press)
	_assert(bool(main.get("collect_action_held")), "Z touch starts resource collection hold")
	controls._end_touch(4)
	_assert(not bool(main.get("collect_action_held")), "Z touch release stops resource collection hold")

	var place_press := InputEventScreenTouch.new()
	place_press.index = 3
	place_press.position = controls.button_centers[2]
	place_press.pressed = true
	controls._input(place_press)
	_assert(bool(main.get("placement_action_held")), "X touch begins placement hold")
	controls._end_touch(3)
	_assert(not bool(main.get("placement_action_held")), "X touch release ends placement hold")

	main.set("shelter_open", true)
	player.set("controls_locked", true)
	var shelter_wheel := InputEventScreenTouch.new()
	shelter_wheel.index = 7
	shelter_wheel.position = controls.joystick_center
	shelter_wheel.pressed = true
	controls._input(shelter_wheel)
	_assert(controls.joystick_touch_id == -1, "night shelter hides and disables the unnecessary movement wheel")
	var shelter_z := InputEventScreenTouch.new()
	shelter_z.index = 8
	shelter_z.position = controls.button_centers[1]
	shelter_z.pressed = true
	controls._input(shelter_z)
	_assert(not bool(main.get("shelter_open")), "the single mobile Z action sleeps until morning")
	controls._end_touch(8)

	if failures == 0:
		print("TOUCH_CONTROLS_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("TOUCH_CONTROLS_TEST: FAIL - " + message)
		failures += 1
