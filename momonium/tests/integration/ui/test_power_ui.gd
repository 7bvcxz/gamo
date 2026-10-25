extends "res://tests/framework/test_case.gd"

## Power on screen: no indicator until power is part of the island; then a
## pill with supply / draw (amber in a brownout) that opens the power panel;
## generator and user lines in the building details.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var bs: BuildingSystem
var hud: Hud


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	bs = sim.system(&"buildings")
	hud = main.get("hud")
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_no_power_no_indicator() -> void:
	await tree.process_frame
	assert_false(hud.power_pill.visible, "a new island shows nothing about power")


func test_the_pill_and_the_panel() -> void:
	bs.place_instant("water_wheel", Vector2i(0, 0))
	await tree.process_frame
	assert_true(hud.power_pill.visible, "a generator brings the pill")
	assert_eq(hud.power_label.text, "3 / 0 kW", "supply / draw")
	assert_true(hud.power_pill.size.y >= 44.0, "finger-sized")
	var vp := main.get_viewport()
	for pressed: bool in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = hud.power_pill.get_global_rect().get_center()
		m.pressed = pressed
		vp.push_input(m, true)
	var frame: PanelFrame = main.get("power_frame")
	assert_true(frame.visible, "a tap opens the power panel")
	var view: PowerView = main.get("power_view")
	assert_eq(view.head.text, "Supply 3 kW · Draw 0 kW · Share 100%", "the totals")
	assert_eq(view.gens.get_child_count(), 1, "one generator listed")
	assert_true((view.gens.get_child(0).get_child(0) as Label).text.contains("Steady"), "with what it depends on")


func test_brownout_turns_the_pill_amber() -> void:
	(sim.system(&"research") as ResearchSystem).completed["electric_furnace"] = 0
	(sim.system(&"research") as ResearchSystem).completed["electric_drill"] = 0
	bs.place_instant("water_wheel", Vector2i(0, 0))
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	var sm := bs.place_instant("smelter", Vector2i(0, 1))
	(sim.system(&"inventory") as InventorySystem).add("copper_ore", 2, "test")
	(sim.system(&"inventory") as InventorySystem).add("wood", 1, "test")
	sim.execute({"type": "building.tap", "id": mine})
	sim.execute({"type": "building.tap", "id": sm})
	await tree.process_frame
	assert_eq(hud.power_label.text, "3 / 4.5 kW", "more draw than supply")
	assert_ne(hud.power_pill.modulate, Color.WHITE, "amber, not white")


func test_details_show_power() -> void:
	(sim.system(&"research") as ResearchSystem).completed["electric_drill"] = 0
	var wheel := bs.place_instant("water_wheel", Vector2i(0, 0))
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	main.call("open_details", wheel)
	var view: BuildingDetailView = main.get("detail_view")
	assert_eq((view.power_row.get_node("Value") as Label).text, "Now 3 kW of 3", "a generator: now of most")
	main.call("open_details", mine)
	assert_eq((view.power_row.get_node("Value") as Label).text, "Uses 1.5 kW · gets 100%", "a user: draw and share")
