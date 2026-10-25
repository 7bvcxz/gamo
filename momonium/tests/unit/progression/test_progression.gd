extends "res://tests/framework/test_case.gd"

## Level and mastery: EXP only for finished things, growing thresholds,
## remainder carried over, mastery per building type, unlocks from data.

var sim: Simulation
var prog: ProgressionSystem
var buildings: BuildingSystem


func before_each() -> void:
	sim = Simulation.new_game()
	prog = sim.system(&"progression")
	buildings = sim.system(&"buildings")


func _farm_cycle(farm: int) -> void:
	for i in 5:
		var b := buildings.get_building(farm)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(buildings.remaining_ms(b))
		sim.execute({"type": "building.tap", "id": farm})
		sim.advance_ms(5000)


func test_starts_at_level_one_with_nothing() -> void:
	assert_eq(prog.level, 1, "Lv 1")
	assert_eq(prog.experience, 0, "0 EXP")
	assert_eq(prog.next_level_exp(), 100, "100 to Lv 2")
	assert_eq(prog.mastery_of("farm"), {"level": 1, "exp": 0, "next": 100}, "farm mastery Lv 1, 0 / 100")


func test_thresholds_grow() -> void:
	var last := 0
	for lv in range(1, 20):
		var need := prog.exp_needed_for(lv)
		assert_true(need > last, "Lv %d -> %d needs more than the step before (%d > %d)" % [lv, lv + 1, need, last])
		last = need


func test_taps_earn_nothing_harvests_earn_exp() -> void:
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	for i in 30:
		sim.execute({"type": "building.tap", "id": farm})
	assert_eq(prog.experience, 0, "thirty taps on a sowing farm: no EXP")
	_farm_cycle(farm)
	assert_eq(prog.experience, 20, "one harvest: 20 EXP")
	assert_eq(prog.mastery_of("farm")["exp"], 25, "and 25 farm mastery")
	assert_eq(prog.mastery_of("mine")["exp"], 0, "other masteries untouched")


func test_finished_buildings_and_land_pay_a_little() -> void:
	(sim.system(&"economy") as EconomySystem).earn(100, "test")
	sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	assert_eq(prog.experience, 0, "placing pays nothing")
	sim.advance_ms(5000)
	assert_eq(prog.experience, 5, "a finished building pays 5")
	sim.execute({"type": "land.buy", "cell": [2, 0]})
	assert_eq(prog.experience, 15, "land pays 10")


func test_level_up_carries_the_remainder_and_can_jump() -> void:
	var ups: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"level_up":
			ups.append(p["level"]))
	prog.add_exp(130, "test")
	assert_eq(prog.level, 2, "Lv 2")
	assert_eq(prog.experience, 30, "30 carried over")
	prog.add_exp(100 + 180 + 300, "test")
	assert_eq(prog.level, 4, "two more levels at once")
	assert_eq(prog.experience, 30 + 580 - 180 - 300, "remainder")
	assert_eq(ups, [2, 3, 4], "one event per level")


func test_mastery_levels_are_independent() -> void:
	prog.add_mastery("farm", 250)
	assert_eq(prog.mastery_of("farm")["level"], 2, "farm Lv 2")
	assert_eq(prog.mastery_of("farm")["exp"], 150, "150 towards Lv 3")
	assert_eq(prog.mastery_of("farm")["next"], 200, "which needs 200")
	assert_eq(prog.mastery_of("lumberyard")["level"], 1, "lumber still Lv 1")


func test_unlocks_come_from_data() -> void:
	var balance: Dictionary = GameData.load_default().table("balance").duplicate(true)
	balance["unlocks"]["land"] = {"level": 2}
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["farm"]["unlock"] = {"level": 1, "mastery": {"farm": 2}}
	var s2 := Simulation.new_game(GameData.from_tables({"balance": balance, "buildings": b}))
	(s2.system(&"economy") as EconomySystem).earn(500, "test")
	assert_eq(s2.execute({"type": "land.buy", "cell": [2, 0]})["reason"], "err.locked", "land needs Lv 2 in this table")
	assert_eq(s2.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})["reason"], "err.locked", "farm needs farm mastery 2 here")
	var p2: ProgressionSystem = s2.system(&"progression")
	p2.add_exp(100, "test")
	p2.add_mastery("farm", 100)
	assert_true(s2.execute({"type": "land.buy", "cell": [2, 0]})["ok"], "Lv 2 opens land")
	assert_true(s2.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})["ok"], "mastery 2 opens the farm")


func test_balance_first_levels_take_a_handful_of_harvests() -> void:
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	var harvests_to := {}
	for n in range(1, 40):
		_farm_cycle(farm)
		if not harvests_to.has(prog.level):
			harvests_to[prog.level] = n
	assert_between(harvests_to.get(2, 999), 4, 8, "Lv 2 after 4-8 harvests (%d)" % harvests_to.get(2, 999))
	assert_between(harvests_to.get(3, 999), 10, 20, "Lv 3 after 10-20 harvests (%d)" % harvests_to.get(3, 999))
	assert_true(prog.mastery_of("farm")["level"] >= 4, "farm mastery climbs with the work (Lv %d)" % prog.mastery_of("farm")["level"])


func test_progress_survives_a_save() -> void:
	prog.add_exp(150, "test")
	prog.add_mastery("farm", 120)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var p2: ProgressionSystem = copy.system(&"progression")
	assert_eq([p2.level, p2.experience], [2, 50], "level and EXP")
	assert_eq(p2.mastery_of("farm"), {"level": 2, "exp": 20, "next": 200}, "mastery")


func test_mastery_up_listeners_see_the_new_level() -> void:
	var sim := Simulation.new_game()
	var prog: ProgressionSystem = sim.system(&"progression")
	var seen := []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"mastery_up":
			seen.append([int(p["level"]), int(prog.mastery_of(String(p["type"]))["level"])]))
	prog.add_mastery("mine", 1000)
	assert_true(seen.size() >= 2, "several levels at once")
	for pair: Array in seen:
		assert_true(pair[1] >= pair[0], "during mastery_up the level is already stored (%s)" % [pair])
