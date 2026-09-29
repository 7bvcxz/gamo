extends SceneTree

## The world zoom has a near end, a far end and a default, and holds at the ends
## (Factory Interaction Pass 01): sixty steps in stop at GAME_SCALE_MAX, sixty out
## at GAME_SCALE_MIN, the desktop default sits between them, and the camera
## arrives at each end -- eased, not stuck halfway.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test()
	if failures == 0:
		print("PASS test_camera_zoom_min_max")
	else:
		print("FAIL test_camera_zoom_min_max (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _main() -> Node2D:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run(5150)
	main.finish_tutorial()
	main.state = main.State.PLAY
	# The zoom setters save the settings file, and the next test (and the
	# player) reads it: remember what was there and put it back (`_leave`).
	kept = [main.game_scale, main.ui_scale]
	main.set_game_scale(1.0)
	main.set_ui_scale(1.0)
	return main

var kept: Array = []

func _leave(main: Node2D) -> void:
	main.set_game_scale(float(kept[0]))
	main.set_ui_scale(float(kept[1]))
	main.clear_save()
	main.free()

## Frames of the camera's own update, the way the game runs them.
func _ease(main: Node2D, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		main._apply_camera_zoom(1.0 / 60.0)
		t += 1.0 / 60.0

func _key(main: Node2D, physical: int, ctrl: bool, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.pressed = true
	main._unhandled_input(event)

func _wheel(main: Node2D, up: bool, ctrl: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.ctrl_pressed = ctrl
	event.pressed = true
	event.position = Vector2(400, 300)
	main._unhandled_input(event)

func _test() -> void:
	var main: Node2D = await _main()
	_assert(Defs.GAME_SCALE_MIN < Defs.GAME_SCALE_DEFAULT_DESKTOP and Defs.GAME_SCALE_DEFAULT_DESKTOP < Defs.GAME_SCALE_MAX,
		"기본값이 가까움과 멂 사이에 있다")
	for step in 60:
		main.zoom_by(Defs.UI_SCALE_STEP, false)
	_assert(is_equal_approx(main.game_scale, Defs.GAME_SCALE_MAX), "가까이는 %.2f 에서 멈춘다" % main.game_scale)
	_ease(main, 1.0)
	_assert(is_equal_approx(main.camera.zoom.x, Defs.GAME_SCALE_DESKTOP_BASE * Defs.GAME_SCALE_MAX),
		"카메라가 그 끝까지 온다 (%.3f)" % main.camera.zoom.x)
	for step in 60:
		main.zoom_by(-Defs.UI_SCALE_STEP, false)
	_assert(is_equal_approx(main.game_scale, Defs.GAME_SCALE_MIN), "멀리는 %.2f 에서 멈춘다" % main.game_scale)
	_ease(main, 1.0)
	_assert(is_equal_approx(main.camera.zoom.x, Defs.GAME_SCALE_DESKTOP_BASE * Defs.GAME_SCALE_MIN),
		"카메라가 그 끝까지 온다 (%.3f)" % main.camera.zoom.x)
	_leave(main)
