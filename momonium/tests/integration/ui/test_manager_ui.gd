extends "res://tests/framework/test_case.gd"

## The manager on screen: priority buttons once management is researched,
## set by tap; the office says who manages; a Momo's card shows its skill,
## where it worked before, and lets the player pin it or hand it over.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var bs: BuildingSystem
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
	bs = sim.system(&"buildings")
	vp = main.get_viewport()
	LocaleService.apply("en")


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


func test_priority_buttons_after_management() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	main.call("open_details", farm)
	var view: BuildingDetailView = main.get("detail_view")
	assert_false(view.priority_box.visible, "no priorities before there can be a manager")
	(sim.system(&"research") as ResearchSystem).completed["management"] = 0
	view.refresh()
	await tree.process_frame
	assert_true(view.priority_box.visible, "management researched: priorities")
	_tap(view.priority_box.get_node("P_high"))
	assert_eq(bs.get_building(farm)["priority"], "high", "set by a tap")
	assert_true((view.priority_box.get_node("P_high") as Button).size.y >= 44.0, "finger-sized")


func test_the_office_says_who_manages() -> void:
	(sim.system(&"research") as ResearchSystem).completed["management"] = 0
	var office := bs.place_instant("office", Vector2i(0, 0))
	main.call("open_details", office)
	var view: BuildingDetailView = main.get("detail_view")
	assert_eq(view.manager_label.text, "No manager at work", "empty office")
	sim.execute({"type": "momo.assign", "momo": 1, "building": office})
	sim.advance_ms(5000)
	view.refresh()
	assert_eq(view.manager_label.text, "Managing · 0 moves", "a Momo at the desk")


func test_the_momo_card() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	(sim.system(&"momo") as MomoSystem).get_momo(1)["experience"]["farm"] = 12
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	(main.get("selection") as SelectionController).select_momo(1)
	await tree.process_frame
	var card: MomoPanel = main.get("momo_panel")
	assert_eq(card.skill_label.text, "Farm skill 1 · 12 jobs", "skill where it works")
	assert_eq(card.pin_button.text, "Stays here", "placed by the player: stays")
	_tap(card.pin_button)
	assert_false((sim.system(&"momo") as MomoSystem).get_momo(1)["pinned"], "a tap hands it to the manager")
	assert_eq(card.pin_button.text, "Manager may move", "and says so")
