extends "res://tests/framework/test_case.gd"

## Step 44: usability without words.
## - a press refused because the glass waits shows why (arrows up to the bin, the bin ringed),
##   for long enough to be in a still a moment later, and makes no smoke (read as burning)
##   (Step 47: up while the finger is down and 2 s after it lifts -- test_ready47)
## - a newcomer's tap (an early release) before any Perfect brings the hint once: the dot runs
##   to the gold with the finger down; never after a Perfect, at most three times
## - the overview's rates are a way in: a rate opens its floor with a free place's picker; a full
##   floor rings its next line instead and the card stays
## - a hold ends when the window loses focus (no burnt lot from a lost key-up)

const Main := preload("res://app/main.tscn")
const PLAN: Array = preload("res://tests/unit/test_factory_rules.gd").FORTY_PLAN
var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	app.save_prefix = "test."
	PopSaveStore.clear("test.factory.v1")
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame


func _open() -> Node:
	app.open("factory")
	app.clock.set_pause("dev", true)
	await tree.process_frame
	return app.frame.play


func _mouse(v: Node, at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	v._gui_input(e)


func _frames(n: int, ms: int = 100) -> void:
	for i in n:
		app.dev_advance(ms)
		await tree.process_frame


func test_a_press_on_a_waiting_glass_shows_the_full_bin_not_smoke() -> void:
	var v: Node = await _open()
	app.rules.glass = {"id": 777777, "recipe": "plain", "quality": 90, "portions": 4}
	app.rules.stats["made_portions"] = int(app.rules.stats["made_portions"]) + 4
	_mouse(v, v.machine_centre(), true)
	await _frames(1)
	_mouse(v, v.machine_centre(), false)
	await _frames(4)   # 0.4 s later: a still shows it
	assert_eq(int(v.full_cues), 1, "the refused press is shown")
	assert_true(v.full_cue.visible, "the cue is up 0.4 s after the press")
	assert_true(v.full_bin_rect().intersects(v.packing_rect()), "the cue rings the bin, on the packing floor")
	assert_false(bool(app.rules.heating), "the kettle did not heat (refused)")
	await _frames(17)
	assert_false(v.full_cue.visible, "gone 2 s after the finger lifted (Step 47)")
	var src := FileAccess.get_file_as_string("res://variants/factory/factory_view.gd")
	var press_fn := src.substr(src.find("func _press() -> void:"), 600)
	assert_false(press_fn.contains("fx.smoke"), "no smoke on a refused press")
	app.rules.glass = {}
	app.rules.stats["made_portions"] = int(app.rules.stats["made_portions"]) - 4


func _tap(v: Node) -> void:
	_mouse(v, v.machine_centre(), true)
	await _frames(1, 60)
	_mouse(v, v.machine_centre(), false)
	await _frames(1, 60)


func test_a_newcomers_tap_brings_the_hold_hint_once_and_never_after_a_perfect() -> void:
	var v: Node = await _open()
	await _tap(v)
	assert_eq(int((app.rules.outcomes as Dictionary).get("early", 0)), 1, "a tap is an early release")
	assert_eq(int(v.coach_shown), 1, "the coach shows")
	await _frames(1)
	assert_true(v.hint_node.visible, "the hint is up right after the tap")
	assert_true(v.hint_finger.visible, "with the finger held down")
	await _frames(30)
	assert_false(v.hint_node.visible, "and gone after its one loop")
	for i in 4:
		await _frames(40)   # past the cooldown
		await _tap(v)
	assert_eq(int(v.coach_shown), int(v.COACH_TIMES), "at most %d times" % v.COACH_TIMES)
	# A Perfect: no more coaching ever (a fresh view).
	app.rules.outcomes["perfect"] = 1
	v.coach_shown = 0
	await _frames(40)
	await _tap(v)
	assert_eq(int(v.coach_shown), 0, "no coach once a Perfect has been made")


func test_a_rate_in_the_overview_opens_its_floor_or_rings_its_next_line() -> void:
	var v: Node = await _open()
	app.dev_build(PLAN.slice(0, 3), 6, 2)   # a kettle, a bagger, a counter machine: places free
	await _frames(3)
	v.overview = true
	await _frames(1)
	assert_true(app.state()["rects"].has("ov_rate_1"), "the rates are pressable")
	var r: Rect2 = v.extra_rects()["ov_rate_1"]
	_mouse(v, r.get_center(), true)
	_mouse(v, r.get_center(), false)
	await _frames(1)
	assert_false(v.overview, "the card closes")
	assert_eq(String(v.sel_slot.get("floor", "")), "packing", "the packing floor's free place is chosen")
	assert_eq(int(v.selected), int(v.FLOOR_INDEX["packing"]), "its floor is open")
	assert_true(app.state()["rects"].keys().any(func(k: String) -> bool: return k.begins_with("pick_")), "its picker is up")
	# A full floor: the card stays and its next line is ringed.
	v._clear_machine_selection()
	v.selected = -1
	app.rules.money = 1 << 24
	while not app.rules.floor_full("kitchen"):
		var ok: bool = bool(app.rules.execute({"type": "build", "machine": "cooker", "floor": "kitchen"})["ok"])
		assert_true(ok, "fill the kitchen")
		if not ok:
			break
	v.overview = true
	await _frames(1)
	v.go_to_stage(0)
	assert_true(v.overview, "a full kitchen keeps the card")
	assert_eq(String(v._ov_flash_line), "kitchen", "and rings its next line")
	await _frames(20)
	assert_eq(String(v._ov_flash_line), "", "for a moment")


func test_a_hold_ends_when_the_window_loses_focus() -> void:
	var v: Node = await _open()
	_mouse(v, v.machine_centre(), true)
	await _frames(3)
	assert_true(bool(app.rules.heating), "holding")
	v.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(1)
	assert_false(bool(app.rules.heating), "released when the window lost focus")
	assert_eq(int(v.focus_releases), 1, "once")
	# The keyboard too: Space down, focus lost, no key-up ever comes.
	await _frames(40)
	v.key(true)
	await _frames(3)
	assert_true(bool(app.rules.heating), "Space holds")
	v.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _frames(1)
	assert_false(bool(app.rules.heating), "released without a key-up")
	assert_eq(int(app.rules.outcomes.get("burnt", 0)), 0, "nothing burnt")


func test_the_motion_button_calms_the_factory_and_is_kept() -> void:
	PopSaveStore.clear("motion")
	var v: Node = await _open()
	assert_true(app.frame.motion_button.visible, "the factory shows the motion button")
	var was := bool(app.reduced_motion)
	app.frame.motion_button.pressed.emit()
	await _frames(1)
	assert_eq(bool(app.reduced_motion), not was, "it switches")
	assert_eq(bool(v.reduced_motion), not was, "the running view follows at once")
	assert_eq(bool(v.low_effects), not was, "calm is also the low effects")
	assert_eq(PopSaveStore.read("motion").strip_edges(), "calm" if not was else "full", "the choice is kept")
	assert_true(app.state()["rects"].has("motion"), "pressable")
	app.frame.motion_button.pressed.emit()
	await _frames(1)
	assert_eq(bool(v.reduced_motion), was, "and back")
	PopSaveStore.clear("motion")
	# The experiments A/B/C keep their bar.
	app.open("click")
	await tree.process_frame
	assert_false(app.frame.motion_button.visible, "not in experiment A")
	assert_false(app.state()["rects"].has("motion"), "nor in its rects")


func test_big_moments_go_to_the_screen_reader_politely() -> void:
	var v: Node = await _open()
	app.dev_build(PLAN.slice(0, 3), 6, 2)
	await _frames(2)
	assert_true(v.announced.size() >= 1, "a machine built is announced (%s)" % [v.announced])
	var n: int = v.announced.size()
	app.dev_build(PLAN.slice(3, 6), 6, 2)
	await _frames(2)
	assert_eq(v.announced.size(), n, "not again within four seconds (polite, not a stream)")
	assert_true(v.CANVAS_LABEL.contains("스페이스"), "the canvas label names the keyboard too")
