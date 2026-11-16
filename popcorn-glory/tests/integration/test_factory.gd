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
	assert_eq(app.rules.money, 0, "the pop pays nothing (Step 17: money only from a sale)")
	assert_eq(int(app.rules.stats["lots"]), 1, "it made a lot")
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
	app.rules.queue.clear()               # a quiet shop: nothing moves but what the hand starts
	app.rules.next_arrival_ms = 1 << 40
	var c: Vector2 = v.machine_centre()
	_mouse(c, true)
	app.dev_advance(200)
	assert_true(bool(v._needs_redraw()), "heating redraws")
	app.dev_advance(app.rules.window_start())
	_mouse(c, false)
	app.dev_advance(8000)                 # the lot lifts and is packed (events: a redraw each)
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


## Step 18: the pictures follow the model's goods one by one (QUALITY_GATES G-13):
## every lot that rides the lift starts and ends once, every pack that goes to
## the shelf or to a customer starts once and ends once (at the sale), customers
## have one actor each, nothing lingers, a restart clears every journey.
func test_every_good_is_followed_once_from_start_to_end() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var c: Vector2 = v.machine_centre()
	for i in 5:
		_mouse(c, true)
		app.dev_advance(app.rules.window_start() + 60)
		_mouse(c, false)
		for k in 12:
			app.dev_advance(250)
			await tree.process_frame
	await tree.create_timer(1.0).timeout    # bags reach the shelf on real frame time
	app.dev_advance(30000)
	await tree.create_timer(1.0).timeout
	var starts := {}
	var ends := {}
	for e: Dictionary in v.cargo_log:
		var key := "%s:%d" % [e["kind"], e["id"]]
		if String(e["what"]) == "start" or String(e["what"]) == "serve":
			starts[key] = int(starts.get(key, 0)) + 1
		elif String(e["what"]) == "end":
			ends[key] = int(ends.get(key, 0)) + 1
	assert_true(starts.size() >= 5, "goods were followed (%d)" % starts.size())
	for key: String in starts.keys():
		assert_true(int(starts[key]) <= 2, "%s started at most twice (to the shelf, then to a customer)" % key)
		assert_eq(int(ends.get(key, 0)), int(starts[key]), "%s: every journey that started ended once" % key)
	var lots_lifted := 0
	for e: Dictionary in v.cargo_log:
		if String(e["kind"]) == "lot" and String(e["what"]) == "start":
			lots_lifted += 1
	assert_eq(lots_lifted, int(app.rules.stats["lots"]) - (0 if app.rules.glass.is_empty() else 1), "one lift journey per lot that left the glass")
	assert_eq(v.cargo.size(), int(app.rules.lift.size()) + (0 if app.rules.serving.is_empty() else 1), "no good lingers: only what is still moving in the model")
	assert_eq(v.customers.size(), app.rules.queue.size() + (0 if app.rules.serving.is_empty() else 1), "one actor per customer in the shop")
	app.restart()
	await tree.process_frame
	assert_eq(_view().cargo.size(), 0, "a restart clears the journeys")
	assert_eq(_view().cargo_log.size(), 0, "and their record")


func test_reduced_motion_moves_in_clear_steps() -> void:
	var a: Node2D = preload("res://variants/factory/actor.gd").new()
	a.start(PackedVector2Array([Vector2(0, 0), Vector2(0, 100), Vector2(100, 100)]), 1.0, true)
	var seen := {}
	for i in 50:
		a.step(0.021)
		seen[str(a.position.round())] = true
	for p: String in seen.keys():
		assert_true(p in ["(0.0, 0.0)", "(0.0, 100.0)", "(100.0, 100.0)"], "only waypoints, no glide (%s)" % p)
	assert_true(a.done, "it arrives")
	a.free()
