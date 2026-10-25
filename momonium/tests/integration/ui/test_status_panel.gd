extends "res://tests/framework/test_case.gd"

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var panel: StatusPanel


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	panel = main.get("status_panel")
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_status_button_opens_numbers_from_the_simulation() -> void:
	var prog: ProgressionSystem = sim.system(&"progression")
	prog.add_exp(145, "test")
	prog.add_mastery("farm", 60)
	main.call("_on_hud_action", &"status")
	assert_true(panel.visible, "Status opens")
	assert_eq(panel.level_label.text, "2", "Lv 2")
	assert_eq(panel.exp_label.text, "45 / 180 EXP", "exact EXP")
	assert_near(panel.exp_bar.value, 45.0 / 180.0, 0.001, "bar matches")
	assert_eq((panel.cards["farm"].find_child("Exp", true, false) as Label).text, "60 / 100 EXP", "farm mastery")
	assert_eq(panel.cards.size(), 4, "farm, mine, lumber, research")
	main.call("_on_hud_action", &"status")
	assert_false(panel.visible, "and closes again")


func test_open_panel_follows_live_progress() -> void:
	main.call("_on_hud_action", &"status")
	(sim.system(&"progression") as ProgressionSystem).add_exp(20, "harvest")
	assert_eq(panel.exp_label.text, "20 / 100 EXP", "updates while open")


func test_panel_leaves_the_side_buttons_free() -> void:
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	var hud: Hud = main.get("hud")
	for b: HudButton in hud.side_buttons:
		assert_false(panel.get_rect().intersects(b.get_rect()), "Status does not cover %s" % b.action)
