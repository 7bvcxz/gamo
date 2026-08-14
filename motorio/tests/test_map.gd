extends SceneTree

## The map, the fog, and the rule that a window takes the keyboard.
##
## Those two arrived together and belong together: the map is the third window
## in this game, and the third window is what turned "the build list handles its
## own keys" into a rule that needed one place to live.
##
## The input half is here because of how it failed. The build list already
## consumed its key presses and marked them handled, and Grim walked anyway --
## movement is polled from the Input singleton, which never looks at what a
## handler decided. Nothing about the build list's code looked wrong, and the
## only way to see it was to open the list and press an arrow.

var failures := 0

func _init() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY

	_modal_locks_the_world(main)
	_fog(main)
	_zoom(main)
	_persistence(main)

	print("MAP: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## Every window, and the character refusing input while any of them is up.
##
## Checked through `modal_open()` and `takes_input()` rather than by pressing
## keys, because the failure was never about the keys: it was that two different
## places disagreed about whether a window was open. What has to be true is that
## one predicate covers all of them.
func _modal_locks_the_world(main: Node2D) -> void:
	var player = main.player
	_check(not main.modal_open(), "아무 창도 없으면 모달이 아니다")
	main._process(0.0)
	_check(player.takes_input(), "창이 없으면 입력을 받는다")

	# Each window on its own, so a new one cannot be added and only remembered in
	# whichever branch its author happened to read.
	var windows: Array[Callable] = [
		func() -> void: main.build_menu_open = true,
		func() -> void: main.gacha_open = true,
		func() -> void: main.map_open = true,
	]
	var names: Array[String] = ["건설 목록", "가챠", "지도"]
	for index in windows.size():
		main.build_menu_open = false
		main.gacha_open = false
		main.map_open = false
		windows[index].call()
		# Through Defs rather than a fixed "가": half of these names end in a
		# consonant and half do not, which is the exact shape of a bug this
		# repository has already shipped twice.
		var subject: String = names[index] + Defs.subject(names[index])
		_check(main.modal_open(), "%s 열리면 모달이다" % subject)
		main._process(0.0)
		_check(not player.takes_input(), "%s 열리면 입력을 받지 않는다" % subject)
	main.build_menu_open = false
	main.gacha_open = false
	main.map_open = false
	main._process(0.0)
	_check(player.takes_input(), "창을 닫으면 다시 받는다")

	# And a freeze is not a window. Closing a window must not thaw the character,
	# which is what one shared flag would have done.
	player.locked = true
	_check(not player.takes_input(), "얼어 있으면 입력을 받지 않는다")
	main.map_open = true
	main.map_open = false
	main._process(0.0)
	_check(not player.takes_input(), "창을 닫아도 잠금은 풀리지 않는다")
	player.locked = false

	# Opening one window closes the others. Two at once would both claim the
	# arrow keys, and they mean different things in each.
	main.build_menu_open = true
	main.toggle_map()
	_check(main.map_open and not main.build_menu_open, "지도를 열면 건설 목록이 닫힌다")
	main.map_open = false

## What the map is allowed to show.
func _fog(main: Node2D) -> void:
	var sim: Sim = main.sim
	sim.setup(4242)

	_check(sim.is_explored(sim.core_cell), "기지는 처음부터 보인다")
	var far: Vector2i = sim.core_cell + Vector2i(80, 80)
	_check(not sim.is_explored(far), "가보지 않은 곳은 가려져 있다")

	# Walking there reveals it, and only within sight.
	sim.mark_explored(far, Defs.SIGHT_RADIUS)
	_check(sim.is_explored(far), "간 곳은 보인다")
	_check(sim.is_explored(far + Vector2i(Defs.SIGHT_RADIUS - 1, 0)),
		"시야 안쪽은 보인다")
	_check(not sim.is_explored(far + Vector2i(Defs.SIGHT_RADIUS * 3, 0)),
		"시야 밖은 여전히 가려져 있다")

	# Round, not square: the fog says how far you can see and sight is not a box.
	var diagonal: int = int(float(Defs.SIGHT_RADIUS) * 0.9)
	_check(not sim.is_explored(far + Vector2i(diagonal, diagonal)),
		"대각선 모서리는 반경 밖이라 가려진다")

	# Negative coordinates. Integer division truncates toward zero, which folds
	# the two chunks either side of the origin into one -- so a cell just west of
	# the origin would be revealed by walking just east of it.
	_check(Sim.chunk_of(Vector2i(-1, -1)) != Sim.chunk_of(Vector2i(0, 0)),
		"원점 양쪽이 같은 칸으로 접히지 않는다")
	var west: Vector2i = sim.core_cell + Vector2i(-60, -60)
	sim.explored.clear()
	sim.mark_explored(west, 2)
	_check(sim.is_explored(west), "음수 좌표도 표시된다")
	_check(not sim.is_explored(-west), "반대편이 함께 열리지 않는다")

## The slider's range, and that it cannot leave it.
func _zoom(main: Node2D) -> void:
	main.set_map_zoom(Defs.MAP_ZOOM_MIN - 5.0)
	_check(is_equal_approx(main.map_zoom, Defs.MAP_ZOOM_MIN), "최소 아래로는 안 간다")
	main.set_map_zoom(Defs.MAP_ZOOM_MAX + 5.0)
	_check(is_equal_approx(main.map_zoom, Defs.MAP_ZOOM_MAX), "최대 위로는 안 간다")
	main.set_map_zoom(1.0)
	main._map_key(_key(KEY_RIGHT))
	_check(main.map_zoom > 1.0, "오른쪽이 확대다: %f" % main.map_zoom)
	main._map_key(_key(KEY_LEFT))
	_check(is_equal_approx(main.map_zoom, 1.0), "왼쪽이 축소다: %f" % main.map_zoom)
	main.map_open = true
	main._map_key(_key(KEY_ESCAPE))
	_check(not main.map_open, "Esc 로 닫힌다")

## The fog survives a save, and a save written before the map existed loads.
func _persistence(main: Node2D) -> void:
	var sim: Sim = main.sim
	sim.setup(4242)
	var walked: Vector2i = sim.core_cell + Vector2i(40, -25)
	sim.mark_explored(walked, Defs.SIGHT_RADIUS)
	var saved: Dictionary = sim.to_save()

	var fresh := Sim.new()
	fresh.setup(4242)
	_check(not fresh.is_explored(walked), "새 세계는 그곳을 모른다")
	fresh.from_save(saved)
	_check(fresh.is_explored(walked), "저장하면 탐사 기록이 남는다")
	_check(fresh.is_explored(sim.core_cell), "기지도 남는다")

	# An old save has no such key at all. It has to load rather than be refused:
	# adding this without moving SAVE_SCHEMA is the whole reason nobody's run was
	# thrown away, and that only works if a missing key is a valid one.
	var old_shape: Dictionary = saved.duplicate(true)
	old_shape.erase("explored")
	var older := Sim.new()
	older.setup(4242)
	older.from_save(old_shape)
	_check(not older.is_explored(walked), "옛 저장은 탐사 기록이 없다")
	_check(older.heat == int(saved.get("heat", -1)), "옛 저장의 나머지는 그대로 불러온다")

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	print("  FAIL: ", message)
	failures += 1
