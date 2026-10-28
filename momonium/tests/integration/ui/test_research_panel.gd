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
	assert_eq(frame.tabs.map(func(t: Dictionary) -> String: return (t["button"] as Button).text), ["Farm", "Lumber", "Mine", "Lab", "Power", "General", "Points"], "a tab per discipline (Step 71: smelting and cars are Mine's, games the Lab's), general last, then the research points")
	var shown_tabs := frame.tabs.filter(func(t: Dictionary) -> bool: return (t["button"] as Button).visible).map(func(t: Dictionary) -> String: return (t["button"] as Button).text)
	assert_eq(shown_tabs, ["Farm", "Lab", "Points"], "a new island shows only what it can reach next")
	var view := _farm_view()
	assert_eq(view.cards.size(), (sim.system(&"research") as ResearchSystem).nodes("farm").size(), "every farm node has a card")
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	view.refresh()
	await tree.process_frame
	var shown: Array = view.cards.keys().filter(func(id: String) -> bool: return (view.cards[id] as Button).visible)
	assert_true(shown.size() >= 6, "Lv 6: much of the farm tree shows (%d)" % shown.size())
	for id: String in shown:
		for other: String in shown:
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
	# Lv 2: field expansion is open, bigger harvests (Lv 3) shows as next.
	var prog: ProgressionSystem = sim.system(&"progression")
	prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	view.refresh()
	await tree.process_frame
	_tap(view.cards["harvest_boost"])
	assert_eq(view.selected, "harvest_boost", "tapping a node selects it")
	assert_eq(view.need_lines("harvest_boost"), ["After Field expansion", "Unlocks at Lv. 3"] as Array[String], "what is missing: the parent, then a plain level (Step 70)")
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


## Step 70: a card held back by the player level says "Lv N" on a pill in
## its corner, unfaded and on the card; reaching the level opens it and the
## pill goes.
func test_a_level_gated_card_shows_its_level() -> void:
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	var view := _farm_view()
	view.refresh()
	await tree.process_frame
	var card: Button = view.cards["farm_expansion"]
	var gate := card.find_child("Gate", true, false) as Label
	assert_true(gate.visible, "locked by the level: the cue shows")
	assert_eq(gate.text, "Lv 2", "the level it opens at")
	assert_eq(gate.modulate, Color.WHITE, "not faded with the card")
	assert_eq(card.modulate, Color.WHITE, "the card fades its face, not its children")
	assert_true((card.get_node("Body") as Control).modulate.a < 1.0, "its face fades")
	var inside := Rect2(Vector2.ZERO, card.size)
	assert_true(inside.encloses(Rect2(gate.position, gate.size)), "the pill is on the card (%s in %s)" % [Rect2(gate.position, gate.size), inside])
	assert_true(gate.position.y < card.size.y * 0.3, "in its top corner")
	assert_true((card.find_child("Notes", true, false) as Label).get_parent().visible, "the notes still show what it will cost")
	var child: Button = view.cards["watering_efficiency"]
	assert_eq(view.gate_level("watering_efficiency"), 2, "a child waiting for its parent and Lv 2 says Lv 2 too")
	var prog: ProgressionSystem = sim.system(&"progression")
	prog.add_exp(prog.exp_needed_for(1), "test")
	view.refresh()
	assert_false(gate.visible, "Lv 2: open, the cue goes")
	assert_eq((card.get_node("Body") as Control).modulate, Color.WHITE, "and the card is no longer faded")
	assert_false((child.find_child("Gate", true, false) as Label).visible, "the child now waits only for its parent: no level cue")
	# A two-digit level still fits: the pill grows to the left.
	var narrow := gate.size.x
	gate.visible = true
	gate.text = "Lv 10"
	await tree.process_frame
	assert_true(gate.size.x > narrow, "it grew (%.0f -> %.0f)" % [narrow, gate.size.x])
	assert_true(inside.encloses(Rect2(gate.position, gate.size)), "'Lv 10' too (%s)" % Rect2(gate.position, gate.size))
