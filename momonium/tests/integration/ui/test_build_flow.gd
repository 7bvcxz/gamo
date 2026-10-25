extends "res://tests/framework/test_case.gd"

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var buildings: BuildingSystem
var placement: PlacementMode
var menu: BuildMenu
var cams: CameraController
var proj: IsoProjection
var vp: Viewport


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	buildings = sim.system(&"buildings")
	placement = main.get("placement")
	menu = main.get("build_menu")
	cams = main.get("cameras")
	proj = main.get("projection")
	vp = main.get_viewport()


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _tap_cell(cell: Vector2i) -> void:
	var p := cams.world_to_screen(proj.cell_center(cell))
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		vp.push_input(t, true)


func test_shop_lists_the_farm_and_picking_it_starts_placement() -> void:
	main.call("_on_hud_action", &"shop")
	assert_true(menu.visible, "Shop opens the building list")
	assert_true(menu.cards.has("farm"), "with the farm")
	(menu.cards["farm"] as Button).pressed.emit()
	assert_false(menu.visible, "picking closes the list")
	assert_true(placement.active, "and starts placing")
	assert_eq(placement.type, "farm", "a farm")
	assert_true(placement.check["ok"], "on a free cell to begin with")


func test_place_where_tapped_then_build() -> void:
	placement.open("farm")
	_tap_cell(Vector2i(1, 1))
	assert_eq(placement.anchor, Vector2i(1, 1), "the ghost follows the tap")
	assert_false(placement.build_button.disabled, "valid: Build enabled")
	placement.confirm()
	assert_false(placement.active, "placement closes after building")
	var id := buildings.building_at(Vector2i(1, 1))
	assert_true(id > 0, "a building stands there")
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.CONSTRUCTING, "under construction")
	assert_eq((main.get("selection") as SelectionController).selected_id, id, "and selected so its progress shows")
	assert_eq((sim.system(&"economy") as EconomySystem).money, 0, "paid")
	sim.advance_ms(5000)
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.IDLE, "built in 5 s")


func test_invalid_spots_say_why_and_cannot_build() -> void:
	buildings.place_instant("farm", Vector2i(0, 0))
	placement.open("farm")
	_tap_cell(Vector2i(0, 0))
	assert_eq(placement.check["reason"], "err.occupied", "occupied")
	assert_true(placement.build_button.disabled, "Build disabled")
	_tap_cell(Vector2i(3, 0))
	assert_eq(placement.check["reason"], "err.not_owned", "sea")
	placement.confirm()
	assert_eq(buildings.ids().size(), 1, "nothing was built")


func test_closing_placement_spends_nothing() -> void:
	placement.open("farm")
	placement.close_button.pressed.emit()
	assert_false(placement.active, "closed")
	assert_eq((sim.system(&"economy") as EconomySystem).money, 10, "no money spent")
	assert_false((main.get("placement_preview") as PlacementPreview).active, "no ghost left behind")


func test_cancel_card_refunds_a_construction() -> void:
	placement.open("farm")
	_tap_cell(Vector2i(1, 0))
	placement.confirm()
	await tree.process_frame
	var panel: ContextPanel = main.get("panel")
	assert_eq(panel.cards.size(), 2, "construction card and cancel card")
	panel.cards[1].pressed.emit()
	assert_eq((sim.system(&"economy") as EconomySystem).money, 10, "refunded")
	assert_eq(buildings.ids().size(), 0, "the construction is gone")


func test_taps_place_while_placing_and_modes_exclude_each_other() -> void:
	var id := buildings.place_instant("farm", Vector2i(0, 1))
	placement.open("farm")
	_tap_cell(Vector2i(0, 1))
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.IDLE, "a tap while placing does not start a farm")
	main.call("_on_hud_action", &"land")
	assert_false(placement.active, "opening land mode closes placement")
	assert_true((main.get("land_mode") as LandMode).active, "and land mode is open")
