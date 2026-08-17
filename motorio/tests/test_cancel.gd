extends SceneTree

const HudScript := preload("res://scripts/HUD.gd")

## X backs out of everything Escape backs out of.
##
## Escape was the way out of every window and X was the way out of two of them,
## which is a rule with exceptions the player has to remember -- and on a phone
## there is no Escape at all. The windows where Escape does something *else*
## keep doing it: in play it opens the settings panel, and in the opening it
## skips the whole sequence rather than cancelling one panel.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_x_closes()
	if failures == 0:
		print("CANCEL: PASS")
	else:
		print("CANCEL: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _press(main: Node2D, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	main._unhandled_input(event)

func _test_x_closes() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.debug_unlock_all()
	main.state = main.State.PLAY

	# The build list.
	main.build_menu_open = true
	_press(main, KEY_X)
	_assert(not main.build_menu_open, "X 로 건설 목록을 닫는다")

	# The map.
	main.map_open = true
	_press(main, KEY_X)
	_assert(not main.map_open, "X 로 지도를 닫는다")

	# The fire's window, which already answered to X and still must.
	main.base_menu_open = true
	_press(main, KEY_X)
	_assert(not main.base_menu_open, "X 로 기지 창을 닫는다")

	# The play log.
	main.log_open = true
	_press(main, KEY_X)
	_assert(not main.log_open, "X 로 기록을 닫는다")

	# The settings panel, and the slot list on top of it.
	main.open_settings()
	_assert(main.state == main.State.SETTINGS, "설정이 열렸다")
	main.settings_load()
	_assert(int(main.hud.slot_picker) == 2, "그 위에 슬롯 목록이 열렸다")
	_press(main, KEY_X)
	_assert(int(main.hud.slot_picker) == 0, "X 로 슬롯 목록을 닫는다")
	_assert(main.state == main.State.SETTINGS, "그리고 설정은 남아 있다")
	_press(main, KEY_X)
	_assert(main.state == main.State.PLAY, "한 번 더 누르면 설정도 닫힌다")

	# The meter is the exception, and it has to stay one. It is the only panel the
	# world keeps running behind, so X there is still 회수 -- a key that both read
	# a machine's throughput and demolished it would be the worst pair in the
	# game. Its own label says C for exactly this reason.
	main.state = main.State.PLAY
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in main.sim.ore:
		seam = cell
		break
	main.sim.build(Defs.M_MINER, seam, Vector2i.UP)
	main.player.position = main.sim.cell_centre(seam + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	_assert(main.toggle_meter(), "계기를 연다")
	_assert(HudScript.key_legend().contains("C 계기"), "안내가 C 를 말한다")

	# And the two places Escape means something else keep meaning it. X in play
	# is 회수 -- a key that both demolished a machine and opened a menu would be
	# the worst possible pair.
	_press(main, KEY_ESCAPE)
	_assert(main.state == main.State.SETTINGS,
		"플레이 중 Esc 는 여전히 설정을 연다 (취소가 아니다)")
	_press(main, KEY_ESCAPE)
	_assert(main.state == main.State.PLAY, "그리고 다시 닫는다")

	main.clear_save()
	main.free()
