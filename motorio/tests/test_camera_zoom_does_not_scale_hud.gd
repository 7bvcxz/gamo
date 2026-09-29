extends SceneTree

## Zooming the world leaves the HUD alone (Factory Interaction Pass 01): across
## the whole range the HUD's scale, its size and the UI scale setting do not move;
## only the camera does.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test()
	if failures == 0:
		print("PASS test_camera_zoom_does_not_scale_hud")
	else:
		print("FAIL test_camera_zoom_does_not_scale_hud (%d)" % failures)
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
	var hud_scale: Vector2 = main.hud.scale
	var hud_size: Vector2 = main.hud.size
	var ui: float = main.ui_scale
	var zooms: Array[float] = []
	for step in 12:
		_key(main, KEY_EQUAL, true)
		_ease(main, 0.5)
		zooms.append(main.camera.zoom.x)
	for step in 24:
		_key(main, KEY_MINUS, true)
		_ease(main, 0.5)
		zooms.append(main.camera.zoom.x)
	_assert(zooms.max() > zooms.min(), "카메라는 움직였다 (%.2f..%.2f)" % [zooms.min(), zooms.max()])
	_assert(main.hud.scale == hud_scale and main.hud.size == hud_size, "HUD 의 크기와 배율은 그대로다")
	_assert(is_equal_approx(main.ui_scale, ui), "UI 크기 설정도 그대로다")
	_assert(main.hud is CanvasItem and (main.hud.get_parent() is CanvasLayer or main.hud is CanvasLayer
		or main.hud.get_canvas_layer_node() != null), "HUD 는 카메라와 다른 캔버스 층에 있다")
	_leave(main)
