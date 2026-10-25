extends "res://tests/framework/test_case.gd"

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var cams: CameraController
var router: InputRouter
var vp: Viewport
var taps: Array = []


class GrabHandler:
	var zone: Rect2
	var log: Array[String] = []

	func try_begin_drag(screen: Vector2, _world: Vector2) -> bool:
		var ok := zone.has_point(screen)
		if ok:
			log.append("begin")
		return ok

	func drag_to(_screen: Vector2, _world: Vector2) -> void:
		log.append("move")

	func end_drag(_screen: Vector2, _world: Vector2) -> void:
		log.append("end")

	func cancel_drag() -> void:
		log.append("cancel")


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	cams = main.get("cameras")
	router = main.get("router")
	vp = main.get_viewport()
	taps.clear()
	router.tapped.connect(func(screen: Vector2, _w: Vector2) -> void: taps.append(screen))


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	vp.push_input(e, true)


func _drag(index: int, from: Vector2, to: Vector2, steps: int = 6) -> void:
	for i in range(1, steps + 1):
		var e := InputEventScreenDrag.new()
		e.index = index
		e.position = from.lerp(to, float(i) / steps)
		vp.push_input(e, true)


func test_island_is_framed_below_the_sky() -> void:
	var size := cams.viewport_size()
	var centre := cams.world_to_screen(cams.island_rect().get_center())
	assert_between(centre.y / size.y, 0.6, 0.76, "island centre sits in the lower part")
	assert_between(centre.x / size.x, 0.4, 0.6, "and in the middle horizontally")


func test_one_finger_drag_pans_and_ground_follows_the_finger() -> void:
	var start := cams.viewport_size() * Vector2(0.5, 0.75)
	var anchor := cams.screen_to_world(start)
	_touch(0, start, true)
	_drag(0, start, start + Vector2(60, -40))
	_touch(0, start + Vector2(60, -40), false)
	assert_true(cams.world_to_screen(anchor).distance_to(start + Vector2(60, -40)) < 1.0, "the world point under the finger moved with it")
	assert_eq(taps.size(), 0, "a drag is not a tap")


func test_tap_is_one_action_even_with_emulated_mouse() -> void:
	var p := cams.viewport_size() * 0.5
	_touch(0, p, true)
	_touch(0, p, false)
	var m := InputEventMouseButton.new()
	m.device = InputEvent.DEVICE_ID_EMULATION
	m.button_index = MOUSE_BUTTON_LEFT
	m.position = p
	m.pressed = true
	vp.push_input(m, true)
	m = m.duplicate()
	m.pressed = false
	vp.push_input(m, true)
	assert_eq(taps.size(), 1, "one tap, not two")


func test_small_wobble_is_still_a_tap() -> void:
	var p := cams.viewport_size() * 0.5
	var before := main.get("camera").position as Vector2
	_touch(0, p, true)
	_drag(0, p, p + Vector2(4, 3), 3)
	_touch(0, p + Vector2(4, 3), false)
	assert_eq(taps.size(), 1, "a few pixels of finger wobble is a tap")
	assert_eq(main.get("camera").position, before, "and does not pan")


func test_pinch_zooms_about_the_midpoint() -> void:
	var c := cams.viewport_size() * Vector2(0.5, 0.7)
	var anchor := cams.screen_to_world(c)
	var z0 := cams.zoom_level()
	_touch(0, c - Vector2(40, 0), true)
	_touch(1, c + Vector2(40, 0), true)
	for i in range(1, 7):
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = c - Vector2(40 + i * 10, 0)
		vp.push_input(e, true)
		e = InputEventScreenDrag.new()
		e.index = 1
		e.position = c + Vector2(40 + i * 10, 0)
		vp.push_input(e, true)
	_touch(0, c - Vector2(100, 0), false)
	_touch(1, c + Vector2(100, 0), false)
	assert_true(cams.zoom_level() > z0 * 1.5, "spreading two fingers zooms in (%.2f -> %.2f)" % [z0, cams.zoom_level()])
	assert_true(cams.world_to_screen(anchor).distance_to(c) < 2.0, "the point between the fingers stays put")
	assert_eq(taps.size(), 0, "a pinch is not a tap")


func test_mouse_wheel_zooms_at_the_cursor_and_drag_pans() -> void:
	var p := cams.viewport_size() * Vector2(0.4, 0.7)
	var anchor := cams.screen_to_world(p)
	var z0 := cams.zoom_level()
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	w.position = p
	w.pressed = true
	vp.push_input(w, true)
	assert_true(cams.zoom_level() > z0, "wheel up zooms in")
	assert_true(cams.world_to_screen(anchor).distance_to(p) < 1.0, "about the cursor")
	var cam_before: Vector2 = main.get("camera").position
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.position = p
	b.pressed = true
	vp.push_input(b, true)
	for i in range(1, 6):
		var mm := InputEventMouseMotion.new()
		mm.position = p + Vector2(i * 8, 0)
		vp.push_input(mm, true)
	b = b.duplicate()
	b.pressed = false
	b.position = p + Vector2(40, 0)
	vp.push_input(b, true)
	assert_true((main.get("camera").position as Vector2).x < cam_before.x, "dragging right moves the view left")


