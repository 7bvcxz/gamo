extends "res://tests/framework/test_case.gd"

## The HUD at several real screen shapes: in the corners, never overlapping
## itself, inside the screen, off the island, and showing the simulation's
## numbers in the current language.

const MainScene := preload("res://scenes/main.tscn")
## Design-space viewports: phone (390x844), tall phone (360x800 -> 720x1600),
## tablet portrait, and a landscape desktop window.
const SIZES := [Vector2i(720, 1558), Vector2i(720, 1600), Vector2i(720, 960), Vector2i(2048, 1280)]

var holder: SubViewport
var main: Node


func _open(size: Vector2i) -> void:
	holder = SubViewport.new()
	holder.size = size
	tree.root.add_child(holder)
	main = MainScene.instantiate()
	holder.add_child(main)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	if holder != null:
		holder.queue_free()
		holder = null
		await tree.process_frame


func test_layout_fits_every_screen_shape() -> void:
	for size: Vector2i in SIZES:
		await _open(size)
		var hud: Hud = main.get("hud")
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var rects := hud.occupied_rects()
		for i in rects.size():
			assert_true(screen.encloses(rects[i]), "%s: element %d %s is on screen" % [size, i, rects[i]])
			for j in range(i + 1, rects.size()):
				assert_false(rects[i].intersects(rects[j]), "%s: elements %d and %d do not overlap" % [size, i, j])
		assert_true(hud.day_panel.get_rect().get_center().x < size.x * 0.5 and hud.day_panel.get_rect().get_center().y < size.y * 0.2, "%s: day panel top-left" % size)
		assert_true(hud.money_pill.get_rect().get_center().x > size.x * 0.5, "%s: money top-right" % size)
		for b: HudButton in hud.side_buttons:
			assert_true(b.get_rect().end.x > size.x - 120, "%s: %s on the right edge" % [size, b.action])
		for b: HudButton in hud.corner_buttons:
			assert_true(b.get_rect().position.x < size.x * 0.35 and b.get_rect().end.y > size.y - 120, "%s: %s bottom-left" % [size, b.action])
		await after_each()


func test_hud_stays_off_the_island() -> void:
	for size: Vector2i in SIZES:
		await _open(size)
		var hud: Hud = main.get("hud")
		var cams: CameraController = main.get("cameras")
		var island := cams.island_rect()
		var top_left := cams.world_to_screen(island.position)
		var bottom_right := cams.world_to_screen(island.end)
		var on_screen := Rect2(top_left, bottom_right - top_left)
		var covered := 0.0
		for r: Rect2 in hud.occupied_rects():
			covered += r.intersection(on_screen).get_area()
		assert_true(covered < on_screen.get_area() * 0.03, "%s: HUD covers %.1f%% of the island's frame" % [size, covered / on_screen.get_area() * 100.0])
		await after_each()


func test_values_come_from_the_simulation() -> void:
	await _open(SIZES[0])
	LocaleService.apply("en")
	var hud: Hud = main.get("hud")
	var sim: Simulation = main.get("sim")
	hud.refresh(true)
	assert_eq(hud._day_label.text, "Day 1", "day")
	assert_eq(hud._money_label.text, "10", "money")
	assert_eq(hud._exp_label.text, "0 / %d" % (sim.system(&"progression") as ProgressionSystem).exp_needed_for(1), "exact EXP")
	sim.time_scale = 0.0
	sim.advance_ms(12500)
	(sim.system(&"economy") as EconomySystem).earn(1234, "test")
	hud.refresh()
	assert_eq(hud._seconds_label.text, "12 / 30 sec", "seconds of the day")
	assert_eq(hud._money_label.text, "1,244", "money with separators")
	sim.advance_ms(20000)
	hud.refresh()
	assert_eq(hud._day_label.text, "Day 2", "the next day")


func test_language_switch_relabels_everything() -> void:
	await _open(SIZES[0])
	var hud: Hud = main.get("hud")
	LocaleService.apply("ko")
	await tree.process_frame
	assert_eq((hud.buttons[&"research"] as HudButton)._label.text, "연구", "Korean")
	LocaleService.apply("ja")
	await tree.process_frame
	assert_eq((hud.buttons[&"mailbox"] as HudButton)._label.text, "郵便箱", "Japanese")
	LocaleService.apply("zh_CN")
	await tree.process_frame
	assert_eq(hud._day_label.text, "第 1 天", "Chinese day label")
	assert_eq(hud.theme.default_font, LocaleService.font_for("zh_CN"), "and the Chinese face")
	LocaleService.apply("en")
	await tree.process_frame


func test_buttons_report_their_action_and_keep_the_camera_still() -> void:
	await _open(SIZES[0])
	var hud: Hud = main.get("hud")
	var camera: Camera2D = main.get("camera")
	var before := camera.position
	assert_false(hud.buttons.has(&"land"), "no land button: the sea is bought where it is")
	var b: HudButton = hud.buttons[&"status"]
	var p := b.get_global_rect().get_center()
	var t := InputEventScreenTouch.new()
	t.position = p
	t.pressed = true
	holder.push_input(t, true)
	var m := InputEventMouseButton.new()
	m.device = InputEvent.DEVICE_ID_EMULATION
	m.button_index = MOUSE_BUTTON_LEFT
	m.position = p
	m.pressed = true
	holder.push_input(m, true)
	t = t.duplicate()
	t.pressed = false
	holder.push_input(t, true)
	m = m.duplicate()
	m.pressed = false
	holder.push_input(m, true)
	await tree.process_frame
	assert_eq(main.get("hud_actions"), ["status"] as Array[String], "the button reported once")
	assert_eq(camera.position, before, "and the world did not move")


func test_the_clock_tower_dial() -> void:
	await _open(SIZES[0])
	var hud: Hud = main.get("hud")
	hud.refresh()
	assert_false(hud.burst_pill.visible, "no tower: no dial")
	var sim: Simulation = main.get("sim")
	(sim.system(&"buildings") as BuildingSystem).place_instant("clock_tower", Vector2i(1, 1))
	sim.advance_to(180000 + 12000)
	hud.refresh()
	assert_true(hud.burst_pill.visible, "a tower: a small dial")
	assert_true(hud.burst_active, "gold during a burst")
	assert_eq(hud.burst_text, "x2 0:18", "counting the burst down")
	sim.advance_to(180000 + 40000)
	hud.refresh()
	assert_false(hud.burst_active, "dim between bursts")
	assert_eq(hud.burst_text, "2:20", "counting to the next one")
	assert_true(hud.burst_pill.get_global_rect().size.x < 140.0, "and small")


func test_bigger_text_still_fits() -> void:
	# Text and buttons at their largest (x1.25) make the canvas 1/1.25 of the
	# screen: the smallest phones below, as the HUD then sees them.
	for size: Vector2i in [Vector2i(576, 768), Vector2i(576, 1246)]:
		await _open(size)
		var hud: Hud = main.get("hud")
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var rects := hud.occupied_rects()
		for i in rects.size():
			assert_true(screen.encloses(rects[i]), "%s: element %d %s is on screen" % [size, i, rects[i]])
			for j in range(i + 1, rects.size()):
				assert_false(rects[i].intersects(rects[j]), "%s: elements %d and %d do not overlap" % [size, i, j])
		await after_each()
