extends "res://tests/framework/test_case.gd"

## The farm as the player sees it: three cards (Sow, Water x3, Harvest), the
## lit one is what comes next, the water card counts its three waterings, the
## cooldown shows on the card, and the plot shows the crop's growth.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var buildings: BuildingSystem
var panel: ContextPanel
var farm := 0


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	buildings = sim.system(&"buildings")
	panel = main.get("panel")
	farm = buildings.place_instant("farm", Vector2i(1, 0))
	await tree.process_frame
	(main.get("selection") as SelectionController).select_building(farm)


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _lit() -> Array[bool]:
	var out: Array[bool] = []
	for c: Button in panel.cards:
		out.append(c.modulate.a > 0.9)
	return out


## A farm stage's work and its wait, from the data (ms).
func _work(i: int) -> int:
	return int(round(float(sim.data.building_type("farm")["cycle"]["stages"][i]["seconds"]) * work_scale(sim) * 1000.0))


func _wait() -> int:
	return int(float(sim.data.building_type("farm")["cycle"]["stages"][1]["cooldown"]) * 1000.0)


func test_three_cards_and_the_lit_one_follows_the_cycle() -> void:
	panel._refresh()
	assert_eq(panel.cards.size(), 3, "Sow, Water, Harvest")
	assert_eq(_lit(), [true, false, false] as Array[bool], "Sow is next")
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(_work(0))
	panel._refresh()
	assert_eq(_lit(), [false, true, false] as Array[bool], "then Water")
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(_work(1) + _wait())
	panel._refresh()
	assert_eq(_lit(), [false, false, true] as Array[bool], "then Harvest")


func test_the_ripening_is_shown_on_the_harvest_card() -> void:
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(_work(0))
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(_work(1) + _wait() / 2)
	LocaleService.apply("en")
	panel._refresh()
	var time: Label = panel.cards[2].find_child("Time", true, false)
	var left := int(ceil((_wait() - _wait() / 2) / 1000.0))
	assert_eq(time.text, "%ds left" % left, "the rest of the ripening")
	assert_true(panel.cards[2].disabled, "and the harvest cannot be pressed until then")


func test_the_plot_shows_the_crop_growing() -> void:
	var view: BuildingView = (main.get("building_views") as BuildingViews).view(farm)
	await tree.process_frame
	assert_false(view.overlay.visible, "bare soil before sowing")
	var looks: Array[String] = []
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(_work(0))
	await tree.process_frame
	looks.append(view._look)
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(_work(1))
	await tree.process_frame
	looks.append(view._look)
	sim.advance_ms(_wait())
	await tree.process_frame
	looks.append(view._look)
	assert_eq(looks, ["crop_seeds", "crop_leafy", "crop_ripe"] as Array[String], "seeds, the watered crop growing, ripe tomatoes")
