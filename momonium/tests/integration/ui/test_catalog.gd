extends "res://tests/framework/test_case.gd"

## The catalog from the right-side Build button: every industry is on it,
## locked ones saying the level they open at, the mine its wood, and it fits
## the screen in rows.

const MainScene := preload("res://scenes/main.tscn")

var main: Node


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	(main.get("sim") as Simulation).time_scale = 0.0
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_build_button_and_every_industry() -> void:
	var hud: Hud = main.get("hud")
	assert_true(hud.buttons.has(&"build"), "a Build button")
	assert_true(hud.side_buttons.has(hud.buttons[&"build"]), "in the right-side column, always there")
	main.call("_on_hud_action", &"build")
	await tree.process_frame
	var menu: BuildMenu = main.get("build_menu")
	assert_true(menu.visible, "it opens the catalog")
	for t: String in ["farm", "research", "lumberyard", "mine"]:
		assert_true(menu.cards.has(t), "%s is listed" % t)
	assert_eq((menu.cards["lumberyard"].find_child("Unlock", true, false) as Label).text, "Opens at Lv 2", "locked, with its level")
	assert_eq((menu.cards["mine"].find_child("Unlock", true, false) as Label).text, "Opens at Lv 3", "the mine too")
	assert_true(menu.cards["mine"].find_child("Materials", true, false) != null, "and the wood it needs")
	assert_true(menu.cards["farm"].find_child("Unlock", true, false) == null, "the farm is open")
	var screen := main.get_viewport().get_visible_rect()
	assert_true(screen.encloses(menu.get_global_rect()), "the catalog fits on screen")
	for b: HudButton in hud.side_buttons:
		assert_false(menu.get_global_rect().intersects(b.get_global_rect()), "and leaves %s free" % b.action)


func test_hiring_is_always_in_view() -> void:
	main.call("_on_hud_action", &"build")
	await tree.process_frame
	await tree.process_frame
	var menu: BuildMenu = main.get("build_menu")
	assert_eq(String(menu.list.get_child(0).name), "Card_momo", "the hire card comes first")
	assert_true(menu.scroll.get_global_rect().encloses(menu.cards["momo"].get_global_rect()), "inside the visible part of the catalog")
