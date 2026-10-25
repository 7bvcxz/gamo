extends "res://tests/framework/test_case.gd"

var data: GameData
var cycle: DayCycle


func before_each() -> void:
	data = GameData.load_default()
	cycle = DayCycle.new(data)


func test_phases_follow_the_data() -> void:
	assert_eq(cycle.phase_at(0.0), &"day", "Day N, 00 s is daylight (as in the reference)")
	assert_eq(cycle.phase_at(0.3), &"day", "midday")
	assert_eq(cycle.phase_at(0.6), &"sunset", "sunset")
	assert_eq(cycle.phase_at(0.85), &"night", "night")
	assert_eq(cycle.phase_at(0.97), &"dawn", "the next dawn starts before the day rolls over")
	assert_eq(cycle.phase_at(1.3), &"day", "progress wraps")


func test_one_day_runs_through_every_phase_in_order() -> void:
	var seen: Array[StringName] = []
	for i in 300:
		var p := cycle.phase_at(i / 300.0)
		if seen.is_empty() or seen[-1] != p:
			seen.append(p)
	assert_eq(seen, [&"day", &"sunset", &"night", &"dawn"] as Array[StringName], "day -> sunset -> night -> dawn, then the next day")


func test_phase_comes_from_the_simulation_clock() -> void:
	var sim := Simulation.new_game()
	assert_eq(cycle.phase(sim.clock), &"day", "Day 1, 00 s")
	sim.advance_ms(int(0.3 * 30000))
	assert_eq(cycle.phase(sim.clock), &"day", "9 s in")
	sim.advance_ms(int(0.55 * 30000))
	assert_true(cycle.is_night(sim.clock), "25.5 s in is night")
	sim.advance_ms(30000 * 7)
	assert_eq(sim.clock.day_number(), 8, "seven days later it is Day 8")
	assert_true(cycle.is_night(sim.clock), "same moment of a later day, same phase")


func test_day_rollover_is_exact_and_frame_independent() -> void:
	for step: int in [1, 7, 16, 33, 1000]:
		var sim := Simulation.new_game()
		var days: Array[int] = []
		sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
			if type == &"day_started":
				days.append(int(p["day"])))
		var t := 0
		while t < 30000 * 3 + 5:
			sim.advance_ms(step)
			t += step
		assert_eq(days, [2, 3, 4] as Array[int], "steps of %d ms see Day 2, 3, 4 exactly once" % step)


func test_bad_phase_tables_are_rejected() -> void:
	var balance: Dictionary = data.table("balance").duplicate(true)
	balance["clock"]["phases"] = [{"name": "day", "from": 0.5}, {"name": "night", "from": 0.2}]
	var broken := GameData.from_tables({"balance": balance})
	assert_false(broken.is_valid(), "phases must start at 0 and increase")
