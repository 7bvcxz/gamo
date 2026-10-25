extends "res://tests/framework/test_case.gd"

## The farm as the rules describe it: sow 5 s, water 5 s three times with a
## wait between waterings (15 s in the data since Step 42; read from it here),
## harvest 5 s for one batch of crops -- every time, in order, with nothing
## skipped.

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


## The wait after a watering, and its floor, as the data gives them (ms, s).
func _wait_ms() -> int:
	return int(float(sim.data.building_type("farm")["cycle"]["stages"][1]["cooldown"]) * 1000.0)


func _floor_s() -> float:
	return float(sim.data.building_type("farm")["cycle"]["stages"][1]["cooldown_floor"])


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
	var w := _wait_ms()
	assert_eq(times, [5000, 10000, 15000 + w, 20000 + 2 * w, 25000 + 3 * w], "5 + 5 + (wait + 5) x 2 + wait + 5 seconds")


func test_watering_waits_on_the_world_clock() -> void:
	_tap()
	sim.advance_ms(5000)
	_tap()
	sim.advance_ms(5000)
	var r := _tap()
	assert_eq(r["reason"], "err.cooldown", "straight after watering, the next watering waits")
	assert_eq(r["remaining_ms"], _wait_ms(), "the whole wait")
	sim.advance_ms(_wait_ms() - 1)
	assert_eq(_tap()["reason"], "err.cooldown", "still waiting 1 ms before")
	sim.advance_ms(1)
	assert_true(_tap()["ok"], "and can water again when it ends")
	assert_eq(_stage(), "water2", "the second watering")


func test_harvest_needs_all_three_waterings() -> void:
	_tap()
	sim.advance_ms(5000)
	for i in 2:
		_tap()
		sim.advance_ms(5000 + _wait_ms())
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
	# Sow, then water so that the wait after it straddles the next midnight.
	var day_ms := 30000
	sim.advance_ms(2 * day_ms - _wait_ms() - 10000 + 1000)
	_tap()
	sim.advance_ms(5000)
	var day := sim.clock.day_number()
	assert_eq(buildings.get_building(farm)["completed"], 1, "sown")
	_tap()
	sim.advance_ms(5000)
	var r := _tap()
	assert_eq(r["remaining_ms"], _wait_ms(), "the wait does not reset at a day boundary")
	sim.advance_ms(_wait_ms())
	assert_true(_tap()["ok"], "and ends on time")
	assert_eq(sim.clock.day_number(), day + 1, "on the next day")


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
	assert_near(buildings.stage_cooldown({"type": "farm"}, w), _floor_s(), 0.0001, "and the wait between waterings has its floor")
	assert_true(_floor_s() >= 1.0, "a real floor: the plants always get time to drink")


func test_farm_data_keeps_the_rules() -> void:
	var stages: Array = GameData.load_default().building_type("farm")["cycle"]["stages"]
	var actions: Array = stages.map(func(st: Dictionary) -> String: return st["action"])
	assert_eq(actions, ["sow", "water", "water", "water", "harvest"], "sow, water x3, harvest")
	for st: Dictionary in stages:
		assert_eq(float(st["seconds"]), 5.0, "%s takes 5 s" % st["id"])
		assert_true(bool(st.get("required", false)), "%s is required" % st["id"])
	for st: Dictionary in stages.slice(1, 4):
		assert_true(float(st["cooldown"]) >= 15.0, "%s is followed by at least 15 s" % st["id"])
		assert_true(float(st["cooldown_floor"]) < float(st["cooldown"]), "%s: research can shorten the wait (floor below it)" % st["id"])
	assert_eq(int(stages[4]["yield"]["crop"]), 1, "harvest gives one batch of crops")
