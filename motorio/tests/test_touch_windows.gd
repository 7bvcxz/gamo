extends SceneTree

## Every window a phone can open, it can also use and close.
##
## The fire's window had no hit test at all. It was reachable only by keyboard --
## the cursor is the arrow keys and a phone has none -- so on a phone it opened
## and then every tap fell straight past it to the tool row underneath, and the
## pad below that re-opened it. From the outside that is the base doing nothing
## at all, which is exactly how it was reported.
##
## So this asks the same three questions of every window: does a tap on a row do
## that row, does a tap outside close it, and does the tap stop there rather than
## reaching the world.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_windows()
	if failures == 0:
		print("TOUCH_WINDOWS: PASS")
	else:
		print("TOUCH_WINDOWS: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## A tap, in viewport coordinates, the way the pad delivers one.
func _tap(main: Node2D, local: Vector2) -> bool:
	return bool(main.touch_hud(local * float(main.hud.scale.x)))

func _test_windows() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.debug_unlock_all()
	main.state = main.State.PLAY
	main.player.position = main.sim.cell_centre(main.sim.core_cell + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	var hud: Node = main.hud
	main._process(0.0)
	hud._layout()
	var away := Vector2(4.0, hud.size.y - 4.0)

	# --- The fire's window ------------------------------------------------------
	main.sim.stock[Defs.ITEM_HEATSTONE] = 40
	main._primary_action()
	_assert(main.base_menu_open, "기지 앞에서 Z 를 누르면 창이 열린다")
	main._process(0.0)
	hud._layout()
	var rows: Array[Dictionary] = main.base_rows()
	_assert(rows.size() >= 2, "줄이 여럿 있다: %d" % rows.size())
	# Every row is where it is drawn, and a tap on one is that row.
	for index in rows.size():
		var rect: Rect2 = hud.call("base_menu_row_rect", index)
		_assert(int(hud.call("base_menu_row_at", rect.get_center())) == index,
			"기지 창 %d번째 줄을 누르면 그 줄이 잡힌다" % index)
	var before: int = main.sim.total_heat
	_assert(_tap(main, (hud.call("base_menu_row_rect", 0) as Rect2).get_center()),
		"기지 창의 탭이 처리된다")
	_assert(main.sim.total_heat > before,
		"연료 줄을 누르면 실제로 들어간다: %d → %d" % [before, main.sim.total_heat])
	# And the window owns the screen: a tap outside closes it rather than picking
	# a tool out of the row underneath.
	main._primary_action()
	_assert(main.base_menu_open, "다시 연다")
	var tool_before: int = main.tool_index
	_assert(_tap(main, away), "바깥 탭도 창이 가져간다")
	_assert(not main.base_menu_open, "그리고 창이 닫힌다")
	_assert(main.tool_index == tool_before, "아래의 도구줄이 바뀌지 않는다")

	# --- The build list ---------------------------------------------------------
	main.build_menu_open = true
	main._process(0.0)
	hud._layout()
	_assert(_tap(main, (hud.call("build_menu_row_rect", 1) as Rect2).get_center()),
		"건설 목록의 탭이 처리된다")
	_assert(main.selected_index == 1, "그 줄이 장전된다")
	main.build_menu_open = true
	main._process(0.0)
	hud._layout()
	_assert(_tap(main, away) and not main.build_menu_open, "바깥 탭으로 닫힌다")

	# --- The map ----------------------------------------------------------------
	main.toggle_map()
	main._process(0.0)
	hud._layout()
	_assert(main.map_open, "지도가 열린다")
	_assert(_tap(main, away) and not main.map_open, "바깥 탭으로 닫힌다")

	# --- The play log -----------------------------------------------------------
	main.toggle_log()
	main._process(0.0)
	hud._layout()
	_assert(main.log_open, "기록이 열린다")
	_assert(_tap(main, away) and not main.log_open, "바깥 탭으로 닫힌다")

	# --- The settings panel and the slot list on top of it ----------------------
	main.open_settings()
	main._process(0.0)
	hud._layout()
	var close_row: int = hud.settings_rows().find(hud.ROW_CLOSE)
	_assert(_tap(main, (hud.settings_row_rects[close_row] as Rect2).get_center()),
		"설정 닫기 줄의 탭이 처리된다")
	_assert(main.state != main.State.SETTINGS, "그리고 닫힌다")
	main.open_settings()
	main.settings_load()
	main._process(0.0)
	hud._layout()
	_assert(int(hud.slot_picker) == 2, "슬롯 목록이 열린다")
	_assert(_tap(main, away), "목록 바깥 탭도 처리된다")
	_assert(int(hud.slot_picker) == 0, "그리고 목록이 닫힌다")
	main.close_settings()

	# --- The title menu ---------------------------------------------------------
	main.state = main.State.TITLE
	main._process(0.0)
	hud._layout()
	var menu_row: Rect2 = hud.call("title_menu_rect", 0)
	_assert(_tap(main, menu_row.get_center()), "타이틀 메뉴의 탭이 처리된다")
	_assert(main.state != main.State.TITLE, "그리고 무언가가 일어난다")

	# --- Screens where the whole display is the button --------------------------
	# The opening was missing from this list, so a tap on a phone never became a
	# `touch_primary` at all: the caption said 화면을 눌러 넘기기 and nothing
	# happened. The panels advanced on their own and the player sat through all
	# seven.
	main.state = main.State.OPENING
	_assert(main.touch_anywhere_starts(), "컷씬에서도 화면 전체가 버튼이다")
	var panel: int = main.cutscene_panel
	main.touch_primary()
	_assert(main.cutscene_panel == panel + 1 or main.state != main.State.OPENING,
		"그래서 탭이 다음 장으로 넘긴다")
	main.state = main.State.TITLE
	_assert(main.touch_anywhere_starts(), "타이틀도")
	main.state = main.State.RESULT
	_assert(main.touch_anywhere_starts(), "정산 카드도")
	# And not while playing: there the screen is the world, and a tap on it is
	# the joystick or a button rather than "confirm".
	main.state = main.State.PLAY
	_assert(not main.touch_anywhere_starts(), "플레이 중에는 아니다 — 화면이 곧 세계다")

	# --- Nothing in the corner lands on anything else ---------------------------
	# The cards on the right dodge the clock when the screen is too narrow to hold
	# both, which was right while the clock was the only thing in that corner. The
	# resource panel hangs below it and grows a row per material, so on a phone
	# the objective card dropped straight onto it.
	main.state = main.State.PLAY
	main.sim.stock[Defs.ITEM_HEATSTONE] = 12
	main.sim.stock[Defs.ITEM_COPPER] = 7
	main.sim.stock[Defs.ITEM_STONE] = 3
	for shape: Vector2 in [Vector2(960, 2077), Vector2(540, 960), Vector2(1280, 720)]:
		hud.size = shape
		main._process(0.0)
		hud._layout()
		var left: Rect2 = hud.call("resource_rect")
		var goal: Rect2 = hud.call("goal_area")
		_assert(not left.intersects(goal),
			"%.0fx%.0f 화면에서 자원 패널과 목표 카드가 겹치지 않는다 (자원 %.0f..%.0f, 목표 %.0f..%.0f)"
				% [shape.x, shape.y, left.position.y, left.position.y + left.size.y,
					goal.position.y, goal.position.y + goal.size.y])
		_assert(goal.position.y + goal.size.y < shape.y,
			"%.0fx%.0f 에서 목표 카드가 화면 안에 있다" % [shape.x, shape.y])

	main.clear_save()
	main.free()
