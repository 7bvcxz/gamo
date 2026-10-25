extends "res://tests/framework/test_case.gd"


func test_default_data_is_valid() -> void:
	var data := GameData.load_default()
	assert_true(data.is_valid(), "shipped data validates: %s" % [data.errors])


func test_every_data_file_is_a_listed_table() -> void:
	var listed := GameData.TABLES
	for file: String in DirAccess.get_files_at("res://data"):
		if file.ends_with(".json"):
			assert_true(listed.has(file.get_basename()), "data/%s is loaded by GameData.TABLES" % file)


func test_mvp_rules_live_in_data() -> void:
	var data := GameData.load_default()
	assert_eq(data.get_int("balance", "start.money"), 10, "$10")
	assert_eq(data.get_int("balance", "start.level"), 1, "Level 1")
	assert_eq(data.get_int("balance", "clock.day_seconds"), 30, "30-second days")
	assert_eq(data.get_vec2i("balance", "start.island.size"), Vector2i(2, 2), "2x2 island")


func test_broken_table_is_reported() -> void:
	var data := GameData.from_tables({"balance": {"start": {"money": "ten"}, "clock": {"day_seconds": 0}}})
	assert_false(data.is_valid(), "invalid balance is caught")
	var joined := "\n".join(data.errors)
	assert_true(joined.contains("start.money"), "names the bad money field")
	assert_true(joined.contains("clock.day_seconds"), "names the bad day length")


func test_data_changes_the_rules() -> void:
	var balance: Dictionary = GameData.load_default().table("balance").duplicate(true)
	balance["start"]["money"] = 250
	balance["clock"]["day_seconds"] = 60
	var sim := Simulation.new_game(GameData.from_tables({"balance": balance}))
	assert_eq((sim.system(&"economy") as EconomySystem).money, 250, "start money comes from data")
	assert_eq(sim.clock.day_ms, 60000, "day length comes from data")
