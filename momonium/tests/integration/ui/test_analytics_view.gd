extends "res://tests/framework/test_case.gd"

## The Stats tab: a few lines from the island's book -- money, output, each
## building's rate, Momo busy share, power -- and where work is stuck right
## now with what it needs.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_a_few_days_read_back() -> void:
	var view: AnalyticsView = main.get("analytics_view")
	assert_true(view != null, "the view exists")
	var bs: BuildingSystem = sim.system(&"buildings")
	var yard := bs.place_instant("lumberyard", Vector2i(1, 0))
	bs.place_instant("smelter", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": yard})
	sim.advance_ms(sim.clock.day_ms * 3)
	main.call("_on_hud_action", &"status")
	(main.get("status_frame") as PanelFrame).show_tab(5)
	view.refresh()
	await tree.process_frame
	assert_true(view.find_child("Money", true, false) != null, "money per day")
	assert_true(view.find_child("Item_wood", true, false) != null, "wood made")
	var stuck: Control = view.find_child("Stuck_*", true, false)
	assert_true(stuck != null, "a stuck building is listed")
	var text := ""
	for l: Node in stuck.find_children("*", "Label", true, false):
		text += (l as Label).text + " "
	assert_true(text.contains("Smelter") and text.contains("needs Copper ore 2"), "by name, with what it needs (%s)" % text)
