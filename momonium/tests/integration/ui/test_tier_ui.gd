extends "res://tests/framework/test_case.gd"

## The tier on screen: the Status tab names it, lists the next tier's
## milestones with have / need, lights Status when promotion is possible,
## promotes with a tap and celebrates.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var vp: Viewport


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
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


func test_milestones_then_a_tap_to_promote() -> void:
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	var tv: TierView = (main.get("status_panel") as StatusPanel).tier_view
	assert_eq(tv.head.text, "Village · Special slots 1", "a village, one special slot")
	assert_eq(tv.next_label.text, "Next: City", "what comes next")
	assert_true(tv.promote_button.disabled, "not yet")
	var tiles: Control = tv.list.get_node("Need_tiles")
	assert_true((tiles.get_child(1) as Label).text == "4 / 9", "4 of 9 tiles (%s)" % (tiles.get_child(1) as Label).text)
	var hud: Hud = main.get("hud")
	assert_false(hud.buttons[&"status"].badge, "no dot on Status yet")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	(sim.system(&"momo") as MomoSystem).add_momo(Vector2(0.5, 1.5))
	(sim.system(&"momo") as MomoSystem).add_momo(Vector2(1.5, 0.5))
	(sim.system(&"research") as ResearchSystem).completed["momo_training"] = 0
	(sim.system(&"research") as ResearchSystem).bought["momo_training"] = 3
	(sim.system(&"economy") as EconomySystem).earn(1500, "sale")
	hud.refresh()
	tv.refresh()
	assert_true(hud.buttons[&"status"].badge, "every milestone met: a dot on Status")
	assert_false(tv.promote_button.disabled, "and the button opens")
	assert_eq(tv.promote_button.text, "Become a City!", "")
	_tap(tv.promote_button)
	await tree.process_frame
	assert_eq((sim.system(&"tiers") as TierSystem).tier_name(), "city", "a city")
	var party: TierCelebration = main.get("celebration")
	assert_true(party.playing(), "celebrated")
	assert_eq(party.text, "Now a City", "with its new name")
	assert_eq(party.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never in the way of a tap")
