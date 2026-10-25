extends "res://tests/framework/test_case.gd"

## The farm's details after research: varieties chosen by tap between cycles,
## the drip line shown as the worker while it waters, and the research in use
## written out.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var view: BuildingDetailView
var buildings: BuildingSystem
var research: ResearchSystem
var vp: Viewport
var farm := 0


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	view = main.get("detail_view")
	buildings = sim.system(&"buildings")
	research = sim.system(&"research")
	vp = main.get_viewport()
	LocaleService.apply("en")
	farm = buildings.place_instant("farm", Vector2i(1, 0))


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _tap(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = p
		m.pressed = pressed
		vp.push_input(m, true)


func _variety(v: String) -> Button:
	return view.variety_box.get_node("Variety_" + v)


func test_varieties_show_what_they_ask_and_give() -> void:
	main.call("open_details", farm)
	await tree.process_frame
	assert_true(view.variety_box.visible, "a farm shows what it can grow")
	assert_eq((_variety("base").find_child("Facts", true, false) as Label).text, "Water x3 · 1 a harvest", "the usual crop")
	assert_eq((_variety("millet").find_child("Facts", true, false) as Label).text, "Water x2 · 1 a harvest", "millet")
	assert_true(_variety("hardy").disabled, "hardy is locked")
	assert_true(_variety("base").size.y >= 52.0, "finger-sized")


func test_tap_a_variety_between_cycles() -> void:
	for id: String in ["farm_expansion", "harvest_boost", "seed_selection", "drought_millet"]:
		research.completed[id] = 0
	main.call("open_details", farm)
	await tree.process_frame
	_tap(_variety("millet"))
	assert_eq(buildings.variety_of(buildings.get_building(farm)), "millet", "the tap changed the crop")
	var ctx: ContextPanel = main.get("panel")
	(main.get("selection") as SelectionController).select_building(farm)
	await tree.process_frame
	ctx._refresh()
	var groups := buildings.action_groups(buildings.get_building(farm))
	assert_eq(groups.map(func(g: Dictionary) -> int: return int(g["count"])), [1, 2, 1], "sow, water x2, harvest")
	assert_eq(ctx.cards.size(), 3, "the stage cards follow the variety")
	sim.execute({"type": "building.tap", "id": farm})
	view.refresh()
	assert_false(view.variety_hint.text == "" or not view.variety_hint.visible, "mid-cycle the hint says when it can change")
	_tap(_variety("base"))
	assert_eq(buildings.variety_of(buildings.get_building(farm)), "millet", "and it does not change with seed in the ground")


func test_the_drip_line_shows_as_the_worker() -> void:
	for id: String in ["farm_expansion", "watering_efficiency", "watering_can", "drip_irrigation"]:
		research.completed[id] = 0
	main.call("open_details", farm)
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(5000)
	view.refresh()
	assert_eq(view.workers_box.get_child(0).get_meta("who"), "auto", "the drip line is watering")
	assert_eq((view.workers_box.get_child(0).find_child("Status", true, false) as Label).text, "Working", "at work")
	var lines: Array = view.research_box.get_children().map(func(c: Node) -> String: return (c as Label).text)
	assert_true(lines.has("Drip irrigation · Water by itself"), "the research in use, named (%s)" % [lines])
	assert_true(lines.has("Watering can · Water work time -40%"), "with what it does")
