extends "res://tests/framework/test_case.gd"

## The farm as the rules describe it: sow 5 s, water 5 s three times with at
## least 30 s between waterings, harvest 5 s for one batch of crops -- every
## time, in order, with nothing skipped.

var sim: Simulation
var buildings: BuildingSystem
var inv: InventorySystem
var farm := 0


class Magic:
	var work := 1.0
	var cooldown := 1.0

	func stage_multiplier(kind: String, _type: String, _action: String) -> float:
		return work if kind == "work" else cooldown


func before_each() -> void:
	sim = Simulation.new_game()
	buildings = sim.system(&"buildings")
	inv = sim.system(&"inventory")
	farm = buildings.place_instant("farm", Vector2i(0, 0))


func _tap() -> Dictionary:
	return sim.execute({"type": "building.tap", "id": farm})


func _stage() -> String:
	return String(buildings.current_stage(buildings.get_building(farm))["id"])


func test_the_full_cycle_in_order() -> void:
	var order: Array[String] = []
	var clock := sim.clock
	var log: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_completed":
			log.append([p["stage"], clock.now_ms]))
	for expected: String in ["sow", "water1", "water2", "water3", "harvest"]:
		assert_eq(_stage(), expected, "next is %s" % expected)
		var r := _tap()
		assert_true(r["ok"], "%s starts" % expected)
		order.append(expected)
		sim.advance_ms(5000)
		var b := buildings.get_building(farm)
		if b["state"] == BuildingSystem.COOLDOWN:
			sim.advance_ms(buildings.remaining_ms(b))
	assert_eq(inv.count("crop"), 1, "one batch of crops from one cycle")
	assert_eq(_stage(), "sow", "and the plot is ready to sow again")
	var times: Array = log.map(func(e: Array) -> int: return e[1])
	assert_eq(times, [5000, 10000, 45000, 80000, 115000], "5 + 5 + (30 + 5) x 2 + 30 + 5 seconds")


func test_watering_waits_thirty_seconds_on_the_world_clock() -> void:
	_tap()
	sim.advance_ms(5000)
	_tap()
	sim.advance_ms(5000)
	var r := _tap()
	assert_eq(r["reason"], "err.cooldown", "straight after watering, the next watering waits")
	assert_eq(r["remaining_ms"], 30000, "thirty seconds")
	sim.advance_ms(29999)
	assert_eq(_tap()["reason"], "err.cooldown", "still waiting 1 ms before")
	sim.advance_ms(1)
	assert_true(_tap()["ok"], "and can water again at 30 s")
	assert_eq(_stage(), "water2", "the second watering")


func test_harvest_needs_all_three_waterings() -> void:
	_tap()
	sim.advance_ms(5000)
	for i in 2:
		_tap()
		sim.advance_ms(35000)
	assert_eq(_stage(), "water3", "after two waterings the farm asks for a third, not the harvest")
	assert_eq(inv.count("crop"), 0, "and nothing has been produced")


func test_rapid_taps_do_one_stage_at_a_time() -> void:
	for i in 20:
		_tap()
	sim.advance_ms(5000)
	for i in 20:
		_tap()
	sim.advance_ms(5000)
	assert_eq(buildings.get_building(farm)["completed"], 2, "forty taps over ten seconds did sow and one watering")
	assert_eq(buildings.get_building(farm)["state"], BuildingSystem.COOLDOWN, "and the farm is waiting, not working")


func test_overlapping_farms_keep_their_own_clocks() -> void:
	var second := buildings.place_instant("farm", Vector2i(1, 1))
	_tap()
	sim.advance_ms(3000)
	sim.execute({"type": "building.tap", "id": second})
	sim.advance_ms(2000)
	assert_eq(buildings.get_building(farm)["completed"], 1, "the first finished sowing at 5 s")
	assert_eq(buildings.get_building(second)["completed"], 0, "the second has 3 s to go")
	sim.advance_ms(3000)
	assert_eq(buildings.get_building(second)["completed"], 1, "and finishes at 8 s")


func test_cycles_run_across_midnight() -> void:
	sim.advance_ms(28000)
	_tap()
	sim.advance_ms(5000)
	assert_eq(sim.clock.day_number(), 2, "the sowing ended on Day 2")
	assert_eq(buildings.get_building(farm)["completed"], 1, "and completed")
	_tap()
	sim.advance_ms(5000)
	var r := _tap()
	assert_eq(r["remaining_ms"], 30000, "the 30 s wait does not reset at a day boundary")
	sim.advance_ms(30000)
	assert_true(_tap()["ok"], "and ends 30 s later, on Day 3")
	assert_eq(sim.clock.day_number(), 3, "Day 3")


func test_no_modifier_can_skip_growth() -> void:
	var magic := Magic.new()
	magic.work = 0.0
	magic.cooldown = 0.0
	buildings.modifiers.append(magic)
	var stages: Array[String] = []
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_completed":
			stages.append(p["stage"]))
	for i in 5:
		var b := buildings.get_building(farm)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(buildings.remaining_ms(b))
		_tap()
		sim.advance_ms(500)
	var b := buildings.get_building(farm)
	sim.advance_ms(buildings.remaining_ms(b))
	assert_eq(stages, ["sow", "water1", "water2", "water3", "harvest"] as Array[String], "every stage still runs, in order")
	var w := buildings.current_stage({"type": "farm", "stage": 1})
	assert_near(buildings.stage_seconds({"type": "farm"}, w), BuildingSystem.MIN_WORK_SECONDS, 0.0001, "work has a floor")
	assert_near(buildings.stage_cooldown({"type": "farm"}, w), 10.0, 0.0001, "and the wait between waterings has a floor of 10 s")


func test_farm_data_keeps_the_rules() -> void:
	var stages: Array = GameData.load_default().building_type("farm")["cycle"]["stages"]
	var actions: Array = stages.map(func(st: Dictionary) -> String: return st["action"])
	assert_eq(actions, ["sow", "water", "water", "water", "harvest"], "sow, water x3, harvest")
	for st: Dictionary in stages:
		assert_eq(float(st["seconds"]), 5.0, "%s takes 5 s" % st["id"])
		assert_true(bool(st.get("required", false)), "%s is required" % st["id"])
	for st: Dictionary in stages.slice(1, 4):
		assert_true(float(st["cooldown"]) >= 30.0, "%s is followed by at least 30 s" % st["id"])
	assert_eq(int(stages[4]["yield"]["crop"]), 1, "harvest gives one batch of crops")
