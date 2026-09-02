extends SceneTree

## The Esc panel, after it became a strip of icons.
##
## What is pinned here is the order the player asked for, that each icon does the
## thing it says, and that choosing one cannot leave the panel in a state where
## the selected icon is not on screen. The two scales and the 31 save slots are
## the old machinery unchanged -- these tests reach them through the new strip to
## prove the rework re-wired rather than rebuilt them.

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
	_test_esc_menu_horizontal_order()
	_test_settings_save_action()
	_test_settings_load_action()
	_test_settings_game_options()
	_test_settings_main_menu()
	_test_settings_exit()
	if failures == 0:
		print("PASS test_settings_menu")
	else:
		print("FAIL test_settings_menu (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _open() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.open_settings()
	main._process(0.0)
	main.hud._layout()

# --- test_esc_menu_horizontal_order ------------------------------------------

## Left to right, in the order the brief names them, and laid out as a strip
## rather than a column.
func _test_esc_menu_horizontal_order() -> void:
	_open()
	var hud: Node = main.hud
	var tabs: Array[int] = hud.settings_tabs()
	var want: Array[int] = [hud.TAB_SAVE, hud.TAB_LOAD, hud.TAB_GAME, hud.TAB_GUIDE,
		hud.TAB_TITLE]
	if not OS.has_feature("web"):
		want.append(hud.TAB_QUIT)
	_assert(tabs == want, "저장·로드·설정·가이드·메인·종료 순이다: %s" % str(tabs))
	_assert(hud.settings_tab_rects.size() == tabs.size(), "아이콘마다 자리가 있다")
	# Horizontal: each one starts to the right of the last and they share a row.
	for index in range(1, hud.settings_tab_rects.size()):
		var a: Rect2 = hud.settings_tab_rects[index - 1]
		var b: Rect2 = hud.settings_tab_rects[index]
		_assert(b.position.x > a.position.x, "%d 번이 오른쪽에 있다" % index)
		_assert(is_equal_approx(a.position.y, b.position.y), "%d 번이 같은 줄이다" % index)
		_assert(not a.intersects(b), "%d 번이 앞 아이콘과 겹치지 않는다" % index)
	# And the strip is walked with left and right.
	var first: int = hud.settings_tab_kind()
	main.settings_step(1)
	_assert(hud.settings_tab_kind() != first, "→ 가 다음 아이콘으로 간다")
	main.settings_step(-1)
	_assert(hud.settings_tab_kind() == first, "← 가 돌아온다")
	# It wraps: six icons in a row is a loop, not a list with ends to bump into.
	for _step in tabs.size():
		main.settings_step(1)
	_assert(hud.settings_tab_kind() == first, "한 바퀴 돌면 제자리다")
	main.close_settings()

# --- test_settings_save_action / test_settings_load_action -------------------

## Both open the existing 31-slot picker. The save machinery is untouched: what
## changed is the thing that opens it.
func _test_settings_save_action() -> void:
	_open()
	main.settings_choose(main.hud.TAB_SAVE)
	_assert(int(main.hud.slot_picker) == 1, "저장 슬롯 목록이 열린다")
	_assert(main.slot_cards().size() == main.SAVE_SLOTS,
		"슬롯은 여전히 %d 칸이다" % main.SAVE_SLOTS)
	main.close_slot_picker()
	main.close_settings()

func _test_settings_load_action() -> void:
	_open()
	# Something to load, so the row is a real one.
	main.sim.stones_in = 7
	_assert(main.save_game(false), "저장된다")
	var cards: Array[Dictionary] = main.slot_cards()
	_assert(bool(cards[0]["exists"]), "0번 슬롯에 기록이 있다")
	# The picker's preview reads the key the save actually writes. It read a key
	# nobody wrote for as long as the picker has existed, so every slot drew
	# 열석 0개 -- one word, on the screen whose only job is telling saves apart.
	_assert(int(cards[0]["stones"]) == 7,
		"슬롯 카드가 실제 열석 수를 읽는다: %d" % int(cards[0]["stones"]))
	main.settings_choose(main.hud.TAB_LOAD)
	_assert(int(main.hud.slot_picker) == 2, "불러오기 슬롯 목록이 열린다")
	main.close_slot_picker()
	main.close_settings()
	main.clear_save()

# --- test_settings_game_options ----------------------------------------------

## The two sliders that already existed, reached through the 설정 icon. No new
## setting was invented for this pass.
func _test_settings_game_options() -> void:
	_open()
	var hud: Node = main.hud
	hud.settings_tab = hud.TAB_GAME
	hud._layout()
	var rows: Array[int] = hud.settings_rows()
	_assert(rows == [hud.ROW_GAME, hud.ROW_UI], "설정 아래에 두 크기가 있다")
	_assert(hud.settings_slider_of(hud.ROW_UI) == 0, "UI 크기는 0번 슬라이더 그대로다")
	_assert(hud.settings_slider_of(hud.ROW_GAME) == 1, "게임 크기는 1번 그대로다")
	_assert(hud.slider_track_rects.size() == 2, "막대는 둘이다")
	for row in 2:
		_assert((hud.slider_track_rects[row] as Rect2).size.x > 0.0,
			"%d 번 막대에 길이가 있다" % row)
	# And they still move the thing they name.
	main.set_ui_scale(Defs.UI_SCALE_MIN)
	var before: float = main.ui_scale
	main._nudge_slider(0, Defs.UI_SCALE_STEP)
	_assert(main.ui_scale > before, "UI 슬라이더가 실제로 크기를 바꾼다")
	main.set_ui_scale(Defs.UI_SCALE_DEFAULT)
	main.close_settings()

# --- test_settings_main_menu -------------------------------------------------

func _test_settings_main_menu() -> void:
	_open()
	main.settings_choose(main.hud.TAB_TITLE)
	_assert(main.state == main.State.TITLE, "메인화면으로 돌아간다")
	# And the panel reopened from there does not still think it is on an icon
	# that only exists inside a run.
	main.open_settings()
	main.hud._layout()
	_assert(main.hud.settings_tabs().has(main.hud.settings_tab_kind()),
		"선택된 아이콘이 실제로 목록에 있다")
	main.close_settings()

# --- test_settings_exit ------------------------------------------------------

## Quitting is real on a desktop and impossible in a browser tab, so the icon is
## absent on the web rather than present and refusing -- the same rule the title
## menu's own 종료 row already follows.
func _test_settings_exit() -> void:
	_open()
	var hud: Node = main.hud
	if OS.has_feature("web"):
		_assert(not hud.settings_tabs().has(hud.TAB_QUIT), "웹에서는 종료가 없다")
	else:
		_assert(hud.settings_tabs().has(hud.TAB_QUIT), "데스크톱에는 종료가 있다")
		_assert(main.has_method("settings_quit"), "종료가 실제 동작에 이어져 있다")
	main.close_settings()
