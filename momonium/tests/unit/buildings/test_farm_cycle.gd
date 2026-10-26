extends "res://tests/framework/test_case.gd"

## The farm as the rules describe it (Step 50): sow, water, a short wait while
## the watered crop drinks and ripens, harvest -- one complete cycle in 9.5 s
## by hand since Step 58 (the work x2.5: 2.5 + 2.5 + the 2 s wait + 2.5; it
## was 5 s), every stage every time, in order, with nothing skipped. The harvest's
## crops are sold the moment they are picked. Durations are read from the data.

var sim: Simulation
var buildings: BuildingSystem
var inv: InventorySystem
var economy: EconomySystem
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
	economy = sim.system(&"economy")
	farm = buildings.place_instant("farm", Vector2i(0, 0))


func _stages() -> Array:
	return sim.data.building_type("farm")["cycle"]["stages"]


func _work_ms(i: int) -> int:
	return int(round(float(_stages()[i]["seconds"]) * work_scale(sim) * 1000.0))


## The wait after watering, and its floor, as the data gives them (ms, s).
func _wait_ms() -> int:
	return int(float(_stages()[1]["cooldown"]) * 1000.0)


func _floor_s() -> float:
	return float(_stages()[1]["cooldown_floor"])


func _tap() -> Dictionary:
	return sim.execute({"type": "building.tap", "id": farm})


func _stage() -> String:
	return String(buildings.current_stage(buildings.get_building(farm))["id"])


func test_the_full_cycle_in_order_in_nine_and_a_half_seconds() -> void:
	var clock := sim.clock
	var log: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_completed":
			log.append([p["stage"], clock.now_ms]))
	var money := economy.money
	for i in 3:
		assert_eq(_stage(), ["sow", "water", "harvest"][i], "next is the %s" % ["sow", "water", "harvest"][i])
		assert_true(_tap()["ok"], "it starts at once")
		sim.advance_ms(_work_ms(i))
		var b := buildings.get_building(farm)
		if b["state"] == BuildingSystem.COOLDOWN:
			sim.advance_ms(buildings.remaining_ms(b))
	var times: Array = log.map(func(e: Array) -> int: return e[1])
	assert_eq(times, [_work_ms(0), _work_ms(0) + _work_ms(1), _work_ms(0) + _work_ms(1) + _wait_ms() + _work_ms(2)], "sow, water, wait, harvest")
	assert_eq(int(times[-1]), 9500, "one complete cycle by hand is 9.5 s (Step 58; Step 50: 5 s)")
	assert_eq(_stage(), "sow", "and the plot is ready to sow again")
	assert_eq(inv.count("crop"), 0, "the crop never sits in the store")
	assert_eq(economy.money - money, economy.unit_price("crop"), "it was sold the moment it was picked")


func test_watering_waits_on_the_world_clock() -> void:
	_tap()
	sim.advance_ms(_work_ms(0))
	_tap()
	sim.advance_ms(_work_ms(1))
	var r := _tap()
	assert_eq(r["reason"], "err.cooldown", "straight after watering, the harvest waits for the crop to ripen")
	assert_eq(r["remaining_ms"], _wait_ms(), "the whole wait")
	sim.advance_ms(_wait_ms() - 1)
	assert_eq(_tap()["reason"], "err.cooldown", "still waiting 1 ms before")
	sim.advance_ms(1)
	assert_true(_tap()["ok"], "and can harvest when it ends")
	assert_eq(_stage(), "harvest", "the harvest")


func test_harvest_needs_the_watering() -> void:
	_tap()
	sim.advance_ms(_work_ms(0) + 10000)
	assert_eq(_stage(), "water", "sown but not watered: the farm asks for water, not the harvest")
	assert_eq(economy.lifetime_income(), 0, "and nothing has been earned")


func test_rapid_taps_do_one_stage_at_a_time() -> void:
	for i in 20:
		_tap()
	sim.advance_ms(_work_ms(0))
	for i in 20:
		_tap()
	sim.advance_ms(_work_ms(1))
	assert_eq(buildings.get_building(farm)["completed"], 2, "forty taps did sow and one watering")
	assert_eq(buildings.get_building(farm)["state"], BuildingSystem.COOLDOWN, "and the crop is ripening, the farm not working")


