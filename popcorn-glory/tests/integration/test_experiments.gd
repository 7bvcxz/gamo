extends "res://tests/framework/test_case.gd"

## Each experiment with real input events: A pays per press; B's press-hold-
## release through the mouse (and the space key) reaches the gold; C's eight
## presses erupt and its pieces stay under the cap. Runs are isolated: leaving
## one experiment and opening another starts from nothing.

const Main := preload("res://app/main.tscn")

var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame


func _mouse(c: Control, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = c.get_global_rect().get_center()
	e.global_position = e.position
	e.pressed = down
	tree.root.push_input(e, true)


func test_a_pays_per_press() -> void:
	app.open("click")
	await tree.process_frame
	for i in 5:
		_mouse(app.frame.play, true)
		_mouse(app.frame.play, false)
	assert_eq(app.rules.money, 5, "5 presses, $5")
	assert_eq(app.session.inputs, 5, "5 inputs")


func test_b_hold_into_the_gold_with_the_mouse() -> void:
	app.open("perfect")
	await tree.process_frame
	_mouse(app.frame.play, true)
	assert_true(bool(app.rules.state()["heating"]), "heating while held")
	app.dev_advance(1600)
	_mouse(app.frame.play, false)
	assert_eq(int(app.rules.outcomes["perfect"]), 1, "released in the gold")
	assert_eq(app.rules.money, 10, "5 x 2")
	assert_eq(app.session.inputs, 1, "a press and its release are one input")


func test_b_with_the_space_key() -> void:
	app.open("perfect")
	await tree.process_frame
	var k := InputEventKey.new()
	k.keycode = KEY_SPACE
	k.pressed = true
	tree.root.push_input(k)
	app.dev_advance(600)
	var u := k.duplicate()
	u.pressed = false
	tree.root.push_input(u)
	assert_eq(int(app.rules.outcomes["early"]), 1, "early by key")


func test_b_holding_forever_never_locks() -> void:
	app.open("perfect")
	await tree.process_frame
	_mouse(app.frame.play, true)
	app.dev_advance(10000)
	assert_eq(int(app.rules.outcomes["burnt"]), 1, "burnt by itself")
	_mouse(app.frame.play, false)
	_mouse(app.frame.play, true)
	assert_true(bool(app.rules.state()["heating"]), "the next press heats again")


func test_c_erupts_and_draws_under_the_cap() -> void:
	app.open("explosion")
	await tree.process_frame
	app.rules.level = 9   # the biggest eruption: 12,073 pieces
	for i in 8:
		_mouse(app.frame.play, true)
		_mouse(app.frame.play, false)
	assert_eq(app.rules.money, 12073, "paid at once")
	for i in 120:
		await tree.process_frame
	assert_true(app.frame.play.fx.peak <= PopFx.CAP, "drawn pieces %d <= %d" % [app.frame.play.fx.peak, PopFx.CAP])
	assert_true(app.frame.play.fx.peak >= 100, "and plenty of them (%d)" % app.frame.play.fx.peak)


func test_runs_are_isolated_between_experiments() -> void:
	app.open("click")
	await tree.process_frame
	for i in 40:
		_mouse(app.frame.play, true)
		_mouse(app.frame.play, false)
	app.buy()
	assert_eq(app.rules.level, 1, "A bought")
	app.back()
	app.open("explosion")
	await tree.process_frame
	assert_eq(app.rules.money, 0, "C starts at 0")
	assert_eq(app.rules.level, 0, "C at level 0")
	assert_eq(app.session.inputs, 0, "C's log is new")
	app.back()
	app.open("click")
	await tree.process_frame
	assert_eq(app.rules.money, 0, "A again from nothing")
	assert_eq(app.history.size(), 2, "two finished runs kept in memory for this visit")


func test_the_machine_is_redrawn_only_when_its_look_changes() -> void:
	app.open("click")
	await tree.process_frame
	await tree.process_frame
	var node: PopMachineNode = app.frame.play.machine_node
	var before := node.redraws
	for i in 60:
		await tree.process_frame
	assert_eq(node.redraws, before, "60 idle frames (it breathes) redraw nothing")
	for i in 10:
		_mouse(app.frame.play, true)
		_mouse(app.frame.play, false)
		await tree.process_frame
	assert_eq(node.redraws, before, "pops squash it by scale, no redraw")
	app.rules.money = 1000
	app.buy()
	await tree.process_frame
	await tree.process_frame
	assert_eq(node.redraws, before + 1, "an upgrade redraws it once")
