extends "res://tests/framework/test_case.gd"

## The game itself with saving on (its own file): it opens the saved island,
## catches up the time away and says what happened; it says when a save was
## damaged; it will not overwrite a newer version's save; it saves when the
## window loses focus.

const MainScene := preload("res://scenes/main.tscn")
const PATH := "user://test_main_save.json"

var main: Node


func before_each() -> void:
	Engine.remove_meta("momonium_no_save")
	Engine.set_meta("momonium_save_path", PATH)


func after_each() -> void:
	if main != null:
		main.queue_free()
		await tree.process_frame
		main = null
	Engine.set_meta("momonium_no_save", true)
	Engine.remove_meta("momonium_save_path")
	for p: String in [PATH, PATH + ".tmp", PATH + ".bak", PATH + ".corrupt"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _open() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	(main.get("sim") as Simulation).time_scale = 0.0
	LocaleService.apply("en")


func test_opens_the_saved_island_and_tells_what_happened_away() -> void:
	var sim := with_starter_momo(Simulation.new_game())
	var f := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": f})
	var two_hours_ago := int(Time.get_unix_time_from_system()) - 7200
	SaveService.write(sim, PATH, two_hours_ago)
	await _open()
	assert_eq(main.get("load_status"), "ok", "the save opened")
	var live: Simulation = main.get("sim")
	var report: Dictionary = main.get("offline_report")
	assert_true(abs(int(report["counted_ms"]) - 7200000) < 5000, "two hours were caught up (%d ms)" % report["counted_ms"])
	assert_true(live.now_ms() >= 7200000, "the island's clock moved on")
	assert_true((main.get("away_frame") as PanelFrame).visible, "a welcome-back card")
	var lines: Array = (main.get("away_view") as AwayView).lines()
	assert_eq(lines[0][0], "Away", "how long")
	assert_true(String(lines[0][1]).begins_with("2 h"), "two hours (%s)" % lines[0][1])
	assert_true(lines.any(func(l: Array) -> bool: return l[0] == "Crops grown"), "what Momo grew")


func test_says_when_the_save_was_damaged() -> void:
	SaveService.write(with_starter_momo(Simulation.new_game()), PATH, int(Time.get_unix_time_from_system()))
	SaveService.write(with_starter_momo(Simulation.new_game()), PATH, int(Time.get_unix_time_from_system()))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	await _open()
	assert_eq(main.get("load_status"), "backup", "opened the save before")
	assert_true((main.get("away_frame") as PanelFrame).visible, "and says so")
	assert_eq((main.get("away_view") as AwayView).notice.text, "Your save was damaged, so the one before it was opened.", "in words")


func test_a_newer_save_is_never_overwritten() -> void:
	SaveService.write(with_starter_momo(Simulation.new_game()), PATH)
	var env: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	env["schema"] = Simulation.SAVE_SCHEMA + 5
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()
	var before := FileAccess.get_file_as_string(PATH)
	await _open()
	assert_eq(main.get("load_status"), "too_new", "recognised")
	assert_ne(main.call("save_now"), OK, "saving is refused")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(FileAccess.get_file_as_string(PATH), before, "the newer save is untouched")


func test_saves_when_the_window_loses_focus() -> void:
	await _open()
	assert_false(FileAccess.file_exists(PATH), "nothing saved yet")
	((main.get("sim") as Simulation).system(&"economy") as EconomySystem).earn(777, "test")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var r := SaveService.load_save(PATH)
	assert_eq(r["status"], "ok", "saved on losing focus")
	assert_eq(int(r["state"]["systems"]["economy"]["money"]), 787, "with the money just earned")


func test_tests_do_not_touch_saves() -> void:
	Engine.set_meta("momonium_no_save", true)
	await _open()
	assert_false(main.get("persist"), "saving is off under tests")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(FileAccess.file_exists(PATH), "and nothing is written")