func test_limits_keep_the_island_reachable() -> void:
	for i in 40:
		cams.zoom_at(0.7, cams.viewport_size() * 0.5)
	assert_near(cams.zoom_level(), cams.min_zoom(), 0.0001, "zoom out stops at the limit")
	for i in 40:
		cams.zoom_at(1.4, cams.viewport_size() * 0.5)
	assert_near(cams.zoom_level(), cams.max_zoom(), 0.0001, "zoom in stops at the limit")
	cams.pan_screen(Vector2(100000, 100000))
	var limit := cams.island_rect().grow(cams.projection.tile_width * CameraController.MARGIN_TILES + cams.viewport_size().y)
	assert_true(limit.has_point((main.get("camera") as Camera2D).position), "a wild fling cannot lose the island")


func test_limits_grow_with_the_island() -> void:
	var world: WorldSystem = main.get("sim").system(&"world")
	var small := cams.island_rect().size
	for x in range(2, 12):
		world.add_land(Vector2i(x, 0))
		world.add_land(Vector2i(x, 1))
	cams.on_resize()
	assert_true(cams.island_rect().size.x > small.x * 3.0, "bounds follow land")
	assert_true(cams.min_zoom() < 0.5 * cams.max_zoom(), "a big island can be zoomed out to see it whole")


func test_drag_handlers_win_over_the_camera() -> void:
	var grab := GrabHandler.new()
	var p := cams.viewport_size() * Vector2(0.5, 0.7)
	grab.zone = Rect2(p - Vector2(20, 20), Vector2(40, 40))
	router.add_drag_handler(grab)
	var before: Vector2 = main.get("camera").position
	_touch(0, p, true)
	_drag(0, p, p + Vector2(80, 0))
	_touch(0, p + Vector2(80, 0), false)
	assert_eq(main.get("camera").position, before, "a claimed drag does not pan")
	assert_eq(grab.log[0], "begin", "handler got the drag")
	assert_eq(grab.log[-1], "end", "and its end")
	# A drag starting outside the handler's zone pans as usual.
	var q := p + Vector2(0, 120)
	_touch(0, q, true)
	_drag(0, q, q + Vector2(80, 0))
	_touch(0, q + Vector2(80, 0), false)
	assert_ne(main.get("camera").position, before, "unclaimed drag pans")


func test_second_finger_cancels_a_drag() -> void:
	var grab := GrabHandler.new()
	var p := cams.viewport_size() * Vector2(0.5, 0.7)
	grab.zone = Rect2(p - Vector2(20, 20), Vector2(40, 40))
	router.add_drag_handler(grab)
	_touch(0, p, true)
	_drag(0, p, p + Vector2(30, 0))
	_touch(1, p + Vector2(0, 100), true)
	_touch(1, p + Vector2(0, 100), false)
	_touch(0, p + Vector2(30, 0), false)
	assert_has(grab.log, "cancel", "a pinch cancels the drag it interrupted")
	assert_false(grab.log.has("end"), "and the drag is not completed")


func test_ui_takes_touches_before_the_world() -> void:
	var layer := CanvasLayer.new()
	var button := Button.new()
	button.position = Vector2(20, 20)
	button.size = Vector2(200, 120)
	layer.add_child(button)
	main.add_child(layer)
	await tree.process_frame
	var pressed := [0]
	button.pressed.connect(func() -> void: pressed[0] += 1)
	var before: Vector2 = main.get("camera").position
	# What the engine delivers for a finger on a phone: the touch, the drag, and
	# (emulate_mouse_from_touch) a synthetic mouse press/release with device -1.
	var p := Vector2(100, 60)
	_touch(0, p, true)
	vp.push_input(_emulated(p, true), true)
	_drag(0, p, p + Vector2(30, 0), 3)
	_touch(0, p + Vector2(30, 0), false)
	vp.push_input(_emulated(p + Vector2(30, 0), false), true)
	await tree.process_frame
	assert_eq(pressed[0], 1, "the button got the tap")
	assert_eq(taps.size(), 0, "the world did not")
	assert_eq(main.get("camera").position, before, "and a drag that started on the button did not pan")


func _emulated(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var m := InputEventMouseButton.new()
	m.device = InputEvent.DEVICE_ID_EMULATION
	m.button_index = MOUSE_BUTTON_LEFT
	m.position = pos
	m.pressed = pressed
	return m
