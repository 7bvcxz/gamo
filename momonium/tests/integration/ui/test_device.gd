extends "res://tests/framework/test_case.gd"

## What a phone does to the game (Step 44): the HUD keeps clear of the camera
## cut-out and the gesture bar; leaving the app saves the island, coming back
## catches up on the time away; the island is there again in a new start; and
## Settings says what the game is -- solo, no server, saved on this device.

const MainScene := preload("res://scenes/main.tscn")
const SAVE := "user://test_device_save.json"

var main: Node


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Engine.set_meta("momonium_save_path", SAVE)
	if Engine.has_meta("momonium_no_save"):
		Engine.remove_meta("momonium_no_save")


func after_each() -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await tree.process_frame
	Engine.remove_meta("momonium_save_path")
	Engine.set_meta("momonium_no_save", true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _open() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame


func test_the_hud_keeps_clear_of_the_cutout() -> void:
	# A tall phone: 1080 x 2340, a punch-hole camera band of 110 px at the top
	# and a 60 px gesture bar, shown on a 720 x 1560 canvas.
	var m := Hud.margins_for(Vector2i(1080, 2340), Rect2i(0, 110, 1080, 2170), Vector2i(1080, 2340), Vector2(720, 1560))
	assert_near(float(m["top"]), Hud.MARGIN + 110.0 * 720.0 / 1080.0, 0.01, "below the camera band")
	assert_near(float(m["bottom"]), Hud.MARGIN + 60.0 * 720.0 / 1080.0, 0.01, "above the gesture bar")
	assert_near(float(m["left"]), Hud.MARGIN, 0.01, "sides untouched")
	var none := Hud.margins_for(Vector2i(1080, 2340), Rect2i(), Vector2i(1080, 2340), Vector2(720, 1560))
	assert_eq(float(none["top"]), Hud.MARGIN, "no safe area reported: the plain margin")


func test_leaving_saves_and_coming_back_catches_up() -> void:
	await _open()
	var sim: Simulation = main.get("sim")
	assert_true(bool(main.get("persist")), "a real island, saved")
	(sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 1))
	var before := int(main.get("saves_written"))
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(int(main.get("saves_written")), before + 1, "the app paused: the island is saved at once")
	assert_true(FileAccess.file_exists(SAVE), "on the device")
	# Back after two minutes in another app: the frame loop sees the gap.
	var j: JourneySystem = sim.system(&"journey")
	main.set("_last_wall", float(main.get("_last_wall")) - 120.0)
	main.call("_process", 0.016)
	assert_true(int(j.totals()["offline_ms"]) >= 119000, "the two minutes away were caught up (%d ms)" % j.totals()["offline_ms"])


func test_the_island_is_there_on_the_next_start() -> void:
	await _open()
	var sim: Simulation = main.get("sim")
	(sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 1))
	(sim.system(&"economy") as EconomySystem).earn(123, "test")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var money := (sim.system(&"economy") as EconomySystem).money
	main.queue_free()
	await tree.process_frame
	await _open()
	var again: Simulation = main.get("sim")
	assert_eq(String(main.get("load_status")), "ok", "the save is read")
	assert_eq((again.system(&"buildings") as BuildingSystem).ids().size(), 1, "the farm is back")
	assert_eq((again.system(&"economy") as EconomySystem).money, money, "and the money")


func test_settings_say_what_the_game_is() -> void:
	await _open()
	var sv: SettingsView = main.get("settings_view")
	LocaleService.apply("en")
	sv.refresh()
	assert_eq(SettingsView.platform(), "desktop", "headless runs as desktop")
	assert_true(sv.about_label.text.contains("no server") and sv.about_label.text.contains("leaderboards"), "solo, no server: %s" % sv.about_label.text)
	assert_true(sv.about_label.text.contains("this device"), "saved on this device")
	assert_eq(sv.version_label.text, "v%s · Desktop" % ProjectSettings.get_setting("application/config/version"), "the build and the platform")
