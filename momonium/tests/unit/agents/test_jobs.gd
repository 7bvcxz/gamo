extends "res://tests/framework/test_case.gd"

## Assigned Momo run their farm with nobody touching it: every stage, in
## order, at the Momo multiple of the player's work time (balance data), with
## the world's waits unchanged, sharing fairly, never doubling up.

var sim: Simulation
var buildings: BuildingSystem
var momos: MomoSystem
var inv: InventorySystem
var economy: EconomySystem
var farm := 0


func before_each() -> void:
	sim = Simulation.new_game()
	buildings = sim.system(&"buildings")
	momos = sim.system(&"momo")
	inv = sim.system(&"inventory")
	economy = sim.system(&"economy")
	farm = buildings.place_instant("farm", Vector2i(1, 0))


## A Momo stage of the farm (5 s for the player) and the wait after a
## watering, in ms, as the data gives them.
func _momo_stage_ms() -> int:
	return int(round(5.0 * sim.data.get_float("balance", "momo.work_time_multiplier", 4.0) * 1000.0))


func _wait_ms() -> int:
	return int(float(sim.data.building_type("farm")["cycle"]["stages"][1]["cooldown"]) * 1000.0)


func _log() -> Array:
	var log: Array = []
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started":
			log.append(["start", p["stage"], p["worker"], clock.now_ms])
		elif t == &"task_completed":
			log.append(["done", p["stage"], p["worker"], clock.now_ms]))
	return log


func test_a_momo_runs_the_whole_cycle_unattended() -> void:
	var log := _log()
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var arrived_at := int(momos.get_momo(1)["end"])
	sim.advance_to(arrived_at + _momo_stage_ms() * 5 + _wait_ms() * 3 + 100)
	var starts := log.filter(func(e: Array) -> bool: return e[0] == "start")
	assert_eq(starts[0][3], arrived_at, "work began the moment Momo reached the farm, without a tap")
	assert_eq(starts[0][2], 1, "done by Momo 1")
	var done := log.filter(func(e: Array) -> bool: return e[0] == "done").map(func(e: Array) -> String: return e[1])
	assert_eq(done.slice(0, 5), ["sow", "water1", "water2", "water3", "harvest"], "every stage, in order, no taps")
	assert_eq(inv.count("crop") + int(economy.money > 10), 1, "one batch harvested (in store, or already sold)")


func test_momo_time_is_the_momo_multiple_and_waits_are_unchanged() -> void:
	var log := _log()
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var t0 := int(momos.get_momo(1)["end"])
	var m := _momo_stage_ms()
	sim.advance_to(t0 + m + m + _wait_ms() + m + 10)
	var times := log.map(func(e: Array) -> Array: return [e[0], e[1], e[3] - t0])
	assert_eq(times[1], ["done", "sow", m], "sowing takes the Momo multiple of 5 s")
	assert_eq(times[3], ["done", "water1", 2 * m], "so does watering")
	assert_eq(times[4], ["start", "water2", 2 * m + _wait_ms()], "the next watering waits exactly the world's wait")


func test_harvests_sell_and_the_farm_keeps_going() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000 * 30)
	var b := buildings.get_building(farm)
	assert_true(int(b["completed"]) >= 15, "three cycles in thirty days, all by Momo (%d stages)" % b["completed"])
	assert_true(economy.money >= 10 + 15, "and the crops turned into money ($%d)" % economy.money)


func test_assigned_momo_work_under_the_moon() -> void:
	# As in the reference night scene: a working Momo keeps watering at night.
	# An array, not a bool: a GDScript lambda captures locals by value, so
	# assigning a captured bool inside it would never reach this scope.
	var night_starts := [0]
	var clock := sim.clock
	var cycle := DayCycle.new(sim.data)
	sim.bus.emitted.connect(func(t: StringName, _p: Dictionary) -> void:
		if t == &"task_started" and cycle.is_night(clock):
			night_starts[0] += 1)
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000 * 12)
	assert_true(night_starts[0] > 0, "work starts at night too (%d times)" % night_starts[0])


