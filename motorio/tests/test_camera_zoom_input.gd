extends SceneTree

## Ctrl+wheel, Ctrl++ and Ctrl+- zoom the world, as real events (Factory
## Interaction Pass 01) -- including Ctrl+Shift+=, which is what Ctrl++ is on most
## keyboards and which would otherwise have gone to the HUD size. The change is
## eased: one frame after the key the camera is between the old zoom and the new
## one, and a quarter of a second later it has arrived.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test()
	if failures == 0:
		print("PASS test_camera_zoom_input")
	else:
		print("FAIL test_camera_zoom_input (%d)" % failures)
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
	var step: float = Defs.UI_SCALE_STEP
	_wheel(main, true, true)
	_assert(is_equal_approx(main.game_scale, 1.0 + step), "Ctrl+휠 위: 가까이 (%.2f)" % main.game_scale)
	_wheel(main, false, true)
	_assert(is_equal_approx(main.game_scale, 1.0), "Ctrl+휠 아래: 멀리 (%.2f)" % main.game_scale)
	_key(main, KEY_EQUAL, true)
	_assert(is_equal_approx(main.game_scale, 1.0 + step), "Ctrl+= : 가까이")
	_key(main, KEY_MINUS, true)
	_assert(is_equal_approx(main.game_scale, 1.0), "Ctrl+- : 멀리")
	var ui: float = main.ui_scale
	_key(main, KEY_EQUAL, true, true)
	_assert(is_equal_approx(main.game_scale, 1.0 + step) and is_equal_approx(main.ui_scale, ui),
		"Ctrl+Shift+= (Ctrl++) 도 세계를 키우고 UI 는 그대로다")
	# Eased: part way after one frame, there after a quarter second.
	main.set_game_scale(1.0)
	_ease(main, 0.5)
	var from: float = main.camera.zoom.x
	_key(main, KEY_EQUAL, true)
	var to: float = Defs.GAME_SCALE_DESKTOP_BASE * main.game_scale
	main._apply_camera_zoom(1.0 / 60.0)
	var mid: float = main.camera.zoom.x
	_assert(mid > from and mid < to, "한 프레임 뒤에는 가는 중이다 (%.3f < %.3f < %.3f)" % [from, mid, to])
	_ease(main, 0.4)
	_assert(is_equal_approx(main.camera.zoom.x, to), "잠시 뒤 도착한다 (%.3f)" % main.camera.zoom.x)
	_leave(main)
