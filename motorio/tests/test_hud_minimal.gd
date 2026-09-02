extends SceneTree

## The corner, after the minimalisation pass.
##
## Three things are asserted here and all three are absences: no clock, no
## permanent list of controls, and no centre-screen text while the fire is
## making something. Absences are the hard kind to keep -- a feature deleted by
## emptying a function leaves its constants, its flags and its call sites behind,
## and this repository has that written down twice -- so each one is checked by
## naming what must not exist rather than by looking at a picture.

var failures := 0
var main: Node2D = null

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	_run()

func _run() -> void:
	_test_no_persistent_key_guide()
	_test_status_hud_has_no_clock()
	_test_temperature_bar()
	_test_day_progress_bar()
	_test_day_number()
	_test_base_crafting_uses_world_progress()
	_test_settings_guide()
	if failures == 0:
		print("PASS test_hud_minimal")
	else:
		print("FAIL test_hud_minimal (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)

# --- test_no_persistent_key_guide / test_initial_key_guide_hidden ------------

## The legend that sat in the bottom-right for the whole run is gone, and gone
## means gone: the drawing, the string that fed it, and the call site.
func _test_no_persistent_key_guide() -> void:
	var hud: String = _source("res://scripts/HUD.gd")
	for name: String in ["key_legend", "_draw_key_legend"]:
		_assert(not hud.contains(name),
			"상시 조작 안내가 남아 있지 않다: %s" % name)
	# What replaced it: one table, read by the guide and checked against the
	# real bindings by test_hints.
	_assert(Defs.KEY_GUIDE.size() > 0, "대신 조작 표가 있다")
	_assert(not Defs.key_guide_rows().is_empty(), "그리고 지금 유효한 줄이 있다")

	# And the contextual prompt is untouched: it is drawn over her head, it shows
	# one thing at a time, and each one retires once it has been learned. That is
	# the opposite of a permanent legend and it stays.
	var player: String = _source("res://scripts/PlayerActor.gd")
	_assert(player.contains("_draw_prompt"), "상황별 안내는 그대로 남아 있다")
	_assert(Defs.key_prompt("MOVE").has("verb"), "첫 안내도 그대로다")

# --- test_status_hud_has_no_clock -------------------------------------------

func _test_status_hud_has_no_clock() -> void:
	var hud: String = _source("res://scripts/HUD.gd")
	# The 26pt "%02d:%02d" in the corner. A player converts a clock into "how
	# long until dark", and the day bar answers that directly.
	_assert(not hud.contains('"%02d:%02d"'), "좌측 상단에 시계 문자열이 없다")
	_assert(not hud.contains("_draw_day_arc"), "반원 해 그림도 없다")
	_assert(hud.contains("_draw_day_bar"), "대신 가로 막대가 있다")

# --- test_temperature_bar ----------------------------------------------------

func _test_temperature_bar() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.hud._layout()
	var panel: Rect2 = main.hud.status_rect()
	# Two rows and no more: the panel used to be 96 tall and held four readouts.
	_assert(is_equal_approx(panel.size.y, main.hud.STATUS_ROW * 2.0),
		"상태 영역은 막대 두 줄 높이다 (%.0f)" % panel.size.y)
	_assert(panel.size.y < 96.0, "예전 패널보다 낮다")
	# The warmth bar is the long one: it is the only readout here that is ever an
	# emergency.
	var warm_len: float = panel.size.x - main.hud.BAR_X - 30.0
	var day_len: float = (panel.size.x - main.hud.BAR_X - 40.0) * main.hud.DAY_BAR_SHARE
	_assert(warm_len > day_len, "체온 막대가 하루 막대보다 길다")
	_assert(main.hud.DAY_BAR_SHARE < 1.0, "하루 막대는 일부러 짧다")

# --- test_day_progress_bar ---------------------------------------------------

func _test_day_progress_bar() -> void:
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var was: float = main.day_fraction()
	_assert(was >= 0.0 and was <= 1.0, "하루 진행도는 0~1 이다: %.2f" % was)
	main.time_left = maxf(0.0, main.time_left - 60.0)
	_assert(main.day_fraction() > was, "시간이 지나면 진행도가 는다")
	# The bar reads the same fraction the day itself runs on -- there is no
	# second clock behind it.
	_assert(is_equal_approx(main.day_fraction(),
		1.0 - main.time_left / Defs.DAY_SECONDS), "막대는 하루 자체를 읽는다")

# --- test_day_number ---------------------------------------------------------

func _test_day_number() -> void:
	main.clear_save()
	main._start_run()
	_assert(main.day_number == 1, "첫날은 1일차다")
	main.day_number = 3
	main.hud._layout()
	# The number sits in the tail the bar leaves for it, so the two never overlap
	# at any width the player can choose.
	for scale_value: float in [Defs.UI_SCALE_MIN, Defs.UI_SCALE_DEFAULT, Defs.UI_SCALE_MAX]:
		main.ui_scale = scale_value
		main.hud._apply_scale()
		main.hud._layout()
		var panel: Rect2 = main.hud.status_rect()
		var tail: float = main.hud._text_width("%d일차" % main.day_number, 11) + 8.0
		var bar: float = (panel.size.x - main.hud.BAR_X - tail) * main.hud.DAY_BAR_SHARE
		_assert(bar > 0.0, "%.2f 배율에서 막대에 자리가 남는다" % scale_value)
		_assert(main.hud.BAR_X + bar + tail <= panel.size.x + 0.5,
			"%.2f 배율에서 일차 표시가 막대와 겹치지 않는다" % scale_value)
	main.ui_scale = Defs.UI_SCALE_DEFAULT
	main.hud._apply_scale()

# --- test_base_crafting_uses_world_progress ----------------------------------

## The fire wears a closing ring while it makes something, in the world, where
## the thing is being made. No banner and no centre-screen countdown.
func _test_base_crafting_uses_world_progress() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.sim.search_kit()
	_assert(is_equal_approx(main.craft_progress(), 0.0), "놀고 있으면 진행도는 0이다")
	main.messages.clear()
	main.message = ""
	main.craft_selected(0)
	_assert(main.craft_making != "", "제작이 시작된다")
	# Nothing is said. Starting a make used to raise a banner that named the item
	# and then sat there for 2.4 seconds while the only thing that knew how far
	# along it was, was the banner itself.
	_assert(main.messages.is_empty() and main.message == "",
		"시작할 때 아무 문구도 띄우지 않는다: '%s'" % main.message)
	_assert(main.craft_total > 0.0, "총 시간이 기록된다 — 없으면 분수가 없다")
	_assert(is_equal_approx(main.craft_progress(), 0.0), "시작 순간에는 0이다")
	for _step in 45:
		main._process_play(1.0 / 30.0)
	var mid: float = main.craft_progress()
	_assert(mid > 0.2 and mid < 0.9, "시간이 지나면 원이 차오른다: %.2f" % mid)
	# And the machine layer is the thing that draws it, through the one ring
	# helper every other hold-and-watch in this game already uses.
	main._process(0.0)
	_assert(main.machine_layer.craft_progress > 0.0, "월드 레이어가 그것을 받는다")
	var layer: String = _source("res://scripts/MachineLayer.gd")
	_assert(layer.contains("func _progress_ring"), "공용 진행 링이 있다")
	_assert(layer.count("_progress_ring(") >= 6,
		"모든 진행 표시가 그것을 지난다 (%d곳)" % layer.count("_progress_ring("))
	# And no screen-space progress anywhere: the fire carries it, in the world.
	var hud_src: String = _source("res://scripts/HUD.gd")
	_assert(not hud_src.contains("craft_left") and not hud_src.contains("craft_progress"),
		"HUD 는 제작 진행도를 그리지 않는다")
	while main.craft_making != "":
		main._process_play(1.0 / 30.0)
	_assert(is_equal_approx(main.craft_progress(), 0.0), "끝나면 표시가 사라진다")

# --- test_settings_guide -----------------------------------------------------

## The guide draws from the key table, so it cannot advertise a key the game does
## not answer to -- which is the whole reason the legend was moved rather than
## rewritten.
func _test_settings_guide() -> void:
	var hud: Node = main.hud
	main.state_before_settings = main.State.PLAY
	hud.settings_tab = hud.TAB_GUIDE
	hud._layout()
	_assert(hud.settings_tab_kind() == hud.TAB_GUIDE, "가이드 탭을 고를 수 있다")
	_assert(hud.settings_rows().is_empty(), "가이드에는 슬라이더가 없다")
	_assert(hud.guide_height() > 0.0, "가이드에 높이가 있다")
	_assert(hud.settings_body_rect.size.x > 0.0
		and hud.settings_body_rect.size.y > 0.0, "그릴 자리가 있다")
	# Every pane has something in it, and every row in every pane is one the
	# game really answers to.
	var seen := 0
	for pane: int in [Defs.PANE_MOVE, Defs.PANE_ACT, Defs.PANE_TOOL, Defs.PANE_WINDOW]:
		var rows: Array[Dictionary] = Defs.key_guide_pane(pane)
		_assert(not rows.is_empty(), "%d 번 묶음에 줄이 있다" % pane)
		seen += rows.size()
	_assert(seen == Defs.key_guide_rows().size(),
		"모든 줄이 어느 한 묶음에 속한다 (%d / %d)" % [seen, Defs.key_guide_rows().size()])
	# The card holds it at every interface size the player can pick.
	for scale_value: float in [Defs.UI_SCALE_MIN, Defs.UI_SCALE_DEFAULT, Defs.UI_SCALE_MAX]:
		main.ui_scale = scale_value
		hud._apply_scale()
		hud._layout()
		var card: Rect2 = hud.settings_card_rect()
		_assert(card.size.y <= hud.size.y + 0.5,
			"%.2f 배율에서 설정 카드가 화면 안에 있다" % scale_value)
		for index in hud.settings_tab_rects.size():
			var tab: Rect2 = hud.settings_tab_rects[index]
			_assert(card.encloses(tab.grow(-0.5)),
				"%.2f 배율에서 %d 번 아이콘이 카드 안에 있다" % [scale_value, index])
	main.ui_scale = Defs.UI_SCALE_DEFAULT
	hud._apply_scale()
	hud.settings_tab = hud.TAB_GAME
