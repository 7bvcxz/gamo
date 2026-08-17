extends SceneTree

## The settings panel and the UI scale behind it. This exists because the HUD is
## sized in logical pixels, which on a phone are roughly 0.4 of a physical one --
## so the numbers below are not cosmetic, they are the difference between a
## readable HUD and a 5 CSS px one.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame

	# --- Scale maths ---------------------------------------------------------
	_assert(Defs.UI_SCALE_TOUCH_BASE == 2.0, "touch starts at twice the logical size")
	_assert(Defs.UI_SCALE_TOUCH_BASE > Defs.UI_SCALE_DESKTOP_BASE,
		"a phone gets a larger base than a desktop")
	_assert(is_equal_approx(Defs.quantise_ui_scale(1.234), 1.25), "scale snaps to the step")
	_assert(is_equal_approx(Defs.quantise_ui_scale(99.0), Defs.UI_SCALE_MAX), "scale clamps high")
	_assert(is_equal_approx(Defs.quantise_ui_scale(-5.0), Defs.UI_SCALE_MIN), "scale clamps low")

	# --- The gear owns the top-left corner ------------------------------------
	_tick(main)
	var gear: Rect2 = main.hud.settings_button_rect
	_assert(gear.size.x > 0.0, "the settings button has a rect")
	_assert(gear.position.x < main.hud.size.x * 0.25 and gear.position.y < main.hud.size.y * 0.25,
		"the settings button sits in the top-left corner")
	_assert(main.hud.status_top() >= gear.position.y + gear.size.y,
		"the status panel starts below the gear instead of under it")

	# --- Opening and closing ---------------------------------------------------
	main.state = main.State.PLAY
	_tick(main)
	_assert(main.touch_hud(gear.get_center() * main.hud.scale.x), "tapping the gear is handled")
	_assert(main.state == main.State.SETTINGS, "tapping the gear opens settings")

	# Sizing the UI must not cost the player warmth or daylight.
	var frozen: float = main.time_left
	main._process(0.5)
	_assert(is_equal_approx(main.time_left, frozen), "the clock stops while settings are open")

	# --- The sliders ------------------------------------------------------------
	_tick(main)
	_assert(main.hud.slider_track_rects.size() == 2, "the panel has a UI row and a game row")
	for row in 2:
		var t: Rect2 = main.hud.slider_track_rects[row]
		_assert(t.size.x > 0.0, "slider row %d has a track" % row)
		_assert((main.hud.slider_hit_rects[row] as Rect2).size.y > t.size.y * 3.0,
			"slider row %d has a hit area far taller than the drawn bar" % row)
		var range: Vector2 = main.hud.slider_range(row)
		_assert(is_equal_approx(main.hud.slider_value_at(row, t.position.x), range.x),
			"the left end of row %d is its minimum" % row)
		_assert(is_equal_approx(main.hud.slider_value_at(row, t.position.x + t.size.x), range.y),
			"the right end of row %d is its maximum" % row)
	# The two rows must not claim each other's touches, or the player drags one
	# slider and watches the other move.
	_assert(not (main.hud.slider_hit_rects[0] as Rect2).intersects(main.hud.slider_hit_rects[1]),
		"the two slider hit areas do not overlap")
	_assert(main.hud.slider_at((main.hud.slider_track_rects[1] as Rect2).get_center()) == 1,
		"a point on the game row resolves to the game row")

	var track: Rect2 = main.hud.slider_track_rects[0]
	var before: float = main.ui_scale
	var right_end := Vector2(track.position.x + track.size.x, track.get_center().y)
	_assert(main.touch_hud(right_end * main.hud.scale.x), "touching the slider is handled")
	_assert(main.ui_scale > before, "dragging the slider right enlarges the UI")
	_assert(is_equal_approx(main.ui_scale, Defs.UI_SCALE_MAX), "the far right end is the maximum")
	_assert(main.hud.dragging_slider == 0, "the UI row is the one being dragged")

	# The HUD must actually resize, not just record a number. Checked here, before
	# anything else ticks, or the change has already been applied and the
	# assertion passes on a HUD that never moved.
	var scale_before: float = main.hud.scale.x
	_tick(main)
	_assert(main.hud.scale.x > scale_before, "raising the setting scales the HUD up")
	_assert(is_equal_approx(main.hud.scale.x,
		Defs.UI_SCALE_DESKTOP_BASE * main.ui_scale), "HUD scale is base times the setting")

	# --- The game-view row drives the camera, not the HUD ------------------------
	var ui_kept: float = main.ui_scale
	var game_track: Rect2 = main.hud.slider_track_rects[1]
	var zoom_before: float = main.camera.zoom.x
	_assert(main.touch_hud(Vector2(game_track.position.x, game_track.get_center().y)
		* main.hud.scale.x), "touching the game row is handled")
	_assert(is_equal_approx(main.game_scale, Defs.GAME_SCALE_MIN),
		"the left end of the game row is its minimum")
	_assert(is_equal_approx(main.ui_scale, ui_kept), "the game row leaves the UI size alone")
	_assert(main.camera.zoom.x < zoom_before, "shrinking the game view zooms the camera out")
	main.set_game_scale(Defs.GAME_SCALE_MAX)
	_assert(main.camera.zoom.x > zoom_before, "enlarging the game view zooms the camera in")
	# Applied on the spot so a drag resizes the world under the player's finger.
	_assert(is_equal_approx(main.camera.zoom.x,
		Defs.GAME_SCALE_DESKTOP_BASE * Defs.GAME_SCALE_MAX),
		"camera zoom is the platform base times the setting")
	main.set_game_scale(Defs.GAME_SCALE_DEFAULT)

	# A phone shows a viewport far taller than the layout was drawn for, so it
	# needs to start closer in than a desktop does.
	_assert(Defs.GAME_SCALE_TOUCH_BASE > Defs.GAME_SCALE_DESKTOP_BASE,
		"touch starts more zoomed in than desktop")
	_assert(is_equal_approx(Defs.GAME_SCALE_TOUCH_BASE, 1.6), "touch starts at 160% of desktop")
	main.touch.visible = true
	main._apply_camera_zoom()
	_assert(is_equal_approx(main.camera.zoom.x, Defs.GAME_SCALE_TOUCH_BASE * main.game_scale),
		"the touch base applies once the pad is showing")
	main.touch.visible = false
	main._apply_camera_zoom()

	# Nothing may run off the screen at the largest setting.
	var slot: Vector2 = main.hud.hotbar_slot()
	var row: float = float(Defs.BUILDABLE.size()) * (slot.x + main.hud.SLOT_GAP) - main.hud.SLOT_GAP
	_assert(row <= main.hud.size.x, "the hotbar still fits across the screen at maximum scale")
	_assert(main.hud.hotbar_origin().x >= 0.0, "the hotbar does not start off the left edge")

	main.set_ui_scale(Defs.UI_SCALE_MIN)
	_tick(main)
	_assert(is_equal_approx(main.ui_scale, Defs.UI_SCALE_MIN), "the slider can come back down")

	# --- The layout has to survive every scale, not just the default ------------
	# Scaling the UI up shrinks the logical screen, so panels that sat comfortably
	# side by side start colliding. These are the two collisions that actually
	# cost the player something: an unreadable objective and an untappable card.
	main.state = main.State.PLAY
	main.touch.visible = true
	for value: float in [Defs.UI_SCALE_MIN, Defs.UI_SCALE_DEFAULT, Defs.UI_SCALE_MAX]:
		main.set_ui_scale(value)
		_tick(main)
		var percent: int = int(round(value * 100.0))
		var objective: Rect2 = main.hud.objective_rect(main.objective())
		_assert(not objective.intersects(main.hud.status_rect()),
			"the objective clears the status panel at %d%%" % percent)
		_assert(objective.position.x >= 0.0
			and objective.position.x + objective.size.x <= main.hud.size.x + 0.5,
			"the objective stays on screen at %d%%" % percent)
		var card: Rect2 = main.hud.hotbar_rects[0]
		var hotbar_bottom: float = (card.position.y + card.size.y) * main.hud.scale.x
		var pad_top: float = main.get_viewport_rect().size.y - main.touch.reserved_height()
		_assert(hotbar_bottom <= pad_top + 0.5,
			"the hotbar clears the touch pad at %d%%" % percent)
		_assert(main.hud.hotbar_origin().y > main.hud.status_rect().end.y,
			"the hotbar stays below the status panel at %d%%" % percent)
	main.touch.visible = false

	# --- The pad scales with it -------------------------------------------------
	main.touch.set_pad_scale(1.0)
	var centres: Array[Vector2] = main.touch.button_centers
	_assert(centres.size() == 4, "the pad lays out four action buttons")
	# The pad's buttons are the keyboard's keys. Mining is the first verb the game
	# teaches and for a while the pad had no way to do it at all, which is why a
	# 캐기 button existed -- but a button the keys do not have is a second control
	# scheme to teach, and this one also opened the throughput panel, which Z has
	# never done.
	var labels: Array = main.touch.BUTTON_LABELS
	_assert(labels[1] == "Z" and labels[2] == "X" and labels[3] == "C",
		"패드가 Z·X·C를 그대로 가진다: %s" % str(labels))
	var hit: float = main.touch.button_hit_radius()
	for a in centres.size():
		for b in range(a + 1, centres.size()):
			_assert(centres[a].distance_to(centres[b]) >= hit * 2.0,
				"action button hit areas do not overlap")
	var small: float = main.touch.wheel_radius()
	main.touch.set_pad_scale(Defs.UI_SCALE_MAX)
	_assert(main.touch.wheel_radius() > small, "the wheel grows with the setting")

	# --- Closing restores the screen underneath ---------------------------------
	main.close_settings()
	_assert(main.state == main.State.PLAY, "closing settings returns to the run")
	main.state = main.State.TITLE
	_tick(main)
	_assert(main.touch_hud(gear.get_center() * main.hud.scale.x), "the gear works on the title too")
	_assert(main.state == main.State.SETTINGS, "settings open from the title screen")
	_assert(not main.player.visible, "the title hero shot stays clean behind the panel")
	main.close_settings()
	_assert(main.state == main.State.TITLE, "closing returns to the title, not into the run")

	# --- Persistence -------------------------------------------------------------
	# A preference about the player's eyes must outlive both a new game and a
	# save-schema bump, so it lives in its own file.
	main.set_ui_scale(1.35)
	main.set_game_scale(0.85)
	_assert(main.save_settings(), "settings are written to disk")
	main.ui_scale = Defs.UI_SCALE_DEFAULT
	main.game_scale = Defs.GAME_SCALE_DEFAULT
	main.load_settings()
	_assert(is_equal_approx(main.ui_scale, 1.35), "the UI scale survives a reload")
	_assert(is_equal_approx(main.game_scale, 0.85), "the game scale survives a reload")
	# Last, because it walks out of the run to the title and everything above
	# it is standing inside that run.
	_test_rows(main)

	main.clear_save()
	main.load_settings()
	_assert(is_equal_approx(main.ui_scale, 1.35), "clearing the run save keeps the UI setting")
	_assert(is_equal_approx(main.game_scale, 0.85), "clearing the run save keeps the game setting")

	main.set_ui_scale(Defs.UI_SCALE_DEFAULT)
	main.set_game_scale(Defs.GAME_SCALE_DEFAULT)
	main.save_settings()

	_test_resource_ledger(main)

	if failures == 0:
		print("SETTINGS_TEST: PASS")
	quit(failures)

