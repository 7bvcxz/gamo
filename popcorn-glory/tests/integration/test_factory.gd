extends "res://tests/framework/test_case.gd"

## Step 16: the three-floor factory scene (#factory) -- layout on several
## screens, cooking only on the bottom floor, floors' details by tap and keys,
## and the layers redrawing only while something moves (QUALITY_GATES R-01).

const Main := preload("res://app/main.tscn")
var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	app.save_prefix = "test."
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame


func _view() -> Node:
	return app.frame.play


func _mouse(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	_view()._gui_input(e)


func _layout_ok(label: String) -> void:
	var v := _view()
	var full := Rect2(Vector2.ZERO, v.size)
	var floors := [v.floor_rect(0), v.floor_rect(1), v.floor_rect(2)]
	for i in 3:
		assert_true(full.encloses(floors[i]), "%s: floor %d inside the view" % [label, i])
		if i > 0:
			assert_false(floors[i].intersects(floors[i - 1]), "%s: floors %d and %d do not overlap" % [label, i - 1, i])
	var ring: Rect2 = v.extra_rects()["ring"]
	assert_true(floors[2].grow(2).encloses(ring), "%s: the ring is inside the kitchen %s %s" % [label, ring, floors[2]])
	if v.is_wide():
		assert_true(ring.size.y >= floors[2].size.y * 0.6, "%s: on landscape the ring fills most of the kitchen's height" % label)
	else:
		assert_true(ring.size.x >= v.scene_rect().size.x * 0.4, "%s: the ring is at least 40%% of the width (G-03)" % label)
	for i in 3:
		v.toggle_floor(i)
		assert_false(v.detail_rect().intersects(ring) and i == 2, "%s: the kitchen's detail never covers the ring" % label)
	v.toggle_floor(-1)


func test_the_floors_fit_and_never_cover_the_ring_on_every_screen() -> void:
	app.open("factory")
	await tree.process_frame
	# Canvas sizes as the stretch (canvas_items, expand, 720x1280) makes them: phones
	# 9:16 and 9:19.5, a 3:4 tablet, landscape 16:10 and 16:9.
	for sz: Vector2i in [Vector2i(720, 1280), Vector2i(720, 1558), Vector2i(960, 1280), Vector2i(2048, 1280), Vector2i(2276, 1280)]:
		app.frame.size = Vector2(sz)
		app.frame._layout()
		await tree.process_frame
		_layout_ok("%dx%d" % [sz.x, sz.y])
		if sz.x > sz.y:
			assert_true(app.frame.is_wide_layout(), "landscape is wide")
			assert_true(_view().scene_rect().size.x <= _view().size.x * 0.61, "floors on the left")
			assert_true(app.frame.upgrade_button.position.x >= app.frame.size.x * 0.6, "the card in the right column")


func test_cooking_only_on_the_bottom_floor_and_floors_open_details() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var mid: Rect2 = v.floor_rect(1)
	_mouse(mid.get_center(), true)
	_mouse(mid.get_center(), false)
	assert_eq(int(app.rules.presses), 0, "a tap on the packing floor does not cook")
	assert_eq(int(v.selected), 1, "it opens the packing floor's detail")
	_mouse(mid.get_center(), true)
	_mouse(mid.get_center(), false)
	assert_eq(int(v.selected), -1, "a second tap closes it")
	var c: Vector2 = v.machine_centre()
	_mouse(c, true)
	app.dev_advance(app.rules.window_start() + 60)
	_mouse(c, false)
	assert_eq(int(app.rules.presses), 1, "the kettle cooks")
	assert_eq(int(app.rules.outcomes["perfect"]), 1, "B's hold into the gold")
	assert_eq(app.rules.money, 10, "and pays as #stand does (Step 17 moves pay to the sale)")
	for k: int in [KEY_2, KEY_3, KEY_1]:
		var e := InputEventKey.new()
		e.keycode = k
		e.pressed = true
		v._unhandled_key_input(e)
	assert_eq(int(v.selected), 2, "keys 2, 3, 1: the kitchen's detail last")
	_mouse(v.badge_rect(0).get_center(), true)
	_mouse(v.badge_rect(0).get_center(), false)
	assert_eq(int(v.selected), 0, "the shop's badge opens the shop")


func test_the_layers_redraw_only_while_something_moves() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var c: Vector2 = v.machine_centre()
	_mouse(c, true)
	app.dev_advance(200)
	assert_true(bool(v._needs_redraw()), "heating redraws")
	app.dev_advance(app.rules.window_start())
	_mouse(c, false)
	v.last_input_ms = app.clock.now_ms   # (the app records input this way; the test sends to the view)
	# Pieces, the gain and the release mark fade on real frame time (MARK_S = 3 s).
	await tree.create_timer(3.3).timeout
	assert_false(bool(v._needs_redraw()), "idle after a cook: no redraw (heating %s fx %d gains %d flash %.2f mark %.1f hint %s squash %.3f jump %.2f once %s)" % [
		app.rules.state()["heating"], v.fx.alive, v._gains.size(), v._flash, v._mark_age, v._hint_visible(), v._squash, v._jump, v._redraw_once])
	app.dev_advance(21000)   # past 20 s idle: the hint's burst
	assert_true(bool(v._needs_redraw()), "the idle hint's burst redraws")
	app.dev_advance(7000)
	assert_false(bool(v._needs_redraw()), "and stops after its burst")


func test_the_stand_is_unchanged() -> void:
	app.open("stand")
	await tree.process_frame
	assert_true(bool(_view()._needs_redraw()), "the stand still redraws every frame as before")
	assert_false(app.frame.wide, "and is not wide")
