extends "res://tests/framework/test_case.gd"

## The first-run tutorial with real taps: it rings the Build button, the farm
## card (price shown), a free tile and the build button, waits for the farm,
## asks for the first sowing and watering, then points at where the mine and
## lumberyard are. It can be skipped, never blocks a tap, and replays from
## Settings.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var tut: Tutorial
var vp: Viewport


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	tut = main.get("tutorial")
	vp = main.get_viewport()
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _tap_at(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		vp.push_input(t, true)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = p
		m.pressed = pressed
		vp.push_input(m, true)


func _frame() -> void:
	await tree.process_frame
	await tree.process_frame


func test_not_started_under_tests_or_on_its_own() -> void:
	assert_false(tut.running, "no tutorial unless a fresh island asks for it")


func test_the_whole_path_with_taps() -> void:
	tut.start()
	await _frame()
	var hud: Hud = main.get("hud")
	assert_eq(tut.step, "open_build", "first: where buildings are made")
	assert_eq(tut.target, hud.buttons[&"build"].get_global_rect(), "the Build button is ringed")
	assert_eq(tut.text.text, "Buildings are made here", "with one short line")
	_tap_at(tut.target.get_center())
	await _frame()
	assert_eq(tut.step, "pick_farm", "the catalog is open")
	var menu: BuildMenu = main.get("build_menu")
	assert_eq(tut.target, menu.cards["farm"].get_global_rect(), "the farm card is ringed")
	assert_eq(tut.text.text, "Choose the farm · $10", "with its price")
	_tap_at(tut.target.get_center())
	await _frame()
	assert_eq(tut.step, "pick_tile", "placing the farm")
	var placement: PlacementMode = main.get("placement")
	assert_eq(tut.target2, placement.build_button.get_global_rect(), "the build button is ringed too")
	_tap_at(tut.target2.get_center())
	await _frame()
	assert_eq(tut.step, "wait_build", "building")
	sim.advance_ms(6000)
	await _frame()
	assert_eq(tut.step, "sow", "built: sow it")
	assert_true(tut.target2.size.x > 0.0, "the lit Sow card is ringed too (a Momo may stand in front of the farm)")
	_tap_at(tut.target2.get_center())
	await _frame()
	assert_eq(tut.step, "working", "the tap is sowing")
	sim.advance_ms(5000)
	await _frame()
	assert_eq(tut.step, "water", "then water")
	_tap_at(tut.target2.get_center())
	await _frame()
	assert_eq(tut.step, "working", "watering")
	sim.advance_ms(5000)
	await _frame()
	assert_eq(tut.step, "more", "first watering done")
	assert_true(tut.text.text.begins_with("Plants need time to drink"), "the wait is explained before the last pointer")
	assert_true(tut.ok_button.visible, "a Got it button now")
	_tap_at(hud.buttons[&"build"].get_global_rect().get_center())
	await _frame()
	assert_eq(tut.target, menu.cards["lumberyard"].get_global_rect(), "the lumberyard card is ringed")
	assert_eq(tut.target2, menu.cards["mine"].get_global_rect(), "and the mine card")
	assert_false(tut.bubble.get_global_rect().intersects(menu.get_global_rect()), "the line sits clear of the catalog")
	assert_eq((menu.cards["mine"].find_child("Unlock", true, false) as Label).text, "Opens at Lv 3", "the mine says when it opens")
	var done := [false]
	tut.finished.connect(func(skipped: bool) -> void: done[0] = not skipped)
	_tap_at(tut.ok_button.get_global_rect().get_center())
	assert_true(done[0], "finished")
	assert_false(tut.running, "and gone")
	assert_true(bool((main.get("settings") as SettingsStore).get_value("tutorial_done")), "remembered")


func test_skip_and_it_never_blocks() -> void:
	tut.start()
	await _frame()
	assert_eq(tut.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the overlay lets taps through")
	assert_eq(tut.bubble.mouse_filter, Control.MOUSE_FILTER_IGNORE, "so does its bubble")
	main.call("_on_hud_action", &"status")
	assert_true((main.get("status_frame") as PanelFrame).visible, "other things work while it runs")
	main.call("_on_hud_action", &"status")
	var skipped := [false]
	tut.finished.connect(func(s: bool) -> void: skipped[0] = s)
	_tap_at(tut.skip_button.get_global_rect().get_center())
	assert_true(skipped[0], "Skip ends it")
	assert_false(tut.running, "gone")


func test_it_follows_the_player_back() -> void:
	tut.start()
	main.call("_on_hud_action", &"build")
	await _frame()
	assert_eq(tut.step, "pick_farm", "catalog open")
	main.call("_on_hud_action", &"build")
	await _frame()
	assert_eq(tut.step, "open_build", "closed again: it points at the Build button again")


func test_replay_from_settings() -> void:
	(main.get("settings") as SettingsStore).set_value("tutorial_done", true)
	(sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	main.call("_on_hud_action", &"settings")
	await _frame()
	var view: SettingsView = main.get("settings_view")
	assert_eq(view.tutorial_button.text, "Replay tutorial", "the option is there")
	_tap_at(view.tutorial_button.get_global_rect().get_center())
	await _frame()
	assert_true(tut.running, "it starts again")
	assert_eq(tut.step, "open_build", "and waits for a new farm, not the old one")
	assert_false((main.get("settings_frame") as PanelFrame).visible, "settings closed out of the way")
