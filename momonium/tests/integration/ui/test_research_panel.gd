extends "res://tests/framework/test_case.gd"

## The research menu: tabs per branch, locked nodes saying what they need,
## effects described from the data, starting by tap, the red dot when
## something can start, and the running/done states.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var frame: PanelFrame
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
	frame = main.get("research_frame")
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


func _farm_view() -> ResearchView:
	return frame.tabs[0]["view"]


func test_the_research_button_opens_the_tree() -> void:
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	assert_true(frame.visible, "the research menu opens")
	assert_eq(frame.tabs.map(func(t: Dictionary) -> String: return (t["button"] as Button).text), ["Farm", "Lumber", "Mine", "Smelting", "Power", "Games", "Cars", "General", "Points"], "a tab per branch, general last, then the research points")
	var view := _farm_view()
	assert_eq(view.cards.size(), (sim.system(&"research") as ResearchSystem).nodes("farm").size(), "every farm node has a card")
	for id: String in view.cards:
		for other: String in view.cards:
			if id != other:
				assert_false((view.cards[id] as Button).get_rect().intersects((view.cards[other] as Button).get_rect()), "%s and %s do not overlap" % [id, other])
	var root: Button = view.cards["farm_expansion"]
	var child: Button = view.cards["watering_efficiency"]
	assert_true(root.position.y < child.position.y, "the root sits above its children")
	assert_true(root.size.y >= 48.0, "nodes are a finger's size")


func test_a_locked_node_says_what_it_needs() -> void:
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	var view := _farm_view()
	_tap(view.cards["watering_efficiency"])
	assert_eq(view.selected, "watering_efficiency", "tapping a node selects it")
	assert_eq(view.need_lines("watering_efficiency"), ["After Field expansion", "A Momo's proposal"] as Array[String], "what is missing")
	assert_eq(view.effect_lines("watering_efficiency"), ["Wait after Water -25%"] as Array[String], "the effect, from the data")
	assert_eq(view.effect_lines("farm_expansion"), ["Harvest: Crops +1"] as Array[String], "field expansion")
	assert_true(view.start_button.disabled, "cannot start")
	assert_eq(view.needs_box.get_child_count(), 2, "both lines shown")


func test_start_by_tap_then_running_and_done() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	buildings.place_instant("research", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(250000)
	(sim.system(&"economy") as EconomySystem).earn(100, "test")
	(sim.system(&"inventory") as InventorySystem).add("notes", 3, "test")
	await tree.process_frame
	var hud: Hud = main.get("hud")
	assert_true(hud.buttons[&"research"].badge, "a red dot: the letter's topic is news (unread letter, Step 57)")
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	var view := _farm_view()
	assert_eq((main.get("research_frame") as PanelFrame).current_view(), view, "Research opens on the branch with the news")
	assert_true(view.fresh.has("farm_expansion"), "a dot on the new topic's card")
	assert_true((main.get("research_frame") as PanelFrame).tab_dot(0), "and on its tab")
	await tree.process_frame
	assert_false(hud.buttons[&"research"].badge, "shown: the button's dot goes")
	_tap(view.cards["farm_expansion"])
	assert_false(view.start_button.disabled, "ready")
	assert_eq(view.start_button.text, "Start research", "says so")
	assert_true(view.start_button.size.y >= 52.0, "a big button")
	_tap(view.start_button)
	var research: ResearchSystem = sim.system(&"research")
	assert_eq(research.state_of("farm_expansion"), "active", "the tap started it")
	assert_true(view.start_button.text.begins_with("Researching"), "running (%s)" % view.start_button.text)
	await tree.process_frame
	assert_false((main.get("hud") as Hud).buttons[&"research"].badge, "nothing new: no dot")
	sim.advance_ms(60000)
	view.refresh()
	assert_true(view.start_button.text.begins_with("Research Lv 2"), "done -- and the next level is offered (%s)" % view.start_button.text)
	assert_true(view.detail_name.text.ends_with("Lv 1 / 5"), "with its level")


func test_lack_of_a_lab_is_named() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(250000)
	main.call("_on_hud_action", &"research")
	var view := _farm_view()
	view.selected = "farm_expansion"
	view.refresh()
	assert_eq(view.start_button.text, "Build a research lab", "the button says what is missing")


func test_research_and_the_other_panels_take_turns() -> void:
	main.call("_on_hud_action", &"research")
	main.call("_on_hud_action", &"mailbox")
	assert_false(frame.visible, "the mailbox replaces research")
	main.call("_on_hud_action", &"research")
	assert_false((main.get("mail_frame") as PanelFrame).visible, "and the other way round")