func test_night_rest_is_a_data_switch() -> void:
	var balance: Dictionary = GameData.load_default().table("balance").duplicate(true)
	balance["momo"]["works_at_night"] = false
	sim = Simulation.new_game(GameData.from_tables({"balance": balance}))
	buildings = sim.system(&"buildings")
	farm = buildings.place_instant("farm", Vector2i(1, 0))
	# An array, not a bool: a GDScript lambda captures locals by value, so
	# assigning a captured bool inside it would never reach this scope.
	var night_starts := [0]
	var clock := sim.clock
	var cycle := DayCycle.new(sim.data)
	sim.bus.emitted.connect(func(t: StringName, _p: Dictionary) -> void:
		if t == &"task_started" and cycle.is_night(clock):
			night_starts[0] += 1)
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000 * 4)
	assert_eq(night_starts[0], 0, "with works_at_night off, no work starts at night")
	assert_true(int(buildings.get_building(farm)["completed"]) >= 2, "but the day's work still happens")


func test_two_farms_two_momos_work_independently() -> void:
	economy.earn(100, "test")
	sim.execute({"type": "momo.hire"})
	var farm2 := buildings.place_instant("farm", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.execute({"type": "momo.assign", "momo": 2, "building": farm2})
	sim.advance_ms(30000 * 8)
	assert_true(int(buildings.get_building(farm)["completed"]) >= 5, "farm 1 cycles")
	assert_true(int(buildings.get_building(farm2)["completed"]) >= 5, "farm 2 cycles")


func test_shared_building_takes_turns() -> void:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["farm"]["workers"] = 2
	sim = Simulation.new_game(GameData.from_tables({"buildings": b}))
	buildings = sim.system(&"buildings")
	momos = sim.system(&"momo")
	(sim.system(&"economy") as EconomySystem).earn(100, "test")
	sim.execute({"type": "momo.hire"})
	farm = buildings.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.execute({"type": "momo.assign", "momo": 2, "building": farm})
	var workers: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started":
			workers.append(p["worker"]))
	sim.advance_ms(30000 * 10)
	assert_true(workers.size() >= 5, "several stages done (%s)" % [workers])
	assert_true(workers.has(1) and workers.has(2), "both Momo take turns (%s)" % [workers])
	for i in range(1, workers.size()):
		assert_ne(workers[i], workers[i - 1], "the one who waited longest goes next")


func test_no_stage_is_ever_started_or_completed_twice() -> void:
	var log := _log()
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	for i in 400:
		sim.advance_ms(997)
		sim.execute({"type": "building.tap", "id": farm})
	var open := 0
	for e: Array in log:
		open += 1 if e[0] == "start" else -1
		assert_between(float(open), 0.0, 1.0, "never two stages at once")
	var b := buildings.get_building(farm)
	var completions := log.filter(func(e: Array) -> bool: return e[0] == "done").size()
	assert_eq(completions, int(b["completed"]), "every completion counted once")


func test_a_full_store_makes_momo_wait_and_the_sale_frees_it() -> void:
	inv.add("crop", inv.capacity("crop"))
	var b := buildings.get_building(farm)
	b["stage"] = 4
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(6000)
	assert_eq(b["state"], BuildingSystem.IDLE, "cannot harvest into a full store: Momo waits")
	sim.advance_to(sim.clock.next_day_start_ms() + 10)
	assert_eq(b["state"], BuildingSystem.WORKING, "after the day's sale Momo harvests")


func test_unattended_runs_are_deterministic() -> void:
	var results: Array = []
	for chunk: int in [16, 1000, 7777]:
		var s := Simulation.new_game()
		var bs: BuildingSystem = s.system(&"buildings")
		var f := bs.place_instant("farm", Vector2i(1, 0))
		s.execute({"type": "momo.assign", "momo": 1, "building": f})
		var t := 0
		while t < 30000 * 6:
			var step := mini(chunk, 30000 * 6 - t)
			s.advance_ms(step)
			t += step
		results.append([bs.get_building(f)["completed"], (s.system(&"inventory") as InventorySystem).count("crop"),
			(s.system(&"economy") as EconomySystem).money, (s.system(&"momo") as MomoSystem).position_of(1)])
	assert_eq(results[1], results[0], "1 s steps match 16 ms steps")
	assert_eq(results[2], results[0], "7.8 s steps match too")
