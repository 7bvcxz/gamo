extends "res://tests/framework/test_case.gd"

## The world's small life, by rule: windows glow only after dusk, pennants
## follow each family's mastery, a fish jumps by the shore now and then --
## somewhere different every few seconds and the same on every replay -- and
## a job done or a skill learned sparkles. All from game time.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_lights_only_after_dusk() -> void:
	assert_eq(BuildingView.night_strength(Color.WHITE), 0.0, "noon: no lights")
	var palette := SkyPalette.new(sim.data)
	var start := float(sim.data.get_value("art", "night_lights", {}).get("start", 0.25))
	var night: Color = palette.at(0.8)["ambient"]
	var noon: Color = palette.at(0.4)["ambient"]
	var sunset: Color = palette.at(0.62)["ambient"]
	assert_true(BuildingView.night_strength(night, start) > 0.4, "night: windows glow (%.2f)" % BuildingView.night_strength(night, start))
	assert_eq(BuildingView.night_strength(noon, start), 0.0, "the day's own light: none")
	assert_eq(BuildingView.night_strength(sunset, start), 0.0, "nor in the warm sunset")


func test_pennants_follow_mastery() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var mine := bs.place_instant("mine", Vector2i(0, 1))
	await tree.process_frame
	var views: BuildingViews = main.get("building_views")
	assert_eq(views.view(farm).pennant_tier(), -1, "a new farm: no pennant")
	var prog: ProgressionSystem = sim.system(&"progression")
	prog.mastery["farm"] = {"level": 3, "exp": 0}
	assert_eq(views.view(farm).pennant_tier(), 0, "farm mastery 3: bronze")
	prog.mastery["farm"] = {"level": 8, "exp": 0}
	assert_eq(views.view(farm).pennant_tier(), 2, "8: gold")
	assert_eq(views.view(mine).pennant_tier(), -1, "the mine's own mastery decides the mine's")
	var smelter := bs.place_instant("smelter", Vector2i(1, 1))
	prog.mastery["mine"] = {"level": 5, "exp": 0}
	await tree.process_frame
	assert_eq(views.view(smelter).pennant_tier(), 1, "a refitted mine flies its family's silver")


func test_a_fish_now_and_then_never_on_a_loop() -> void:
	var sea: SeaLife = main.get("sea_life")
	var cells := {}
	var splashes := 0
	for t in range(0, 600000, 400):
		sim.clock.now_ms = t
		var s := sea.current()
		if not s.is_empty():
			splashes += 1
			cells[s["cell"]] = true
	assert_true(splashes > 100, "ten minutes: plenty of splashes (%d samples)" % splashes)
	assert_true(cells.size() >= 4, "all round the shore (%d tiles)" % cells.size())
	sim.clock.now_ms = 123456
	var once := sea.current()
	assert_eq(sea.current(), once, "the same moment, the same splash")
	assert_true(sea.current().is_empty() or (world_frontier().has(sea.current()["cell"])), "always in the water beside the island")


func world_frontier() -> Array[Vector2i]:
	return (sim.system(&"world") as WorldSystem).frontier()


func test_work_and_learning_sparkle() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var school := bs.place_instant("school", Vector2i(0, 1))
	await tree.process_frame
	var views: BuildingViews = main.get("building_views")
	sim.bus.emit(&"task_completed", {"id": farm, "stage": "sow", "type": "farm", "worker": 1})
	assert_true(views.view(farm)._sparkle > 0.0, "a Momo's job: stars over the farm")
	sim.bus.emit(&"momo_skilled", {"id": 1, "type": "farm", "level": 1})
	assert_true(views.view(school)._sparkle > 0.0, "a skill learned: the School twinkles")
