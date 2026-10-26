extends "res://tests/framework/test_case.gd"

## Taps on the world, through the real input router: buildings start work,
## tiles select, the sea deselects, and nothing a drag does counts as a tap.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var buildings: BuildingSystem
var cams: CameraController
var proj: IsoProjection
var sel: SelectionController
var vp: Viewport


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	# The Momo these cases are about (Step 53: a new island has none).
	with_starter_momo(sim)
	await tree.process_frame
	buildings = sim.system(&"buildings")
	cams = main.get("cameras")
	proj = main.get("projection")
	sel = main.get("selection")
	vp = main.get_viewport()


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _tap_cell(cell: Vector2i) -> void:
	_tap(cams.world_to_screen(proj.cell_center(cell)))


func _tap(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		vp.push_input(t, true)


func test_tapping_a_ready_building_starts_its_work() -> void:
	var id := buildings.place_instant("farm", Vector2i(1, 0))
	await tree.process_frame
	_tap_cell(Vector2i(1, 0))
	assert_eq(sel.kind, "building", "the farm is selected")
	assert_eq(sel.selected_id, id, "this farm")
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.WORKING, "and working, from the tap alone")
	assert_true((main.get("panel") as ContextPanel).card_rects().size() > 0, "its stage cards show")


## Step 45 (blind playtest): a working Momo stands on its farm, so a tap on
## the farm got the Momo, again and again. A second tap on the selected Momo
## reaches the building it stands on; the first still gets the Momo.
func test_a_second_tap_on_a_selected_momo_reaches_its_building() -> void:
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	var momos: MomoSystem = sim.system(&"momo")
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000)
	await tree.process_frame
	var actor := (main.get("momo_views") as MomoViews).actor(1)
	assert_true(momos.at_work(1), "the Momo is at its farm")
	var spot := actor.position + Vector2(0, -6)
	assert_eq(buildings.building_at(proj.cell_at(spot)), farm, "the point is on the farm")
	assert_eq((main.get("momo_views") as MomoViews).hit(spot), 1, "and on the Momo")
	_tap(cams.world_to_screen(spot))
	assert_eq(sel.kind, "momo", "first tap: the Momo")
	_tap(cams.world_to_screen(spot))
	assert_eq(sel.kind, "building", "second tap: through to the farm")
	assert_eq(sel.selected_id, farm, "this farm")
	_tap(cams.world_to_screen(spot))
	assert_eq(sel.kind, "momo", "a third: the Momo again (nothing is out of reach)")


func test_work_continues_when_something_else_is_selected() -> void:
	var a := buildings.place_instant("farm", Vector2i(1, 0))
	var b := buildings.place_instant("farm", Vector2i(0, 1))
	await tree.process_frame
	_tap_cell(Vector2i(1, 0))
	sim.advance_ms(2000)
	_tap_cell(Vector2i(0, 1))
	assert_eq(sel.selected_id, b, "the second farm is selected now")
	_tap_cell(Vector2i(0, 0))
	assert_eq(sel.kind, "tile", "then a tile")
	sim.advance_ms(3000)
	assert_eq(buildings.get_building(a)["completed"], 1, "the first farm finished while not selected")
	sim.advance_ms(2000)
	assert_eq(buildings.get_building(b)["completed"], 1, "and so did the second")


func test_tile_then_sea() -> void:
	_tap_cell(Vector2i(0, 0))
	assert_eq(sel.kind, "tile", "owned grass selects")
	assert_eq(sel.selected_cell, Vector2i(0, 0), "that cell")
	assert_true((main.get("marker") as SelectionMarker).shown, "and is outlined")
	_tap_cell(Vector2i(2, 0))
	assert_eq(sel.kind, "", "the sea next to the island is not a selection")
	assert_eq((main.get("land_buyer") as LandBuyer).pending, Vector2i(2, 0), "it is land to buy: previewed, a second tap buys")
	_tap_cell(Vector2i(9, 9))
	assert_eq(sel.kind, "", "open sea deselects")
	assert_false((main.get("panel") as ContextPanel).is_open(), "and closes the panel")


func test_tapping_a_busy_building_does_not_restart_it() -> void:
	var id := buildings.place_instant("farm", Vector2i(1, 1))
	await tree.process_frame
	_tap_cell(Vector2i(1, 1))
	var end_before: int = buildings.get_building(id)["task_end"]
	sim.advance_ms(int(float(sim.data.building_type("farm")["cycle"]["stages"][0]["seconds"]) * 500.0))
	_tap_cell(Vector2i(1, 1))
	assert_eq(sel.last_result["reason"], "err.busy", "the second tap is refused")
	assert_eq(buildings.get_building(id)["task_end"], end_before, "and the work keeps its end time")


func test_a_drag_across_a_building_is_not_a_tap() -> void:
	var id := buildings.place_instant("farm", Vector2i(1, 0))
	await tree.process_frame
	var p := cams.world_to_screen(proj.cell_center(Vector2i(1, 0)))
	var t := InputEventScreenTouch.new()
	t.position = p
	t.pressed = true
	vp.push_input(t, true)
	for i in range(1, 6):
		var d := InputEventScreenDrag.new()
		d.position = p + Vector2(i * 12, 0)
		vp.push_input(d, true)
	t = t.duplicate()
	t.pressed = false
	t.position = p + Vector2(60, 0)
	vp.push_input(t, true)
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.IDLE, "panning over a farm does not start it")
	assert_eq(sel.kind, "", "or select it")


func test_the_lit_card_starts_the_next_stage() -> void:
	var id := buildings.place_instant("farm", Vector2i(1, 0))
	await tree.process_frame
	sel.select_building(id)
	await tree.process_frame
	var panel: ContextPanel = main.get("panel")
	var card := panel.cards[0]
	assert_false(card.disabled, "the next stage's card is enabled while the farm is ready")
	card.pressed.emit()
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.WORKING, "pressing it starts the work")
	panel._refresh()
	assert_true(card.disabled, "and it disables while the work runs")
