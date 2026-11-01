extends "res://tests/framework/test_case.gd"

## The game itself with saving on (its own file): it opens the saved island
## exactly as it was saved -- Step 79: nothing is caught up, however long
## ago it was saved, and no welcome-back card; it says when a save was
## damaged; it will not overwrite a newer version's save; it saves when the
## window loses focus and when it goes to the background.

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


## A farm ripening after its watering and a Momo 40% through a dig, saved:
## the player sows, the Momo is sent to the mine during the sowing, the
## watering ends while the dig is under way.
func _busy_island() -> Simulation:
	var sim := with_starter_momo(Simulation.new_game())
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var mine := bs.place_instant("mine", Vector2i(0, 1))
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(14000)
	sim.execute({"type": "momo.assign", "momo": 1, "building": mine})
	sim.advance_ms(bs.remaining_ms(bs.get_building(farm)))
	sim.execute({"type": "building.tap", "id": farm})
	var dig := bs.get_building(mine)
	while dig["state"] != BuildingSystem.WORKING or bs.progress(dig) < 0.4:
		sim.advance_ms(100)
	assert_eq(bs.get_building(farm)["state"], BuildingSystem.COOLDOWN, "the crop is ripening")
	return sim


func test_opens_the_saved_island_exactly_as_saved_however_long_ago() -> void:
	for hours: int in [2, 10, 24 * 7]:
		var sim := _busy_island()
		var bs: BuildingSystem = sim.system(&"buildings")
		var saved: Dictionary = sim.snapshot()
		var farm_left := bs.remaining_ms(bs.get_building(bs.building_at(Vector2i(1, 0))))
		var dig_left := bs.remaining_ms(bs.get_building(bs.building_at(Vector2i(0, 1))))
		SaveService.write(sim, PATH, int(Time.get_unix_time_from_system()) - hours * 3600)
		await _open()
		assert_eq(main.get("load_status"), "ok", "%d h: the save opened" % hours)
		var live: Simulation = main.get("sim")
		var lb: BuildingSystem = live.system(&"buildings")
		# Only the frames on screen since it opened (before the test stopped
		# its clock) -- never the hours since the save.
		var ran := live.now_ms() - sim.now_ms()
		assert_between(ran, 0, 1000, "%d h: the island's clock where it was saved (%d ms of frames since)" % [hours, ran])
		var now: Dictionary = live.snapshot()
		for k: String in ["economy", "progression", "inventory", "mail", "research", "buildings", "momo", "journey", "prestige"]:
			assert_true(JSON.stringify(now[k]) == JSON.stringify(saved[k]), "%d h: %s as saved" % [hours, k])
		assert_eq(lb.remaining_ms(lb.get_building(lb.building_at(Vector2i(1, 0)))), farm_left - ran, "%d h: the crop has the same ripening left" % hours)
		assert_eq(lb.remaining_ms(lb.get_building(lb.building_at(Vector2i(0, 1)))), dig_left - ran, "%d h: the dig the same 60%% left" % hours)
		assert_eq(main.get("offline_report"), {}, "%d h: nothing caught up" % hours)
		assert_false((main.get("away_frame") as PanelFrame).visible, "%d h: no welcome-back card" % hours)
		# On screen, the island goes on with its frames.
		var before := live.now_ms()
		live.time_scale = 1.0
		main.call("_process", 0.4)
		live.time_scale = 0.0
		assert_eq(live.now_ms(), before + 400, "%d h: then it runs with the frames" % hours)
		main.queue_free()
		await tree.process_frame
		main = null


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


func test_the_background_saves_once_and_stands_still() -> void:
	await _open()
	var live: Simulation = main.get("sim")
	(live.system(&"economy") as EconomySystem).earn(5, "test")
	var saves := int(main.get("saves_written"))
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(int(main.get("saves_written")), saves + 1, "gone to the background: saved once")
	assert_eq(SaveService.load_save(PATH)["status"], "ok", "on disk")
	main.call("go_background")
	assert_eq(int(main.get("saves_written")), saves + 1, "said twice, saved once")
	live.time_scale = 1.0
	var now := live.now_ms()
	for d: float in [0.016, 5.0, 3600.0]:
		main.call("_process", d)
	assert_eq(live.now_ms(), now, "no frame moves the island in the background")
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	main.call("_process", 3600.0)
	assert_eq(live.now_ms(), now, "the first frame back carries the hour away: none of it counts")
	main.call("_process", 0.25)
	live.time_scale = 0.0
	assert_eq(live.now_ms(), now + 250, "then the frames, as before")


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
