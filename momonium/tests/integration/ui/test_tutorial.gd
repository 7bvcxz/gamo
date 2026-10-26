extends "res://tests/framework/test_case.gd"

## The first-run tutorial with real taps. On a new player's island it rings
## the ripe crop first (the first tap is a harvest and its money, Step 50),
## then sowing and watering it; on an island without one it rings an empty
## tile, then the farm among the four choices beside it (price shown), waits
## for the farm, asks for the first sowing and watering. Then a Momo and its
## tiles, then that any empty tile builds the others and how one comes down.
## It can be skipped, never blocks a tap, and replays from Settings.

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


## How long a farm stage (or its building) takes, from the data (ms).
func _ms(i: int) -> int:
	var st: Dictionary = sim.data.building_type("farm")["cycle"]["stages"][i]
	return int((float(st["seconds"]) + float(st.get("cooldown", 0.0))) * 1000.0)


func test_a_new_island_starts_with_the_ripe_crop() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_ready("farm", Vector2i(0, 0), "harvest")
	tut.start()
	await _frame()
	assert_eq(tut.step, "harvest", "first: the ripe crop")
	assert_eq(tut.text.text, "Tap the ripe crop", "with one short line")
	var money := (sim.system(&"economy") as EconomySystem).money
	_tap_at(tut.target.get_center())
	await _frame()
	assert_eq(tut.step, "working", "the tap is the harvest")
	sim.advance_ms(_ms(2))
	await _frame()
	assert_true((sim.system(&"economy") as EconomySystem).money > money, "and its money")
	assert_eq(tut.step, "sow", "then sow it again")
	_tap_at(tut.target2.get_center())
	await _frame()
	sim.advance_ms(_ms(0))
	await _frame()
	assert_eq(tut.step, "water", "then water")
	_tap_at(tut.target2.get_center())
	await _frame()
	sim.advance_ms(_ms(1))
	await _frame()
	assert_eq(tut.step, "momo_select", "then a Momo")
	assert_eq(int(bs.get_building(farm)["completed"]), 3, "three stages by hand")


func test_not_started_under_tests_or_on_its_own() -> void:
	assert_false(tut.running, "no tutorial unless a fresh island asks for it")