## The HUD is its own node, so ticking the orchestrator alone leaves its layout
## and scale a frame behind. Both have to run for a layout assertion to mean
## anything.
func _tick(main: Node2D) -> void:
	main._process(0.0)
	main.hud._process(0.0)

## --- The resource ledger ------------------------------------------------------
## Split out of the status panel: that box is about the player's own situation
## (time, daylight, warmth, body heat) and this one is about what they own. They
## were one box, and every resource added to the game made the clock harder to
## read.
func _test_resource_ledger(main: Node2D) -> void:
	var sim = main.sim
	main.state = main.State.PLAY
	sim.stock.clear()
	sim.delivered.clear()
	sim.gain_rate.clear()
	main.hud._apply_scale()
	main.hud._layout()

	var names: Array[String] = _row_names(main)
	_assert(names.has("열"), "heat is always on the ledger, since it is the score")
	_assert(not names.has("구리"),
		"a resource never seen is not listed: a row reading zero teaches nothing")

	# Gaining one is what puts it on the list, and the rate comes from the same
	# accounting rather than from a second counter that could disagree.
	sim._gain(Defs.ITEM_COPPER, 4)
	sim.tick(1.05)
	names = _row_names(main)
	_assert(names.has("구리"), "holding a resource puts it on the ledger")
	# The exact text the player reads. Per minute, like every other rate the game
	# quotes: a miner is 6/min, and the same figure written as 0.10/s is the same
	# information in a form nobody can plan against.
	var copper: Array = _row(main, "구리")
	_assert(copper[1] == "4", "the amount column is the plain count: '%s'" % copper[1])
	_assert(String(copper[2]).ends_with("/분"),
		"and the rate column is per minute: '%s'" % copper[2])
	_assert(String(copper[2]).begins_with("+"),
		"marked as income rather than a bare number: '%s'" % copper[2])
	# Four items in one second is 240 a minute, smoothed toward that by the same
	# lerp heat uses, so this checks the unit rather than the exact reading.
	_assert(float(sim.gain_rate.get(Defs.ITEM_COPPER, 0.0)) > 10.0,
		"four items in a second reads as a per-minute figure, not a per-second one: %.1f"
		% float(sim.gain_rate.get(Defs.ITEM_COPPER, 0.0)))
	# Heat is quoted from the same unit, so the two rows cannot disagree.
	sim.heat_rate = 12.0
	_assert(_row(main, "열")[2] == "+12/분", "heat reads per minute too: '%s'" % _row(main, "열")[2])
	sim.heat_rate = 0.0
	_assert(_row(main, "열")[2] == "", "and a resource producing nothing shows no rate")
	_assert(sim.gain_rate.get(Defs.ITEM_COPPER, 0.0) > 0.0,
		"and what arrived is counted as income: %.1f/min" % float(sim.gain_rate.get(Defs.ITEM_COPPER, 0.0)))

	# Spending is not negative production. A row that dipped below zero every
	# time the player built something would be reporting on the wrong thing.
	var before: float = float(sim.gain_rate.get(Defs.ITEM_COPPER, 0.0))
	sim.stock[Defs.ITEM_COPPER] = 1
	sim.tick(1.05)
	_assert(float(sim.gain_rate.get(Defs.ITEM_COPPER, 0.0)) <= before + 0.001,
		"spending never registers as income")

	# Power reads as used-of-available rather than as a stock, and only appears
	# once something generates it.
	_assert(not _row_names(main).has("전기"), "no power row before a generator exists")

	# The two boxes must not overlap each other, the screen edge or the hotbar,
	# at any scale the player can choose.
	for scale_value: float in [Defs.UI_SCALE_MIN, Defs.UI_SCALE_DEFAULT, Defs.UI_SCALE_MAX]:
		main.ui_scale = scale_value
		main.hud._apply_scale()
		main.hud._layout()
		var status: Rect2 = main.hud.status_rect()
		var ledger: Rect2 = main.hud.resource_rect()
		_assert(ledger.position.y >= status.position.y + status.size.y,
			"the ledger sits below the status panel at UI %.2f" % scale_value)
		_assert(ledger.position.x >= 0.0 and ledger.position.x + ledger.size.x <= main.hud.size.x + 0.5,
			"and stays on screen at UI %.2f" % scale_value)
		_assert(ledger.position.y + ledger.size.y <= main.hud.hotbar_origin().y + 0.5,
			"and clear of the hotbar at UI %.2f" % scale_value)
	main.ui_scale = Defs.UI_SCALE_DEFAULT

