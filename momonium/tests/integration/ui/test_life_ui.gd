extends "res://tests/framework/test_case.gd"

## Momo life on screen: the Life tab explains happiness part by part (and why
## something is shut), counts homes and who sleeps outdoors, and states the
## effect on work; homes and amenities say the same in their details.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var bs: BuildingSystem


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	bs = sim.system(&"buildings")
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _built(type: String, cell: Vector2i) -> int:
	var id := bs.place_instant(type, cell)
	sim.bus.emit(&"building_built", {"id": id, "type": type})
	return id


func test_the_life_tab_explains() -> void:
	_built("park", Vector2i(0, 0))
	var pub := _built("pub", Vector2i(1, 0))
	_built("villa", Vector2i(0, 1))
	main.call("_on_hud_action", &"status")
	var frame: PanelFrame = main.get("status_frame")
	frame.show_tab(4)
	var view: LifeView = main.get("life_view")
	assert_eq(view.happy_label.text, "10 / 100", "the park's 10")
	var lines := {}
	for r: Node in view.parts.get_children():
		lines[String(r.name)] = (r.get_node("Value") as Label).text
	assert_eq(lines["Part_%d" % pub], "shut: short of $%d" % int(sim.data.building_type("pub")["amenity"]["daily"]["money"]), "the pub says why it is shut: its day's food money")
	assert_eq((view.homes_row.get_node("Value") as Label).text, "1 / 2", "one Momo, a villa for two")
	assert_false(view.homeless.visible, "nobody outdoors")
	assert_eq((view.work_row.get_node("Value") as Label).text, "×0.91", "0.92 x (1 - 0.1 x 0.15)")


func test_homes_and_amenities_say_it_in_details() -> void:
	var villa := _built("villa", Vector2i(0, 0))
	var park := _built("park", Vector2i(1, 0))
	var view: BuildingDetailView = main.get("detail_view")
	main.call("open_details", villa)
	assert_eq(view.manager_label.text, "Residents 1/2", "who lives here")
	main.call("open_details", park)
	assert_eq(view.manager_label.text, "Open today · happiness +10", "what it gives")
