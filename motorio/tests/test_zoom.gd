extends SceneTree

## The two zoom keys, driven as real events.
##
## The trap this exists for: Shift changes what the key produces. Minus becomes
## underscore and equals becomes plus, so a handler written against `keycode`
## stops firing the instant Shift is held -- which is precisely when the HUD
## binding is wanted. Reading `physical_keycode` is what makes the pair work
## both ways, and nothing about that is visible in a screenshot.

var failures := 0

func _init() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY

	var step: float = Defs.UI_SCALE_STEP
	main.set_game_scale(1.0)
	main.set_ui_scale(1.0)

	# The world, on the bare keys.
	_press(main, KEY_MINUS, false)
	_check(is_equal_approx(main.game_scale, 1.0 - step),
		"- 를 누르면 게임 화면이 한 단계 작아진다: %.2f" % main.game_scale)
	_press(main, KEY_EQUAL, false)
	_press(main, KEY_EQUAL, false)
	_check(is_equal_approx(main.game_scale, 1.0 + step),
		"= 를 두 번 누르면 한 단계 커진다: %.2f" % main.game_scale)
	_check(is_equal_approx(main.ui_scale, 1.0), "그동안 UI 크기는 그대로다: %.2f" % main.ui_scale)

	# The HUD, on the same keys with Shift. The event carries the shifted
	# character in `keycode`, which is the whole point of the test.
	var before: float = main.game_scale
	_press(main, KEY_MINUS, true, KEY_UNDERSCORE)
	_check(is_equal_approx(main.ui_scale, 1.0 - step),
		"Shift+- 는 UI를 한 단계 줄인다: %.2f" % main.ui_scale)
	_press(main, KEY_EQUAL, true, KEY_PLUS)
	_press(main, KEY_EQUAL, true, KEY_PLUS)
	_check(is_equal_approx(main.ui_scale, 1.0 + step),
		"Shift+= 는 UI를 한 단계 키운다: %.2f" % main.ui_scale)
	_check(is_equal_approx(main.game_scale, before),
		"그동안 게임 화면 크기는 그대로다: %.2f" % main.game_scale)

	# The numpad pair, which does not change under Shift and so must not need to.
	main.set_game_scale(1.0)
	_press(main, KEY_KP_SUBTRACT, false)
	_check(is_equal_approx(main.game_scale, 1.0 - step),
		"숫자패드 - 도 게임 화면을 줄인다: %.2f" % main.game_scale)
	_press(main, KEY_KP_ADD, false)
	_check(is_equal_approx(main.game_scale, 1.0), "숫자패드 + 도 되돌린다: %.2f" % main.game_scale)

	# The ends of the range hold rather than wrapping or running away.
	for _step in 60:
		_press(main, KEY_MINUS, false)
	_check(is_equal_approx(main.game_scale, Defs.GAME_SCALE_MIN),
		"계속 줄이면 최소값에서 멈춘다: %.2f" % main.game_scale)
	for _step in 80:
		_press(main, KEY_EQUAL, false)
	_check(is_equal_approx(main.game_scale, Defs.GAME_SCALE_MAX),
		"계속 키우면 최대값에서 멈춘다: %.2f" % main.game_scale)

	# The camera has to follow, or the setting is a number nobody sees.
	main.set_game_scale(1.0)
	main._apply_camera_zoom()
	var at_one: float = main.camera.zoom.x
	_press(main, KEY_EQUAL, false)
	main._apply_camera_zoom()
	_check(main.camera.zoom.x > at_one,
		"카메라 줌이 실제로 따라온다: %.3f -> %.3f" % [at_one, main.camera.zoom.x])

	# And the keys must not reach the world while a modal owns the keyboard.
	main.set_game_scale(1.0)
	main.gacha_open = true
	_press(main, KEY_MINUS, false)
	_check(is_equal_approx(main.game_scale, 1.0),
		"가챠 창이 열려 있으면 줌 키가 먹지 않는다: %.2f" % main.game_scale)
	main.gacha_open = false

	print("ZOOM: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## A real key event, with the shifted character in `keycode` the way the platform
## delivers it. Passing the event to _unhandled_input rather than calling the
## handler is what makes this a test of the binding and not of one function.
func _press(main: Node2D, physical: int, shift: bool, produced: int = 0) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = produced if produced != 0 else physical
	event.shift_pressed = shift
	event.pressed = true
	main._unhandled_input(event)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	print("  FAIL: ", message)
	failures += 1