func test_overlapping_farms_keep_their_own_clocks() -> void:
	var second := buildings.place_instant("farm", Vector2i(1, 1))
	_tap()
	sim.advance_ms(_work_ms(0) / 2)
	sim.execute({"type": "building.tap", "id": second})
	sim.advance_ms(_work_ms(0) / 2)
	assert_eq(buildings.get_building(farm)["completed"], 1, "the first finished sowing")
	assert_eq(buildings.get_building(second)["completed"], 0, "the second has half to go")
	sim.advance_ms(_work_ms(0) / 2)
	assert_eq(buildings.get_building(second)["completed"], 1, "and finishes on its own clock")


func test_cycles_run_across_midnight() -> void:
	# Sow, then water so that the ripening after it straddles the next midnight.
	var day_ms := sim.clock.day_ms
	sim.advance_ms(2 * day_ms - _wait_ms() / 2 - _work_ms(0) - _work_ms(1))
	_tap()
	sim.advance_ms(_work_ms(0))
	var day := sim.clock.day_number()
	_tap()
	sim.advance_ms(_work_ms(1))
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
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_completed":
			stages.append(p["stage"]))
	for i in 3:
		var b := buildings.get_building(farm)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(buildings.remaining_ms(b))
		_tap()
		sim.advance_ms(int(BuildingSystem.MIN_WORK_SECONDS * work_scale(sim) * 1000.0))
	var b := buildings.get_building(farm)
	sim.advance_ms(buildings.remaining_ms(b))
	assert_eq(stages, ["sow", "water", "harvest"] as Array[String], "every stage still runs, in order")
	var w := buildings.current_stage({"type": "farm", "stage": 1})
	assert_near(buildings.stage_seconds({"type": "farm"}, w), BuildingSystem.MIN_WORK_SECONDS * work_scale(sim), 0.0001, "work has a floor (scaled like the work, Step 58)")
	assert_near(buildings.stage_cooldown({"type": "farm"}, w), _floor_s(), 0.0001, "and the ripening has its floor")
	assert_true(_floor_s() > 0.0, "a real floor: the plants always get time to drink")


func test_farm_data_keeps_the_rules() -> void:
	var stages: Array = GameData.load_default().building_type("farm")["cycle"]["stages"]
	var actions: Array = stages.map(func(st: Dictionary) -> String: return st["action"])
	assert_eq(actions, ["sow", "water", "harvest"], "sow, water, harvest")
	var total := 0.0
	for st: Dictionary in stages:
		assert_true(bool(st.get("required", false)), "%s is required" % st["id"])
		total += float(st["seconds"]) * work_scale(sim) + float(st.get("cooldown", 0.0))
	assert_near(total, 9.5, 0.0001, "a complete cycle by hand is 9.5 s (Step 58; Step 50: 5 s)")
	assert_true(float(stages[1]["cooldown"]) > 0.0, "the watered crop needs time to ripen")
	assert_true(float(stages[1]["cooldown_floor"]) < float(stages[1]["cooldown"]), "research can shorten that wait (floor below it)")
	assert_eq(int(stages[2]["yield"]["crop"]), 1, "harvest gives one batch of crops")
	assert_eq(String(GameData.load_default().item("crop").get("sell", "")), "instant", "sold the moment it is picked")


func test_a_ripe_farm_waits_on_a_new_island() -> void:
	var island := Simulation.new_island()
	var bs: BuildingSystem = island.system(&"buildings")
	assert_eq(bs.ids().size(), 1, "a new player's island has one farm")
	var b := bs.get_building(bs.ids()[0])
	assert_eq(String(bs.current_stage(b)["id"]), "harvest", "its crop ripe")
	assert_eq(int(b["completed"]), 0, "nobody has worked it yet")
	var eco: EconomySystem = island.system(&"economy")
	var before := eco.money
	assert_true(island.execute({"type": "building.tap", "id": b["id"]})["ok"], "the first tap is the harvest")
	island.advance_ms(int(float(bs.current_stage(b)["seconds"]) * work_scale(island) * 1000.0))
	assert_eq(eco.money - before, eco.unit_price("crop"), "and its money, within seconds")
	assert_eq(Simulation.new_game().system(&"buildings").ids().size(), 0, "the bare world for tests stays bare")
