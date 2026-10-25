extends "res://tests/framework/test_case.gd"

## The sale and the research points on screen: the economy tab names the
## island's worth and opens the sale; selling needs the level, then two taps;
## the new island opens on its research points, where - and + place them and
## Confirm applies them.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var vp: Viewport


func _open_main() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	vp = main.get_viewport()


func before_each() -> void:
	LocaleService.apply("en")
	await _open_main()


func after_each() -> void:
	if Engine.has_meta("momonium_handoff"):
		Engine.remove_meta("momonium_handoff")
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


func _to_level(lv: int) -> void:
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < lv:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")


func test_the_economy_tab_opens_the_sale() -> void:
	main.call("_on_hud_action", &"status")
	(main.get("status_frame") as PanelFrame).show_tab(2)
	await tree.process_frame
	var eco: EconomyView = main.get("economy_view")
	assert_true(eco.sale_button.text.begins_with("Island worth $"), "the worth on the button (%s)" % eco.sale_button.text)
	_tap(eco.sale_button)
	await tree.process_frame
	assert_true((main.get("sale_frame") as PanelFrame).visible, "it opens the sale")
	var view: SaleView = main.get("sale_view")
	assert_true(view.sell_button.disabled, "a new island cannot be sold")
	assert_eq(view.sell_button.text, "Can be sold from Lv 5", "and says when")
	assert_true(view.find_child("Fam_lumberyard", true, false) != null, "the worth by the four families")
	assert_true(view.reset_label.text.contains("research levels"), "what starts over")
	assert_true(view.keep_label.text.contains("Legacy points"), "what stays")


func test_two_taps_sell_and_the_new_island_opens_on_points() -> void:
	_to_level(6)
	var rs: ResearchSystem = sim.system(&"research")
	rs.bought["momo_training"] = 2
	rs.completed["momo_training"] = 0
	rs.unlocked["momo_training"] = true
	main.call("open_sale")
	await tree.process_frame
	var view: SaleView = main.get("sale_view")
	assert_false(view.sell_button.disabled, "Lv 6: it can be sold")
	_tap(view.sell_button)
	assert_true(view.confirming, "the first tap asks again")
	assert_false(Engine.has_meta("momonium_handoff"), "nothing sold yet")
	_tap(view.cancel_button)
	assert_false(view.confirming, "cancel puts it back")
	_tap(view.sell_button)
	_tap(view.sell_button)
	assert_true(Engine.has_meta("momonium_handoff"), "the second tap sells")
	var next: Simulation = Engine.get_meta("momonium_handoff")
	assert_eq((next.system(&"research") as ResearchSystem).rp_earned, 2, "two research levels: two points")
	# The game starts again on the new island.
	main.queue_free()
	await tree.process_frame
	await _open_main()
	assert_eq(main.get("sim"), next, "the new island")
	await tree.process_frame
	await tree.process_frame
	var frame: PanelFrame = main.get("research_frame")
	var rp: RpView = main.get("rp_view")
	assert_true(frame.visible and frame.current_view() == rp, "opened on its research points")
	assert_eq(rp.head.text, "Research points 2 / 2", "two to place")
	var row: Control = rp.rows["momo_training"]
	_tap(row.get_node("Plus"))
	_tap(row.get_node("Plus"))
	assert_true((row.get_node("Plus") as Button).disabled, "none left")
	_tap(row.get_node("Minus"))
	assert_eq(rp.head.text, "Research points 1 / 2", "a minus gives one back")
	_tap(row.get_node("Plus"))
	_tap(rp.confirm_button)
	assert_eq((next.system(&"research") as ResearchSystem).level("momo_training"), 2, "confirmed: Lv 2 again")
	assert_false(frame.visible, "and the screen closes")
	assert_false((next.system(&"prestige") as PrestigeSystem).welcome, "the welcome is done")


func test_a_broken_plan_cannot_be_confirmed() -> void:
	var rs: ResearchSystem = sim.system(&"research")
	rs.rp_earned = 1
	rs.unlocked["momo_training"] = true
	rs.unlocked["momo_reach"] = true
	main.call("open_rp")
	await tree.process_frame
	var rp: RpView = main.get("rp_view")
	_tap((rp.rows["momo_reach"] as Control).get_node("Plus"))
	assert_true(rp.confirm_button.disabled, "reach without training: no")
	assert_true(rp.why.text.contains("needs"), "and why (%s)" % rp.why.text)
	_tap((rp.rows["momo_reach"] as Control).get_node("Minus"))
	_tap((rp.rows["momo_training"] as Control).get_node("Plus"))
	assert_false(rp.confirm_button.disabled, "training alone: fine")
	_tap(rp.cancel_button)
	assert_eq(rs.allocated, {}, "cancel places nothing")