## The ledger row with this name, or an empty row.
func _row(main: Node2D, name: String) -> Array:
	for row: Array in main.hud.resource_rows():
		if String(row[0]) == name:
			return row
	return ["", "", "", Color.WHITE, -1]

func _row_names(main: Node2D) -> Array[String]:
	var names: Array[String] = []
	for row: Array in main.hud.resource_rows():
		names.append(String(row[0]))
	return names


# --- One list, and what is on it --------------------------------------------

func _test_rows(main: Node2D) -> void:
	var hud: Node = main.hud

	# From the title there is no run to save, load into or leave. A row that is
	# present and refuses teaches the player to skip past the row.
	main.state_before_settings = main.State.TITLE
	var from_title: Array[int] = hud.settings_rows()
	_assert(from_title == [hud.ROW_GAME, hud.ROW_UI, hud.ROW_CLOSE],
		"메인화면의 설정에는 두 크기와 닫기만 있다: %s" % str(from_title))

	# In a run, the order the player asked for, top to bottom.
	main.state_before_settings = main.State.PLAY
	var in_run: Array[int] = hud.settings_rows()
	_assert(in_run == [hud.ROW_SAVE, hud.ROW_LOAD, hud.ROW_TITLE, hud.ROW_GAME,
			hud.ROW_UI, hud.ROW_CLOSE],
		"게임 중에는 저장·불러오기·메인화면·게임 크기·UI 크기·닫기 순이다: %s" % str(in_run))
	# The way out is on the cursor. It was the one button on the panel the arrow
	# keys could not reach, which on a pad with no Escape meant the way out was a
	# tap and only a tap.
	_assert(in_run[in_run.size() - 1] == hud.ROW_CLOSE, "닫기가 마지막 줄이다")

	# Reordering the display must not renumber the values: the two scales keep
	# the slider indices everything else speaks.
	_assert(hud.settings_slider_of(hud.ROW_UI) == 0, "UI 크기는 여전히 0번 슬라이더다")
	_assert(hud.settings_slider_of(hud.ROW_GAME) == 1, "게임 크기는 여전히 1번이다")
	for kind: int in [hud.ROW_SAVE, hud.ROW_LOAD, hud.ROW_TITLE, hud.ROW_CLOSE]:
		_assert(hud.settings_slider_of(kind) < 0, "행동 줄은 슬라이더가 아니다")

	# Every row is on the same cursor, and every row is where it is drawn.
	#
	# `open_settings` remembers the screen it was opened over, so the state has to
	# be the run before it is called -- otherwise the panel lays itself out as the
	# title's two rows while this reads the run's six.
	main.state = main.State.PLAY
	main.open_settings()
	main._process(0.0)
	for index in in_run.size():
		var rect: Rect2 = hud.settings_row_rects[index]
		_assert(rect.size.x > 100.0 and rect.size.y > 20.0,
			"%d번째 줄이 그릴 만한 크기다" % index)
		_assert(int(hud.call("settings_row_at", rect.get_center())) == index,
			"%d번째 줄을 누르면 그 줄이 잡힌다" % index)
	var card: Rect2 = hud.call("_card_rect", hud.settings_card_height())
	for index in in_run.size():
		var row: Rect2 = hud.settings_row_rects[index]
		_assert(card.encloses(row.grow(-1.0)),
			"%d번째 줄이 카드 안에 있다 (줄 %.0f..%.0f, 카드 %.0f..%.0f)"
				% [index, row.position.y, row.position.y + row.size.y,
					card.position.y, card.position.y + card.size.y])
	_assert(card.position.y >= 0.0 and card.position.y + card.size.y <= hud.size.y,
		"다섯 줄짜리 카드가 화면 안에 들어간다")

	# The close button and the last row are the same rectangle, so what the cursor
	# lands on and what a finger taps cannot drift apart.
	var close_row: int = in_run.find(hud.ROW_CLOSE)
	_assert((hud.settings_close_rect as Rect2).get_center()
		.distance_to((hud.settings_row_rects[close_row] as Rect2).get_center()) < 0.01,
		"닫기 버튼과 마지막 줄이 같은 사각형이다")
	hud.settings_row = close_row
	main.settings_activate(hud.ROW_CLOSE)
	_assert(main.state != main.State.SETTINGS, "닫기 줄에서 Z 를 누르면 닫힌다")
	main.open_settings()
	main._process(0.0)

	# And 메인화면 gets out of the run.
	hud.settings_row = in_run.find(hud.ROW_TITLE)
	main.settings_activate(hud.ROW_TITLE)
	_assert(main.state == main.State.TITLE, "메인화면 줄은 타이틀로 나간다")
	_assert(main.state_before_settings == main.State.TITLE,
		"그리고 설정이 게임으로 돌아가려 하지 않는다")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SETTINGS_TEST: FAIL - " + message)
		failures += 1
