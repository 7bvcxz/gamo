extends "res://tests/framework/test_case.gd"

## Building by tapping the island: an empty tile opens four choices beside
## it, one tap builds; a building tapped shows a trash can, the can shows a
## check, and only the check pulls it down (half of what it cost comes back).

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var buildings: BuildingSystem
var strip: BuildStrip
var panel: ContextPanel
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
	strip = main.get("build_strip")
	panel = main.get("panel")
	cams = main.get("cameras")
	proj = main.get("projection")
	vp = main.get_viewport()
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _tap(p: Vector2) -> void:
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


func _tap_cell(cell: Vector2i) -> void:
	_tap(cams.world_to_screen(proj.cell_center(cell)))


func test_no_build_button_and_the_shop_only_hires() -> void:
	var hud: Hud = main.get("hud")
	assert_false(hud.buttons.has(&"build"), "no separate Build button: tap the ground")
	main.call("_on_hud_action", &"shop")
	var shop: ShopMenu = main.get("shop_menu")
	assert_true(shop.visible, "the shop opens")
	assert_eq(shop.cards.keys(), ["momo"], "with hiring only")


func test_an_empty_tile_opens_four_choices_beside_it() -> void:
	_tap_cell(Vector2i(1, 1))
	await tree.process_frame
	assert_true(strip.open, "tapping empty ground opens the choices")
	assert_eq(strip.cell, Vector2i(1, 1), "for that tile")
	assert_eq(strip.buttons.keys(), ["farm", "mine", "lumberyard", "research"], "farm, mine, lumberyard, lab")
	assert_false((strip.buttons["farm"] as Button).disabled, "the farm can be built at once")
	for t: String in ["mine", "lumberyard", "research"]:
		assert_true((strip.buttons[t] as Button).disabled, "%s waits for a level" % t)
	assert_eq((strip.buttons["mine"].find_child("Price", true, false) as Label).text, "Opens at Lv 3", "and says which")
	assert_eq((strip.buttons["farm"].find_child("Price", true, false) as Label).text, "$10", "the farm shows its price")
	var screen := main.get_viewport().get_visible_rect()
	assert_true(screen.encloses(strip.strip_rect()), "on screen")
	var tile := cams.world_to_screen(proj.cell_center(Vector2i(1, 1)))
	assert_true(strip.strip_rect().get_center().distance_to(tile) < 220.0, "near the tile")


func test_one_tap_builds() -> void:
	_tap_cell(Vector2i(1, 0))
	await tree.process_frame
	_tap((strip.buttons["farm"] as Button).get_global_rect().get_center())
	await tree.process_frame
	var id := buildings.building_at(Vector2i(1, 0))
	assert_true(id > 0, "a farm stands there")
	assert_false(strip.open, "the choices close")
	assert_eq(buildings.get_building(id)["state"], BuildingSystem.CONSTRUCTING, "under construction")
	assert_eq((main.get("selection") as SelectionController).selected_id, id, "and selected so its progress shows")
	assert_eq((sim.system(&"economy") as EconomySystem).money, 0, "paid $10")


func test_near_every_edge_it_stays_on_screen() -> void:
	var world: WorldSystem = sim.system(&"world")
	var screen := main.get_viewport().get_visible_rect()
	for c: Vector2i in world.owned_cells():
		strip.show_for(c)
		assert_true(screen.encloses(strip.strip_rect()), "tile %s: the choices fit on screen" % c)
	cams.camera.position += Vector2(500, 900)
	strip.show_for(Vector2i(0, 0))
	assert_true(screen.encloses(strip.strip_rect()), "even with the tile pushed off to a corner")


func test_tapping_elsewhere_closes_it() -> void:
	_tap_cell(Vector2i(1, 1))
	assert_true(strip.open, "open")
	_tap_cell(Vector2i(6, 6))
	assert_false(strip.open, "a tap on the sea closes it")
	_tap_cell(Vector2i(1, 1))
	main.call("_on_hud_action", &"status")
	assert_false(strip.open, "and so does opening a panel")


func test_occupied_tile_shows_info_and_the_trash() -> void:
	var farm := buildings.place_instant("farm", Vector2i(0, 1))
	_tap_cell(Vector2i(0, 1))
	await tree.process_frame
	assert_false(strip.open, "no choices on a built tile")
	assert_eq(panel.building_id, farm, "its information instead")
	assert_true(panel.trash_button.visible, "with the trash can")
	assert_false(panel.confirm_button.visible, "the check is not there yet")
	var screen := main.get_viewport().get_visible_rect()
	assert_true(panel.trash_button.get_global_rect().get_center().x > screen.size.x * 0.75, "bottom right")


