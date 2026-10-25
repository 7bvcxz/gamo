extends "res://tests/framework/test_case.gd"

## Versioned, checked, atomic saves of everything on the island; recovery from
## damage; and progress while away that only runs what the world itself runs,
## within deterministic limits.

const PATH := "user://test_persistence.json"


func after_each() -> void:
	for p: String in [PATH, PATH + ".tmp", PATH + ".bak", PATH + ".corrupt"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## An island with something in every system.
func _busy_world() -> Simulation:
	var sim := Simulation.new_game()
	var bs: BuildingSystem = sim.system(&"buildings")
	(sim.system(&"economy") as EconomySystem).earn(2000, "test")
	sim.execute({"type": "land.buy", "cell": [2, 0]})
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var lab := bs.place_instant("research", Vector2i(0, 1))
	sim.execute({"type": "momo.hire"})
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.execute({"type": "momo.assign", "momo": 2, "building": lab})
	sim.advance_ms(260000)
	sim.execute({"type": "mail.claim", "id": 1})
	sim.execute({"type": "research.start", "id": "farm_expansion"})
	sim.execute({"type": "building.place", "building": "farm", "anchor": [2, 0]})
	sim.advance_ms(3000)
	return sim


func _json(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)))


func test_the_envelope() -> void:
	var sim := Simulation.new_game()
	var env: Dictionary = JSON.parse_string(SaveService.encode(sim, 1700000000))
	assert_eq(env["format"], "momonium", "says what it is")
	assert_eq(int(env["schema"]), Simulation.SAVE_SCHEMA, "and which version")
	assert_eq(int(env["saved_unix"]), 1700000000, "when it was saved")
	assert_eq(String(env["checksum"]), String(env["state"]).sha256_text(), "a checksum of the state")


func test_everything_round_trips() -> void:
	var sim := _busy_world()
	var keys := (sim.save_state()["systems"] as Dictionary).keys()
	for k: String in ["world", "economy", "inventory", "buildings", "progression", "momo", "jobs", "mail", "research"]:
		assert_true(keys.has(k), "%s is saved" % k)
	assert_eq(SaveService.write(sim, PATH), OK, "written")
	var r := SaveService.load_save(PATH)
	assert_eq(r["status"], "ok", "read back")
	var loaded := Simulation.from_save(r["state"])
	assert_eq(_json(loaded.save_state()), _json(sim.save_state()), "the same island, field for field")
	for s: Simulation in [sim, loaded]:
		s.advance_ms(30000 * 20)
	assert_eq(_json(loaded.save_state()), _json(sim.save_state()), "and it goes on the same way")


func test_a_damaged_save_falls_back_to_the_one_before() -> void:
	var sim := _busy_world()
	SaveService.write(sim, PATH)
	sim.advance_ms(5000)
	SaveService.write(sim, PATH)
	var text := FileAccess.get_file_as_string(PATH)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text.substr(0, text.length() / 2))
	f.close()
	var r := SaveService.load_save(PATH)
	assert_eq(r["status"], "backup", "the cut-off save is refused, the previous one opens")
	assert_eq(int(r["state"]["clock"]["now_ms"]), sim.now_ms() - 5000, "it is the save before")
	assert_true(FileAccess.file_exists(PATH + ".corrupt"), "the damaged file is kept to look at")


func test_an_edited_save_is_recognised() -> void:
	SaveService.write(Simulation.new_game(), PATH)
	var env: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var edited := String(env["state"]).replace("\"money\":10", "\"money\":99999")
	assert_ne(edited, String(env["state"]), "the edit really changed the money")
	env["state"] = edited
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()
	assert_eq(SaveService.load_save(PATH)["status"], "corrupt", "the checksum no longer matches")


func test_nonsense_and_missing() -> void:
	assert_eq(SaveService.load_save(PATH)["status"], "missing", "no save")
	for text: String in ["", "{ not json", "[1, 2]", "{\"format\": \"other\"}", "{\"format\": \"momonium\", \"state\": 5}"]:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		assert_eq(SaveService.load_save(PATH)["status"], "corrupt", "%s is not a save" % text)


func test_a_newer_save_is_left_alone() -> void:
	SaveService.write(Simulation.new_game(), PATH)
	var env: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	env["schema"] = Simulation.SAVE_SCHEMA + 1
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()
	var before := FileAccess.get_file_as_string(PATH)
	assert_eq(SaveService.load_save(PATH)["status"], "too_new", "from a newer version")
	assert_eq(FileAccess.get_file_as_string(PATH), before, "not touched")


func test_a_save_from_before_the_envelope_opens() -> void:
	var sim := _busy_world()
	var old := sim.save_state()
	old["schema"] = 1
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var r := SaveService.load_save(PATH)
	assert_eq(r["status"], "ok", "schema 1 migrates")
	assert_eq(int(r["saved_unix"]), 0, "with no time, so no offline progress is guessed")
	assert_eq(int(r["state"]["schema"]), Simulation.SAVE_SCHEMA, "now at the current schema")
	assert_eq(_json(Simulation.from_save(r["state"]).save_state()["systems"]), _json(sim.save_state()["systems"]), "same island")


