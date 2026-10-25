extends "res://tests/framework/test_case.gd"

## On the large demo island (Settings): what the camera does not see does not
## animate, small motions slow down when everything is tiny, nothing redraws
## every frame that has not changed, and the performance readout tells it.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var cams: CameraController
var views: BuildingViews
var momos: MomoViews


func before_each() -> void:
	Engine.set_meta("momonium_demo", "large")
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	Engine.remove_meta("momonium_demo")
	sim = main.get("sim")
	sim.time_scale = 0.0
	cams = main.get("cameras")
	views = main.get("building_views")
	momos = main.get("momo_views")
	LocaleService.apply("en")


func after_each() -> void:
	var settings: SettingsStore = main.get("settings")
	settings.set_value("perf_overlay", false)
	main.queue_free()
	await tree.process_frame


func _frames(n: int, dt: float = 1.0 / 60.0) -> void:
	for i in n:
		views._process(dt)
		momos._process(dt)
		await tree.process_frame


func test_the_large_demo_is_the_stress_island() -> void:
	assert_true(bool(main.get("in_demo")), "a demo, never saved")
	assert_eq(String(main.get("demo_kind")), "large", "the large one")
	assert_false(bool(main.get("persist")), "nothing of it is written")
	var types := {}
	for id: int in (sim.system(&"buildings") as BuildingSystem).ids():
		types[(sim.system(&"buildings") as BuildingSystem).get_building(id)["type"]] = true
	assert_eq(types.keys().size(), 4, "only the four kinds the player places")
	assert_true(views.views.size() > 150, "%d buildings" % views.views.size())
	assert_true(momos.actors.size() > 50, "%d Momo" % momos.actors.size())


func test_out_of_sight_does_not_animate() -> void:
	cams.frame_island()
	await _frames(2)
	var all := views.views.size()
	assert_eq(views.active_count(), all, "the whole island in view: everything moves")
	assert_eq(momos.awake_count(), momos.actors.size(), "every Momo too")
	# Close in on one corner.
	var size := cams.viewport_size()
	for i in 12:
		cams.zoom_at(1.5, size * 0.5)
	await _frames(2)
	assert_false(cams.far(), "close: full detail")
	assert_true(views.active_count() < all / 3, "close in: %d of %d buildings animate" % [views.active_count(), all])
	assert_true(momos.awake_count() < momos.actors.size(), "and %d of %d Momo" % [momos.awake_count(), momos.actors.size()])
	var sleeping: BuildingView = null
	for v: BuildingView in views.views.values():
		if not v.is_processing():
			sleeping = v
			break
	assert_false(sleeping.ring.visible, "an unseen building's ring is not even drawn")
	cams.frame_island()
	await _frames(2)
	assert_eq(views.active_count(), all, "back out: all of it again")


func test_far_out_small_motions_slow_down() -> void:
	var size := cams.viewport_size()
	for i in 8:
		cams.zoom_at(0.6, size * 0.5)
	await _frames(2)
	assert_true(cams.far(), "zoomed out, a tile is a few pixels")
	var a: MomoActor = momos.actors.values()[0]
	assert_eq(a.rig.lod_step, 2, "Momo limbs pose every other frame")
	var t := a.rig.time
	for i in 10:
		a.rig._process(0.1)
	assert_near(a.rig.time - t, 1.0, 0.0001, "with the time that passed: none lost")


func test_rings_redraw_only_when_they_move() -> void:
	cams.frame_island()
	await _frames(1)
	var idle: BuildingView = null
	for id: int in views.views:
		var b := (sim.system(&"buildings") as BuildingSystem).get_building(id)
		var v: BuildingView = views.views[id]
		if b["state"] == BuildingSystem.IDLE and not v._in_motion(b):
			idle = v
			break
	assert_true(idle != null, "an idle building")
	idle.far = false
	var before := idle.ring_draws
	for i in 60:
		idle._process(1.0 / 60.0)
	var n := idle.ring_draws - before
	assert_true(n >= 8 and n <= 11, "idle: about ten redraws a second, not sixty (%d)" % n)
	idle.celebrate()
	before = idle.ring_draws
	for i in 30:
		idle._process(1.0 / 60.0)
	assert_eq(idle.ring_draws - before, 30, "celebrating: every frame")


func test_editing_tiles_does_not_redo_the_route() -> void:
	var overlay: WatchOverlay = main.get("watch_overlay")
	overlay.show_for(1)
	overlay.editing = true
	await tree.process_frame
	var pulses := [0]
	var count := func() -> void: pulses[0] = int(pulses[0]) + 1
	overlay.draw.connect(count)
	var before := overlay.route_draws
	for i in 30:
		overlay._process(1.0 / 60.0)
		await tree.process_frame
	overlay.draw.disconnect(count)
	assert_true(int(pulses[0]) >= 25, "the tiles pulse every frame while edited (%d)" % pulses[0])
	assert_true(overlay.route_draws - before <= 3, "but the route was drawn %d times, not with each pulse" % (overlay.route_draws - before))
	overlay.clear()


func test_the_performance_readout() -> void:
	var perf: PerfOverlay = main.get("perf_overlay")
	assert_false(perf.visible, "off by default")
	assert_false(perf.is_processing(), "and costs nothing when off")
	main.get("settings_view").option_changed.emit("perf_overlay", true)
	assert_true(perf.visible and perf.is_processing(), "Settings turns it on")
	perf._process(1.0)
	var n := perf.numbers
	assert_eq(int(n["buildings"]), views.views.size(), "counts the buildings")
	assert_eq(int(n["momos"]), momos.actors.size(), "and the Momo")
	assert_true(perf.text.contains("fps") and perf.text.contains("Buildings"), "shown as text: %s" % perf.text)
	main.get("settings_view").option_changed.emit("perf_overlay", false)
	assert_false(perf.visible, "and off again")


func test_settings_offer_the_large_demo() -> void:
	var sv: SettingsView = main.get("settings_view")
	sv.in_demo = false
	sv.refresh()
	assert_true(sv.large_demo_button.visible, "outside a demo the large demo is offered")
	assert_eq(sv.large_demo_button.text, tr("settings.large_demo"), "")
	sv.in_demo = true
	sv.refresh()
	assert_false(sv.large_demo_button.visible, "inside one, only the way back")
