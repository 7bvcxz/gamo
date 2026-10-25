extends "res://tests/framework/test_case.gd"

## The generic building task cycle: tap starts the next stage, it ends by
## itself at exactly its duration, cooldowns hold the next stage, and several
## buildings run independently and deterministically.

var sim: Simulation
var buildings: BuildingSystem
var world: WorldSystem


func _data_with_cycle(stages: Array) -> GameData:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["farm"]["cycle"]["stages"] = stages
	return GameData.from_tables({"buildings": b})


func before_each() -> void:
	sim = Simulation.new_game(_data_with_cycle([
		{"id": "a", "seconds": 5, "cooldown": 0},
		{"id": "b", "seconds": 5, "cooldown": 30},
		{"id": "c", "seconds": 2, "cooldown": 0}]))
	buildings = sim.system(&"buildings")
	world = sim.system(&"world")


func test_placing_occupies_the_footprint() -> void:
	var id := buildings.place_instant("farm", Vector2i(1, 1))
	assert_true(id > 0, "placed")
	assert_eq(world.occupant(Vector2i(1, 1)), id, "the cell knows its building")
	assert_eq(buildings.building_at(Vector2i(1, 1)), id, "and the building is found by cell")
	assert_eq(buildings.place_instant("farm", Vector2i(1, 1)), 0, "cannot stack on it")
	assert_eq(buildings.place_instant("farm", Vector2i(7, 7)), 0, "cannot place at sea")


func test_tap_starts_now_and_ends_exactly_on_time() -> void:
	var id := buildings.place_instant("farm", Vector2i(0, 0))
	sim.advance_ms(1234)
	var r := sim.execute({"type": "building.tap", "id": id})
	assert_true(r["ok"], "a ready building starts at once")
	assert_eq(r["ends_ms"], 6234, "ends 5 s after the tap")
	var b := buildings.get_building(id)
	assert_eq(b["state"], BuildingSystem.WORKING, "working")
	sim.advance_ms(4999)
	assert_eq(b["state"], BuildingSystem.WORKING, "1 ms before the end, still working")
	sim.advance_ms(1)
	assert_eq(b["state"], BuildingSystem.IDLE, "done at exactly 5 s")
	assert_eq(b["stage"], 1, "and the next stage is up")
	assert_eq(b["completed"], 1, "one stage completed")


func test_busy_and_cooldown_refuse_with_time_left() -> void:
	var id := buildings.place_instant("farm", Vector2i(0, 0))
	sim.execute({"type": "building.tap", "id": id})
	sim.advance_ms(2000)
	var r := sim.execute({"type": "building.tap", "id": id})
	assert_false(r["ok"], "a working building refuses")
	assert_eq(r["reason"], "err.busy", "busy")
	assert_eq(r["remaining_ms"], 3000, "with the time left")
	sim.advance_ms(3000)
	sim.execute({"type": "building.tap", "id": id})
	sim.advance_ms(5000)
	var b := buildings.get_building(id)
	assert_eq(b["state"], BuildingSystem.COOLDOWN, "stage b is followed by a 30 s cooldown")
	r = sim.execute({"type": "building.tap", "id": id})
	assert_eq(r["reason"], "err.cooldown", "cooldown refuses")
	assert_eq(r["remaining_ms"], 30000, "the whole cooldown is left")
	sim.advance_ms(29999)
	assert_false(buildings.is_ready(b), "not a millisecond early")
	sim.advance_ms(1)
	assert_true(buildings.is_ready(b), "ready when the cooldown ends")
	assert_true(sim.execute({"type": "building.tap", "id": id})["ok"], "and stage c can start")


func test_buildings_work_independently() -> void:
	var a := buildings.place_instant("farm", Vector2i(0, 0))
	var b := buildings.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "building.tap", "id": a})
	sim.advance_ms(2000)
	sim.execute({"type": "building.tap", "id": b})
	var done: Array = []
	# Capture the clock, not the simulation: a lambda on the sim's own bus that
	# holds the sim is a reference cycle, and RefCounted never frees it.
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_completed":
			done.append([p["id"], clock.now_ms]))
	sim.advance_ms(10000)
	assert_eq(done, [[a, 5000], [b, 7000]], "each finishes at its own time")


func test_rapid_taps_start_one_task() -> void:
	var id := buildings.place_instant("farm", Vector2i(0, 0))
	var started := [0]
	sim.bus.emitted.connect(func(t: StringName, _p: Dictionary) -> void:
		if t == &"task_started":
			started[0] += 1)
	for i in 10:
		sim.execute({"type": "building.tap", "id": id})
	assert_eq(started[0], 1, "ten taps in one instant start one task")


func test_unknown_building_is_refused() -> void:
	assert_eq(sim.execute({"type": "building.tap", "id": 999})["reason"], "err.no_building", "no such building")


func test_save_mid_task_and_finish_on_time() -> void:
	var id := buildings.place_instant("farm", Vector2i(0, 0))
	sim.advance_ms(500)
	sim.execute({"type": "building.tap", "id": id})
	sim.advance_ms(3000)
	var data := _data_with_cycle([{"id": "a", "seconds": 5, "cooldown": 0}, {"id": "b", "seconds": 5, "cooldown": 30}, {"id": "c", "seconds": 2, "cooldown": 0}])
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())), data)
	var cb: BuildingSystem = copy.system(&"buildings")
	assert_eq(cb.get_building(id)["state"], BuildingSystem.WORKING, "still working after the load")
	copy.advance_ms(1999)
	assert_eq(cb.get_building(id)["state"], BuildingSystem.WORKING, "not finished early")
	copy.advance_ms(1)
	assert_eq(cb.get_building(id)["state"], BuildingSystem.IDLE, "finished at the original end time")
	assert_eq(copy.system(&"world").call("occupant", Vector2i(0, 0)), id, "occupancy survived")


func test_shipped_cycle_data_is_valid() -> void:
	var data := GameData.load_default()
	assert_true(data.is_valid(), "%s" % [data.errors])
	var broken: Dictionary = data.table("buildings").duplicate(true)
	broken["types"]["farm"]["cycle"]["stages"] = [{"id": "x", "seconds": 0}]
	assert_false(GameData.from_tables({"buildings": broken}).is_valid(), "a stage that takes no time is rejected")