func test_the_whole_path_with_taps() -> void:
	tut.start()
	await _frame()
	assert_eq(tut.step, "pick_tile", "first: tap the ground")
	var cell := tut.suggested_tile()
	assert_true((sim.system(&"world") as WorldSystem).is_buildable(cell), "the ringed tile is free")
	assert_eq(tut.text.text, "Tap an empty tile", "with one short line")
	_tap_at(tut.target.get_center())
	await _frame()
	assert_eq(tut.step, "pick_farm", "the four choices are open")
	var strip: BuildStrip = main.get("build_strip")
	assert_eq(strip.cell, cell, "on the ringed tile")
	assert_eq(tut.target, strip.buttons["farm"].get_global_rect(), "the farm is ringed")
	assert_eq(tut.text.text, "Build a farm here · $10", "with its price")
	assert_false(tut.bubble.get_global_rect().intersects(strip.strip_rect()), "the line sits clear of the choices")
	_tap_at(tut.target.get_center())
	await _frame()
	assert_eq(tut.step, "wait_build", "building")
	sim.advance_ms(int(float(sim.data.building_type("farm")["build_seconds"]) * 1000.0))
	await _frame()
	assert_eq(tut.step, "sow", "built: sow it")
	assert_true(tut.target2.size.x > 0.0, "the lit Sow card is ringed too (a Momo may stand in front of the farm)")
	_tap_at(tut.target2.get_center())
	await _frame()
	assert_eq(tut.step, "working", "the tap is sowing")
	sim.advance_ms(_ms(0))
	await _frame()
	assert_eq(tut.step, "water", "then water")
	_tap_at(tut.target2.get_center())
	await _frame()
	assert_eq(tut.step, "working", "watering")
	sim.advance_ms(int(float(sim.data.building_type("farm")["cycle"]["stages"][1]["seconds"]) * 1000.0))
	await _frame()
	# The Momo, its pencil, a tile: what each Momo looks after.
	assert_eq(tut.step, "momo_select", "first watering done: now a Momo")
	assert_eq(tut.text.text, "Tap a Momo", "")
	assert_true(tut.target.size.x > 0.0, "a Momo is ringed")
	(main.get("selection") as SelectionController).deselect()
	_tap_at(tut.target.get_center())
	await _frame()
	assert_eq(tut.step, "momo_pencil", "a Momo selected: its pencil")
	assert_eq(tut.target, (main.get("watch_editor") as WatchEditor).pencil.get_global_rect(), "the pencil is ringed")
	_tap_at(tut.target.get_center())
	await _frame()
	assert_eq(tut.step, "momo_edit", "editing")
	assert_true(tut.text.text.begins_with("Tap tiles or drag across them:"), "how, with the count (%s)" % tut.text.text)
	_tap_at((main.get("cameras") as CameraController).world_to_screen((main.get("projection") as IsoProjection).cell_center(Vector2i(0, 1))))
	await _frame()
	# The sea (Step 50), once the island is nearly full: quiet until then.
	(main.get("watch_editor") as WatchEditor).end_edit()
	await _frame()
	assert_eq(tut.step, "later", "a tile edited: quiet while the island has room")
	assert_false(tut.bubble.visible, "nothing on screen")
	assert_true(tut.running, "but not over")
	var world: WorldSystem = sim.system(&"world")
	while world.buildable_cells().size() > 1:
		(sim.system(&"buildings") as BuildingSystem).place_instant("research", world.buildable_cells()[0])
	await _frame()
	assert_eq(tut.step, "land", "one tile left: the sea")
	assert_true(tut.bubble.visible, "said again")
	var land: LandSystem = sim.system(&"land")
	var economy: EconomySystem = sim.system(&"economy")
	var preview: LandPreview = main.get("land_preview")
	assert_eq(tut.target, tut._cell_rect(preview.grow_spot()), "the tile the island would grow into is ringed")
	if not economy.can_afford(land.next_cost()):
		assert_eq(tut.text.text, "The island can grow here · $%d" % land.next_cost(), "with its price while it is too dear")
		economy.earn(land.next_cost(), "test")
		await _frame()
	assert_eq(tut.text.text, "Tap the glowing sea to grow the island", "affordable: tap it")
	assert_eq(preview.invitation(), preview.grow_spot(), "the ringed tile is the glowing one")
	(main.get("selection") as SelectionController).deselect()
	var sea := tut.target.get_center()
	_tap_at(sea)
	await _frame()
	_tap_at(sea)
	await _frame()
	assert_false(land.purchases.is_empty(), "two taps: the island grew")
	assert_eq(tut.step, "more", "then the last step")
	assert_true(tut.text.text.begins_with("Watered, the crop ripens"), "the wait is explained before the last pointer")
	assert_true(tut.text.text.contains("Any empty tile builds"), "then where the others are built")
	assert_true(tut.text.text.contains("half comes back"), "and how one comes down")
	assert_true(tut.ok_button.visible, "a Got it button now")
	assert_true(tut.target.size.x > 0.0 or tut.target2.size.x > 0.0, "something is ringed")
	(main.get("selection") as SelectionController).deselect()
	_tap_at((main.get("cameras") as CameraController).world_to_screen((main.get("projection") as IsoProjection).cell_center(tut.suggested_tile())))
	await _frame()
	assert_eq(tut.target, strip.buttons["lumberyard"].get_global_rect(), "an empty tile tapped: the lumberyard is ringed")
	assert_eq(tut.target2, strip.buttons["mine"].get_global_rect(), "and the mine")
	assert_eq((strip.buttons["mine"].find_child("Price", true, false) as Label).text, "Opens at Lv 3", "the mine says when it opens")
	var done := [false]
	tut.finished.connect(func(skipped: bool) -> void: done[0] = not skipped)
	_tap_at(tut.ok_button.get_global_rect().get_center())
	assert_true(done[0], "finished")
	assert_false(tut.running, "and gone")
	assert_true(bool((main.get("settings") as SettingsStore).get_value("tutorial_done")), "remembered")


func test_the_trash_is_shown_at_the_end() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	tut.start()
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	bs.get_building(farm)["completed"] = 2
	tut._momo_done = true
	tut._land_done = true
	(main.get("selection") as SelectionController).select_building(farm)
	await _frame()
	var panel: ContextPanel = main.get("panel")
	assert_eq(tut.step, "more", "the last step")
	assert_eq(tut.target, panel.trash_button.get_global_rect(), "a building selected: its trash can is ringed")
	for r: Rect2 in [panel.trash_button.get_global_rect(), panel.confirm_button.get_global_rect()]:
		assert_false(tut.bubble.get_global_rect().intersects(r), "the line keeps clear of the trash and where its check appears")
	for c: Button in panel.cards:
		assert_false(c.get_global_rect().intersects(panel.trash_button.get_global_rect()), "the trash is on no card")


func test_the_ringed_tile_has_no_momo_on_it() -> void:
	var momos: MomoSystem = sim.system(&"momo")
	var world: WorldSystem = sim.system(&"world")
	for c: Vector2i in world.owned_cells():
		momos.get_momo(1)["from"] = [c.x + 0.5, c.y + 0.5]
		momos.get_momo(1)["to"] = [c.x + 0.5, c.y + 0.5]
		var p := momos.position_of(1)
		assert_ne(tut.suggested_tile(), Vector2i(floori(p.x), floori(p.y)), "Momo on %s: another tile is ringed" % c)


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
	var strip: BuildStrip = main.get("build_strip")
	strip.show_for(Vector2i(1, 1))
	await _frame()
	assert_eq(tut.step, "pick_farm", "choices open")
	strip.close()
	await _frame()
	assert_eq(tut.step, "pick_tile", "closed again: it points at a tile again")


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
	assert_eq(tut.step, "pick_tile", "and waits for a new farm, not the old one")
	assert_false((main.get("settings_frame") as PanelFrame).visible, "settings closed out of the way")
