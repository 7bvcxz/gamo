extends "res://tests/framework/test_case.gd"

const Probe := preload("res://tests/support/probe_system.gd")


func _sim_with_probe() -> Simulation:
	var systems: Array[SimSystem] = SystemRegistry.create_default()
	systems.append(Probe.new())
	return Simulation.new_game(null, systems)


func test_new_game_follows_the_starting_rules() -> void:
	var sim := Simulation.new_game()
	var economy: EconomySystem = sim.system(&"economy")
	var progression: ProgressionSystem = sim.system(&"progression")
	assert_eq(economy.money, 10, "a new game has $10")
	assert_eq(progression.level, 1, "Level 1")
	assert_eq(progression.experience, 0, "0 EXP")
	assert_eq(sim.clock.day_number(), 1, "Day 1")
	assert_eq(sim.clock.day_ms, 30000, "a day is 30 real seconds")


func test_day_started_fires_on_each_boundary() -> void:
	var sim := _sim_with_probe()
	var days: Array[int] = []
	sim.bus.emitted.connect(func(type: StringName, payload: Dictionary) -> void:
		if type == &"day_started":
			days.append(payload["day"]))
	sim.advance_ms(29999)
	assert_eq(days.size(), 0, "no new day before 30 s")
	sim.advance_ms(1)
	assert_eq(days, [2] as Array[int], "Day 2 begins at exactly 30 s")
	sim.advance_ms(30000 * 3)
	assert_eq(days, [2, 3, 4, 5] as Array[int], "one event per boundary even in a single big step")


func test_result_does_not_depend_on_frame_chunking() -> void:
	var histories: Array = []
	for chunk: int in [16, 17, 1000, 95000]:
		var sim := _sim_with_probe()
		sim.execute({"type": "probe.schedule", "delay": 5000, "data": {"tag": "farm", "repeat": 6, "every": 7000}})
		sim.execute({"type": "probe.schedule", "delay": 12000, "data": {"tag": "mine", "repeat": 3, "every": 9000}})
		var elapsed := 0
		while elapsed < 95000:
			var step := mini(chunk, 95000 - elapsed)
			sim.advance_ms(step)
			elapsed += step
		var probe: SimSystem = sim.system(&"probe")
		histories.append(probe.get("history"))
	for i in range(1, histories.size()):
		assert_eq(histories[i], histories[0], "chunk size %d gives the same history" % [16, 17, 1000, 95000][i])
	assert_true((histories[0] as Array).size() > 10, "the history is not trivially empty")


func test_real_seconds_carry_fractions() -> void:
	var sim := Simulation.new_game()
	for i in 600:
		sim.advance_seconds(1.0 / 60.0)
	assert_between(sim.now_ms(), 9999, 10000, "600 frames of 1/60 s are 10 s, not 9.6 s of truncated ms")
	sim.time_scale = 10.0
	sim.advance_seconds(1.0)
	assert_between(sim.now_ms(), 19999, 20000, "time_scale multiplies real time")


func test_save_and_load_continue_identically() -> void:
	var a := _sim_with_probe()
	a.execute({"type": "probe.schedule", "delay": 4000, "data": {"tag": "p", "repeat": 10, "every": 6000}})
	(a.system(&"economy") as EconomySystem).spend(3, "test")
	a.advance_ms(20000)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(a.save_state()))
	var systems: Array[SimSystem] = SystemRegistry.create_default()
	systems.append(Probe.new())
	var b := Simulation.from_save(saved, null, systems)
	assert_eq(b.now_ms(), 20000, "time restored")
	assert_eq((b.system(&"economy") as EconomySystem).money, 7, "money restored")
	a.advance_ms(60000)
	b.advance_ms(60000)
	assert_eq(b.system(&"probe").get("history"), a.system(&"probe").get("history"), "both continue with the same history")


func test_unknown_command_is_refused() -> void:
	var sim := Simulation.new_game()
	var result := sim.execute({"type": "no.such.thing"})
	assert_false(result["ok"], "unknown command fails")
	assert_eq(result["reason"], "err.unknown_command", "with a stable reason key")


func test_economy_spend_rules() -> void:
	var sim := Simulation.new_game()
	var economy: EconomySystem = sim.system(&"economy")
	assert_false(economy.spend(11, "test"), "cannot spend more than $10")
	assert_eq(economy.money, 10, "a refused spend changes nothing")
	assert_false(economy.spend(-5, "test"), "negative spend is refused")
	assert_true(economy.spend(10, "test"), "can spend exactly what there is")
	assert_eq(economy.money, 0, "nothing left")
