extends "res://tests/framework/test_case.gd"

## The real scene with real input events (Viewport.push_input, canvas
## coordinates): the chooser opens the stub, a press pops and pays on the same
## frame, one finger (a touch and its mouse copy) is one press, the upgrade
## button buys, restart starts from nothing, back returns to the chooser.

const Main := preload("res://app/main.tscn")

var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame


func _click(c: Control, touch_too: bool = false) -> void:
	var p := c.get_global_rect().get_center()
	if touch_too:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = true
		tree.root.push_input(t, true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = p
	down.global_position = p
	down.pressed = true
	tree.root.push_input(down, true)
	if touch_too:
		var tu := InputEventScreenTouch.new()
		tu.position = p
		tu.pressed = false
		tree.root.push_input(tu, true)
	var up := down.duplicate()
	up.pressed = false
	tree.root.push_input(up, true)


func _open_stub() -> void:
	var tile: Control = app.chooser.tiles[0]["button"]
	_click(tile)
	await tree.process_frame


func test_starts_on_the_chooser_with_the_stub_tile() -> void:
	assert_eq(app.screen, "chooser", "chooser first")
	assert_eq(app.chooser.tiles.size(), 1, "one tile")
	assert_eq(String(app.chooser.tiles[0]["id"]), "stub", "the stub")
	assert_true(app.chooser.visible, "visible")
	assert_false(app.frame.visible, "frame hidden")


func test_the_tile_opens_the_stub() -> void:
	await _open_stub()
	assert_eq(app.screen, "play", "playing")
	assert_eq(app.exp_id, "stub", "the stub")
	assert_true(app.frame.visible, "frame shown")
	assert_eq(app.rules.money, 0, "from nothing")


func test_a_press_pops_and_pays_on_the_same_frame() -> void:
	await _open_stub()
	_click(app.frame.play)
	# No frame has passed: the press was handled synchronously.
	assert_eq(app.rules.money, 1, "paid at once")
	assert_eq(app.frame.money_view.money, 1, "the counter shows it at once")
	assert_true(app.frame.play.fx.alive > 0 or app.frame.play.fx.peak >= 0, "fx exists")
	await tree.process_frame
	assert_true(app.frame.play.fx.alive > 0, "popcorn flying")
	assert_eq(app.session.inputs, 1, "one input logged")
	assert_true(app.session.milestones.has("first_earn"), "first earn logged")


func test_one_finger_is_one_press() -> void:
	await _open_stub()
	_click(app.frame.play, true)
	assert_eq(app.rules.presses, 1, "touch + its mouse copy = one press")
	assert_eq(app.rules.money, 1, "one dollar")


func test_the_upgrade_button_buys_only_when_affordable() -> void:
	await _open_stub()
	_click(app.frame.upgrade_button)
	assert_eq(app.rules.level, 0, "no money, no upgrade")
	for i in 10:
		_click(app.frame.play)
	await tree.process_frame
	assert_true(app.frame.upgrade_button.enabled, "affordable shows enabled")
	_click(app.frame.upgrade_button)
	assert_eq(app.rules.level, 1, "bought")
	assert_eq(app.rules.money, 0, "paid 10")
	assert_true(app.session.milestones.has("first_upgrade"), "logged")
	_click(app.frame.play)
	assert_eq(app.rules.money, 2, "the upgrade is visible in the yield")


func test_restart_starts_from_nothing_and_back_returns() -> void:
	await _open_stub()
	for i in 5:
		_click(app.frame.play)
	app.dev_advance(3000)
	_click(app.frame.restart_button)
	await tree.process_frame
	assert_eq(app.screen, "play", "still playing")
	assert_eq(app.rules.money, 0, "money reset")
	assert_eq(app.clock.now_ms < 1000, true, "clock reset (%d)" % app.clock.now_ms)
	assert_eq(app.session.inputs, 0, "new log")
	assert_eq(app.history.size(), 1, "the old run's summary kept for this visit")
	assert_eq(int(app.history[0]["inputs"]), 5, "with its inputs")
	_click(app.frame.back_button)
	await tree.process_frame
	assert_eq(app.screen, "chooser", "back to the chooser")
	assert_eq(app.history.size(), 2, "second summary")


func test_the_space_key_presses_too() -> void:
	await _open_stub()
	var k := InputEventKey.new()
	k.keycode = KEY_SPACE
	k.pressed = true
	tree.root.push_input(k)
	var u := k.duplicate()
	u.pressed = false
	tree.root.push_input(u)
	assert_eq(app.rules.money, 1, "space pressed once")


func test_hidden_page_stops_the_clock() -> void:
	await _open_stub()
	app.clock.set_pause("hidden", true)
	var before := app.clock.now_ms
	for i in 10:
		await tree.process_frame
	assert_eq(app.clock.now_ms, before, "no time while hidden")
	app.clock.set_pause("hidden", false)
	for i in 5:
		await tree.process_frame
	assert_true(app.clock.now_ms >= before, "runs again")


func test_three_minutes_is_logged_and_shown() -> void:
	await _open_stub()
	app.dev_advance(180000)
	assert_true(app.session.milestones.has("three_minutes"), "milestone")
	assert_true(app.frame.clock_ms >= 180000, "the frame knows (draws the 3:00 pill)")


func test_state_reports_rects_inside_the_window() -> void:
	await _open_stub()
	var s := app.state()
	var win: Array = s["window"]
	for key: String in ["play", "upgrade", "back", "restart", "money"]:
		var r: Array = s["rects"][key]
		assert_true(float(r[2]) > 0 and float(r[3]) > 0, "%s has a size %s" % [key, r])
		assert_true(float(r[0]) >= -1 and float(r[0]) + float(r[2]) <= float(win[0]) + 1, "%s inside the window %s %s" % [key, r, win])
