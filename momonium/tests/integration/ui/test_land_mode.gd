extends "res://tests/framework/test_case.gd"

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var mode: LandMode
var cams: CameraController
var proj: IsoProjection
var vp: Viewport


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	mode = main.get("land_mode")
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


func test_land_button_opens_and_closes_the_mode() -> void:
	main.call("_on_hud_action", &"land")
	assert_true(mode.active, "Land opens land mode")
	assert_true((main.get("land_preview") as LandPreview).active, "and shows the buyable cells")
	assert_eq((main.get("sim").system(&"land") as LandSystem).candidates().size(), 8, "eight around the start island")
	main.call("_on_hud_action", &"land")
	assert_false(mode.active, "pressing it again closes")


func test_choose_and_buy_a_cell() -> void:
	(sim.system(&"economy") as EconomySystem).earn(90, "test")
	mode.open()
	_tap_cell(Vector2i(2, 1))
	assert_eq(mode.chosen, Vector2i(2, 1), "a tap chooses the cell")
	assert_false(mode.buy_button.disabled, "affordable, so Buy is enabled")
	mode.confirm()
	assert_true(mode.last_result["ok"], "bought")
	assert_true((sim.system(&"world") as WorldSystem).is_owned(Vector2i(2, 1)), "the island grew")
	assert_eq((sim.system(&"economy") as EconomySystem).money, 50, "for $50")
	assert_true(mode.active, "the mode stays open for the next cell")
	assert_true(mode.buy_button.disabled, "nothing chosen now, so Buy waits")


func test_cannot_buy_what_you_cannot_afford() -> void:
	mode.open()
	_tap_cell(Vector2i(-1, 0))
	assert_eq(mode.chosen, Vector2i(-1, 0), "chosen")
	assert_true(mode.buy_button.disabled, "$10 cannot pay $50: Buy is disabled")
	mode.confirm()
	assert_eq((sim.system(&"world") as WorldSystem).owned_count(), 4, "nothing bought")


func test_taps_belong_to_land_mode_while_it_is_open() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var id := buildings.place_instant("farm", Vector2i(0, 0))
	await tree.process_frame
	mode.open()
	_tap_cell(Vector2i(0, 0))
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.IDLE, "a farm tapped in land mode does not start")
	assert_eq(mode.chosen, Vector2i(-99999, -99999), "and land cannot be chosen there")
	mode.close()
	_tap_cell(Vector2i(0, 0))
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.WORKING, "after closing, taps reach the world again")


func test_far_cells_cannot_be_chosen() -> void:
	mode.open()
	_tap_cell(Vector2i(4, 4))
	assert_eq(mode.chosen, Vector2i(-99999, -99999), "not adjacent: not a candidate")
	_tap_cell(Vector2i(2, 2))
	assert_eq(mode.chosen, Vector2i(-99999, -99999), "diagonal: not a candidate")
