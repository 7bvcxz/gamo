extends "res://tests/framework/test_case.gd"

## Settings: language buttons, the demo island (built by the real rules,
## labelled, never saved), and the first-run tutorial starting by itself only
## on a brand-new island.

const MainScene := preload("res://scenes/main.tscn")
const SAVE := "user://test_settings_save.json"
const PREFS := "user://test_settings_prefs.json"

var main: Node


func after_each() -> void:
	if main != null:
		main.queue_free()
		await tree.process_frame
		main = null
	Engine.set_meta("momonium_no_save", true)
	for k: String in ["momonium_save_path", "momonium_settings_path", "momonium_demo"]:
		if Engine.has_meta(k):
			Engine.remove_meta(k)
	for p: String in [SAVE, SAVE + ".bak", SAVE + ".tmp", PREFS]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	LocaleService.apply("en")


func _open() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame


func test_language_buttons() -> void:
	await _open()
	main.call("_on_hud_action", &"settings")
	var view: SettingsView = main.get("settings_view")
	view.lang_buttons["ja"].pressed.emit()
	assert_eq(LocaleService.current(), "ja", "Japanese")
	assert_eq(view.tutorial_button.text, "チュートリアルをもう一度", "the panel speaks it")
	assert_eq((main.get("settings") as SettingsStore).get_value("language"), "ja", "and remembers")


func test_the_demo_island() -> void:
	var demo := DemoWorld.build()
	var bs: BuildingSystem = demo.system(&"buildings")
	var types := bs.ids().map(func(id: int) -> String: return String(bs.get_building(id)["type"]))
	for t: String in ["farm", "research", "lumberyard", "mine"]:
		assert_true(types.has(t), "the demo has a %s" % t)
	var inv: InventorySystem = demo.system(&"inventory")
	assert_true(inv.count("stone") > 0 and inv.count("copper_ore") + inv.count("iron_ore") > 0, "ores came from its mine")
	assert_eq((demo.system(&"research") as ResearchSystem).state_of("deep_shaft"), "available", "a late research to try")
	assert_true((demo.system(&"mail") as MailSystem).letters.size() > 0, "letters to read")


func test_the_demo_is_labelled_and_never_saved() -> void:
	Engine.remove_meta("momonium_no_save")
	Engine.set_meta("momonium_save_path", SAVE)
	Engine.set_meta("momonium_settings_path", PREFS)
	Engine.set_meta("momonium_demo", true)
	await _open()
	assert_true(main.get("in_demo"), "demo mode")
	assert_false(main.get("persist"), "nothing saved")
	assert_ne(main.call("save_now"), OK, "saving refused")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(FileAccess.file_exists(SAVE), "the player's save untouched")
	assert_true((main.get("_demo_badge") as Label).visible, "labelled")
	main.call("_on_hud_action", &"settings")
	assert_eq((main.get("settings_view") as SettingsView).demo_button.text, "Back to my island", "the way back")
	assert_false((main.get("tutorial") as Tutorial).running, "no tutorial in the demo")


func test_a_brand_new_island_starts_the_tutorial_once() -> void:
	Engine.remove_meta("momonium_no_save")
	Engine.set_meta("momonium_save_path", SAVE)
	Engine.set_meta("momonium_settings_path", PREFS)
	await _open()
	await tree.process_frame
	assert_true((main.get("tutorial") as Tutorial).running, "a fresh island: the tutorial starts")
	(main.get("tutorial") as Tutorial).stop(true)
	main.queue_free()
	await tree.process_frame
	await _open()
	await tree.process_frame
	assert_false((main.get("tutorial") as Tutorial).running, "seen once: not again by itself")


func test_the_demo_island_is_fully_staffed() -> void:
	var demo := DemoWorld.build()
	var momos: MomoSystem = demo.system(&"momo")
	assert_eq(momos.ids().size(), 8, "every Momo it means to hire was hired (money did not run out)")
	assert_true(momos.ids().all(func(m: int) -> bool: return int(momos.get_momo(m)["assigned"]) != 0), "and each has a job")
	var community: CommunitySystem = demo.system(&"community")
	assert_eq(community.housing().size(), 8, "and a home")