func test_a_crash_mid_write_leaves_a_save() -> void:
	var sim := Simulation.new_game()
	SaveService.write(sim, PATH)
	sim.advance_ms(2000)
	SaveService.write(sim, PATH)
	# As if the game died after keeping the backup, before the new file landed.
	DirAccess.remove_absolute(PATH)
	var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	f.store_string("{\"format\": \"momonium\", \"sta")
	f.close()
	assert_eq(SaveService.load_save(PATH)["status"], "backup", "the backup is there")


# --- away ---------------------------------------------------------------------

func _momo_farm() -> Simulation:
	var sim := Simulation.new_game()
	var f := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": f})
	return sim


func test_away_runs_assigned_work_and_sales() -> void:
	var sim := _momo_farm()
	var r := OfflineProgress.catch_up(sim, 3600000)
	assert_eq(r["counted_ms"], 3600000, "an hour counted")
	assert_true(int(r["crops"]) >= 15, "Momo farmed (%d crops)" % r["crops"])
	assert_true(int(r["income"]) > 0, "and the daily sales paid ($%d)" % r["income"])
	assert_eq(r["days"], 120, "120 days of 30 s went by")


func test_away_never_taps_for_the_player() -> void:
	var sim := Simulation.new_game()
	var bs: BuildingSystem = sim.system(&"buildings")
	var f := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "building.tap", "id": f})
	var r := OfflineProgress.catch_up(sim, 3600000)
	var b := bs.get_building(f)
	assert_eq(int(b["completed"]), 1, "only the sowing the player started finished")
	assert_eq(int(b["stage"]), 1, "nobody watered it")
	assert_eq(r["crops"], 0, "no crops from work nobody did")


func test_away_respects_the_store() -> void:
	var sim := _momo_farm()
	var inv: InventorySystem = sim.system(&"inventory")
	var worst := [0]
	sim.bus.emitted.connect(func(t: StringName, _p: Dictionary) -> void:
		if t == &"inventory_changed":
			worst[0] = maxi(worst[0], inv.count("crop")))
	(sim.system(&"research") as ResearchSystem).completed["farm_expansion"] = 0
	(sim.system(&"research") as ResearchSystem).completed["harvest_boost"] = 0
	OfflineProgress.catch_up(sim, 8 * 3600000)
	assert_true(worst[0] <= inv.capacity("crop"), "never more crops than the store holds (%d)" % worst[0])


func test_the_clock_going_back_gives_nothing() -> void:
	var sim := _momo_farm()
	var before := JSON.stringify(sim.save_state())
	var r := OfflineProgress.catch_up(sim, -86400000)
	assert_true(r["clock_went_back"], "noticed")
	assert_eq(r["counted_ms"], 0, "no time counted")
	assert_eq(JSON.stringify(sim.save_state()), before, "the island is untouched")


func test_a_huge_clock_jump_is_capped() -> void:
	var sim := _momo_farm()
	var r := OfflineProgress.catch_up(sim, 365 * 86400000)
	assert_true(r["capped_time"], "a year away")
	assert_eq(r["counted_ms"], 8 * 3600000, "counts as the 8 hours the rules allow")


func test_the_event_budget_stops_the_clock_where_it_stopped() -> void:
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	bal["offline"]["max_events"] = 50
	var results: Array = []
	for i in 2:
		var sim := Simulation.new_game(GameData.from_tables({"balance": bal}))
		var f := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
		sim.execute({"type": "momo.assign", "momo": 1, "building": f})
		var r := OfflineProgress.catch_up(sim, 3600000)
		results.append([r["counted_ms"], JSON.stringify(sim.save_state())])
		assert_true(r["capped_events"], "too much to count")
		assert_true(int(r["counted_ms"]) < 3600000, "so less than the hour is counted (%d ms)" % r["counted_ms"])
		assert_eq(sim.now_ms(), int(r["counted_ms"]), "and the clock is where the counting stopped")
	assert_eq(results[1], results[0], "the same save stops at the same moment")


func test_away_is_the_same_as_staying() -> void:
	var a := _momo_farm()
	var b := _momo_farm()
	OfflineProgress.catch_up(a, 600000)
	for i in 600:
		b.advance_ms(1000)
	# The journey keeps which of the two it was; the island is the same.
	var sa := a.save_state()
	var sb := b.save_state()
	assert_eq(int(sa["systems"]["journey"]["offline_ms"]), 600000, "the journey knows these ten minutes were away")
	assert_eq(int(sb["systems"]["journey"]["offline_ms"]), 0, "and these were watched")
	sa["systems"].erase("journey")
	sb["systems"].erase("journey")
	assert_eq(JSON.stringify(sa), JSON.stringify(sb), "ten minutes away = ten minutes watched")


func test_the_newer_of_two_copies_opens() -> void:
	var old := {"status": "ok", "saved_unix": 100, "state": {"n": 1}}
	var new := {"status": "ok", "saved_unix": 200, "state": {"n": 2}}
	assert_eq(SaveService.newest(old, new)["saved_unix"], 200, "the later save")
	assert_eq(SaveService.newest(new, old)["saved_unix"], 200, "either way round")
	assert_eq(SaveService.newest({"status": "corrupt"}, old)["saved_unix"], 100, "a readable copy over a broken one")
	assert_eq(SaveService.newest({"status": "missing"}, old)["saved_unix"], 100, "over none")
	assert_eq(SaveService.newest({"status": "too_new"}, old)["status"], "too_new", "but never past a newer version's save")