func test_trash_then_check_demolishes_for_half() -> void:
	(sim.system(&"economy") as EconomySystem).earn(200, "test")
	(sim.system(&"progression") as ProgressionSystem).add_exp(500, "test")
	var r := sim.execute({"type": "building.place", "building": "lumberyard", "anchor": [1, 0]})
	sim.advance_ms(20000)
	var id := int(r["id"])
	sim.execute({"type": "momo.assign", "momo": 1, "building": id})
	(main.get("selection") as SelectionController).select_building(id)
	await tree.process_frame
	var money := (sim.system(&"economy") as EconomySystem).money
	_tap(panel.trash_button.get_global_rect().get_center())
	await tree.process_frame
	assert_true(panel.confirm_button.visible, "the trash shows a check")
	assert_true(panel.confirm_button.get_global_rect().end.y <= panel.trash_button.get_global_rect().position.y, "right above it")
	assert_false(buildings.get_building(id).is_empty(), "nothing pulled down yet")
	_tap(panel.trash_button.get_global_rect().get_center())
	await tree.process_frame
	assert_false(panel.confirm_button.visible, "the trash again backs out")
	assert_false(buildings.get_building(id).is_empty(), "still standing")
	_tap(panel.trash_button.get_global_rect().get_center())
	await tree.process_frame
	_tap(panel.confirm_button.get_global_rect().get_center())
	await tree.process_frame
	assert_true(buildings.get_building(id).is_empty(), "the check pulls it down")
	assert_eq((sim.system(&"economy") as EconomySystem).money - money, 40, "half of $80 back")
	assert_eq(int((sim.system(&"momo") as MomoSystem).get_momo(1)["assigned"]), 0, "its Momo is free")
	assert_eq((main.get("selection") as SelectionController).kind, "", "nothing selected")
	assert_false(panel.trash_button.visible, "and the trash goes away")
	_tap_cell(Vector2i(1, 0))
	assert_true(strip.open, "the tile is empty again: tap it to build")


func test_cancel_card_refunds_a_construction() -> void:
	_tap_cell(Vector2i(1, 0))
	await tree.process_frame
	_tap((strip.buttons["farm"] as Button).get_global_rect().get_center())
	await tree.process_frame
	assert_eq(panel.cards.size(), 2, "construction card and cancel card")
	panel.cards[1].pressed.emit()
	assert_eq((sim.system(&"economy") as EconomySystem).money, 10, "refunded in full")
	assert_eq(buildings.ids().size(), 0, "the construction is gone")


func test_the_sea_is_not_a_build() -> void:
	_tap_cell(Vector2i(2, 0))
	assert_false(strip.open, "a sea tile next to the island: no building choices")
	assert_eq((main.get("land_buyer") as LandBuyer).pending, Vector2i(2, 0), "its land preview instead")


func test_special_choices_and_back() -> void:
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	(sim.system(&"economy") as EconomySystem).earn(2000, "test")
	var inv: InventorySystem = sim.system(&"inventory")
	for item: String in ["stone", "wood", "copper_ingot"]:
		inv.add(item, 50, "test")
	_tap_cell(Vector2i(1, 1))
	await tree.process_frame
	assert_true(strip.special_button != null, "a fifth choice: Special")
	assert_eq((strip.special_button.find_child("Price", true, false) as Label).text, "0/1", "with its slots")
	_tap(strip.special_button.get_global_rect().get_center())
	await tree.process_frame
	assert_eq(strip.mode, "special", "the strip turns into the landmarks")
	assert_eq(strip.row.get_child(0), strip.back_button, "a back arrow first")
	assert_eq(strip.special_buttons.keys(), ["clock_tower", "school", "momo_monument"], "then the three")
	_tap(strip.special_buttons["school"].get_global_rect().get_center())
	await tree.process_frame
	var id := buildings.building_at(Vector2i(1, 1))
	assert_eq(String(buildings.get_building(id)["type"]), "school", "a school, through the usual build")
	assert_false(strip.open, "and the strip goes")
	_tap_cell(Vector2i(0, 1))
	await tree.process_frame
	_tap(strip.special_button.get_global_rect().get_center())
	await tree.process_frame
	assert_false(strip.special_buttons.has("school"), "the school standing: not offered")
	assert_true((strip.special_buttons["clock_tower"] as Button).disabled, "the slot is taken")
	assert_eq((strip.special_buttons["clock_tower"].find_child("Price", true, false) as Label).text, "No slot (1/1)", "and it says so")
	_tap(strip.back_button.get_global_rect().get_center())
	await tree.process_frame
	assert_eq(strip.mode, "core", "back: the five again")
	assert_true(strip.buttons.has("farm"), "")
