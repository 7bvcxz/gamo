extends "res://tests/framework/test_case.gd"

## Step 58: the work and the Momo were far too quick -- every stage's work x2.5
## and a Momo's walk x1.3. Step 69: still too quick -- the work x2.5 again, so
## balance.pace.work_scale is 6.25 (2.5 x 2.5 of the data seconds, ONE
## multiplier applied once per stage: by hand, by a Momo, at a lab, in a
## smelter -- never 2.5 x 2.5 x 2.5), and construction, a timer of its own,
## x2.5 by balance.pace.build_scale. Step 78: still too quick -- every
## stage's work, every wait after a stage (a watered crop ripening) and every
## construction x5 more (balance.pace.production): work x31.25 of the data,
## waits x5, construction x12.5, each one factor applied once. Step 84: far
## too slow after all -- each production factor 5 -> 5/3, a third of Step
## 78's time: work x10.42 of the data, waits x1.67, construction x4.17
## (design/PACE84.md). The walk stays
## x1.3; the day, research times and offline time are not touched; research,
## skills, the Clock Tower and the legacy multiply on top as before; nothing
## doubles across a save; offline earns what online earns.

var sim: Simulation
var bs: BuildingSystem


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	bs = sim.system(&"buildings")


func _stage(type: String, i: int) -> Dictionary:
	return (sim.data.building_type(type)["cycle"]["stages"] as Array)[i]


func test_the_scales_are_data_and_as_asked() -> void:
	assert_near(sim.data.get_float("balance", "pace.work_scale", 0.0), 6.25, 0.0001, "work x6.25: Step 58's x2.5, x2.5 again (Step 69)")
	assert_near(sim.data.get_float("balance", "pace.build_scale", 0.0), 2.5, 0.0001, "construction x2.5 (Step 69)")
	for k: String in ["work", "wait", "build"]:
		assert_near(sim.data.get_float("balance", "pace.production." + k, 0.0), 5.0 / 3.0, 0.0001, "%s x5/3 (Step 78's x5, three times as fast -- Step 84)" % k)
	assert_near(sim.data.get_float("balance", "pace.travel_scale", 0.0), 1.3, 0.0001, "walking still x1.3")
	assert_near(bs.work_scale(), 31.25 / 3.0, 0.0001, "read by the buildings: 6.25 x 5/3")
	assert_near(bs.wait_scale(), 5.0 / 3.0, 0.0001, "the waits: x5/3")
	assert_near(bs.build_scale(), 12.5 / 3.0, 0.0001, "and the construction: 2.5 x 5/3")


func test_every_task_at_level_zero_takes_its_data_times_the_scales() -> void:
	# Step 84's seconds of work and wait: a third of Step 78's (31.25, 10 ...),
	# which were 5 times Step 69's (6.25, 2.0 ...).
	var step78 := {"farm": [[31.25, 0.0], [31.25, 10.0], [31.25, 0.0]], "mine": [[125.0, 30.0]], "lumberyard": [[125.0, 0.0], [62.5, 50.0]], "research": [[93.75, 30.0]], "smelter": [[312.5, 25.0]]}
	var expect := {}
	for type: String in step78:
		expect[type] = (step78[type] as Array).map(func(p: Array) -> Array: return [float(p[0]) / 3.0, float(p[1]) / 3.0])
	for type: String in expect:
		var id := bs.place_instant(type, Vector2i(1, 0))
		assert_true(id > 0, "%s placed" % type)
		var b := bs.get_building(id)
		for i in (expect[type] as Array).size():
			var st: Dictionary = bs.stages(b)[i]
			assert_near(bs.stage_seconds(b, st), float(expect[type][i][0]), 0.0001, "%s %s: %.1f s of work (data %.1f)" % [type, st["id"], expect[type][i][0], float(st["seconds"])])
			assert_near(bs.stage_cooldown(b, st), float(expect[type][i][1]), 0.0001, "%s %s: the wait x5/3" % [type, st["id"]])
		bs.demolish(id)


func test_a_tap_and_a_momo_take_the_scaled_time_once() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var r := sim.execute({"type": "building.tap", "id": farm})
	assert_eq(int(r["ends_ms"]) - sim.now_ms(), 10417, "a sowing by hand: 10.4 s (Step 78: 31.25 s, Step 69: 6.25 s, Step 58: 2.5 s, Step 50: 1 s)")
	sim.advance_ms(10417)
	var momos: MomoSystem = sim.system(&"momo")
	var x := momos.work_multiplier(1, "farm")
	var started := [0, 0]
	# The clock, not the simulation: a handler on its own bus that holds the
	# simulation keeps it alive for good (a leak at exit).
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p.get("worker", 0)) == 1 and started[0] == 0:
			started[0] = clock.now_ms
			started[1] = int(p["ends_ms"]))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var t := 0
	while started[0] == 0 and t < 120000:
		sim.advance_ms(100)
		t += 100
	assert_true(started[0] > 0, "the Momo started the watering")
	assert_eq(started[1] - started[0], int(round(31.25 / 3.0 * x * 1000.0)), "a Momo's watering: the scaled time times its own multiplier (%.2f), once" % x)


func test_research_and_the_clock_tower_multiply_on_top() -> void:
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	var b := bs.get_building(mine)
	var dig: Dictionary = bs.stages(b)[0]
	var plain := bs.stage_seconds(b, dig)
	var research: ResearchSystem = sim.system(&"research")
	research.completed["pickaxes"] = 0
	research.bought["pickaxes"] = 1
	var with_picks := bs.stage_seconds(b, dig)
	assert_true(with_picks < plain, "steel picks shorten the dig")
	var ratio := with_picks / plain
	var unit := Simulation.new_game(unit_pace())
	var ub := unit.system(&"buildings") as BuildingSystem
	var um := ub.place_instant("mine", Vector2i(1, 0))
	var ur: ResearchSystem = unit.system(&"research")
	ur.completed["pickaxes"] = 0
	ur.bought["pickaxes"] = 1
	assert_near(ratio, ub.stage_seconds(ub.get_building(um), dig) / float(dig["seconds"]), 0.0001, "by the same share as at the data's own pace: research is relative")
	# The Clock Tower's burst: half the work while it lasts.
	bs.place_instant("clock_tower", Vector2i(0, 1))
	var specials: SpecialSystem = sim.system(&"specials")
	var burst: Dictionary = specials.burst()
	if not burst["active"]:
		sim.advance_ms(int(burst["remaining_ms"]) + 1)
	assert_true(specials.burst()["active"], "the burst is on")
	var m := float(specials.effect("work_burst")["multiply"])
	assert_near(bs.stage_seconds(b, dig), with_picks * m, 0.0001, "the burst multiplies the scaled, researched dig (x%.2f)" % m)


func test_momo_walk_one_point_three_times_as_long() -> void:
	var momos: MomoSystem = sim.system(&"momo")
	var base := sim.data.get_float("balance", "momo.walk_speed", 0.0)
	assert_near(momos.walk_speed(), base / 1.3, 0.0001, "tiles a second, over 1.3")
	var m := momos.get_momo(1)
	var from := momos.position_of(1)
	var to := from + Vector2(3.0, 0.0)
	var arrive := momos._walk_to(m, to)
	assert_eq(arrive - sim.now_ms(), int(round(3.0 / (base / 1.3) * 1000.0)), "three tiles: %.1f s (was %.1f s)" % [3.0 / (base / 1.3), 3.0 / base])


func test_the_day_and_the_clock_are_untouched() -> void:
	assert_eq(sim.clock.day_ms, 30000, "a day is still 30 s")
	var research: ResearchSystem = sim.system(&"research")
	assert_eq(research.duration_ms("farm_expansion"), int(float(research.node("farm_expansion")["seconds"]) * 1000.0), "a research takes its own time, not scaled")


func test_a_save_mid_task_finishes_on_the_same_tick() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var end := int(sim.execute({"type": "building.tap", "id": farm})["ends_ms"])
	sim.advance_ms(1000)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var cb: BuildingSystem = copy.system(&"buildings")
	assert_eq(int(cb.get_building(farm)["task_end"]), end, "the end is kept, not scaled again")
	copy.advance_to(end - 1)
	assert_eq(cb.get_building(farm)["state"], BuildingSystem.WORKING, "still working 1 ms before")
	copy.advance_to(end)
	assert_eq(int(cb.get_building(farm)["completed"]), 1, "done exactly on time")


func test_offline_earns_what_online_earns() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var state := JSON.stringify(sim.save_state())
	var online := Simulation.from_save(JSON.parse_string(state))
	online.advance_ms(600000)
	var away := Simulation.from_save(JSON.parse_string(state))
	away.replaying = true
	away.advance_ms(600000)
	away.replaying = false
	var a := (online.system(&"economy") as EconomySystem).lifetime_income()
	var b := (away.system(&"economy") as EconomySystem).lifetime_income()
	assert_true(a > 0, "ten minutes of a Momo's farming earns")
	assert_eq(b, a, "away for the same time: the same money, once")


func test_the_job_cards_show_the_time_it_takes() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	for g: Dictionary in bs.action_groups(bs.get_building(farm)):
		assert_near(float(g["seconds"]), 31.25 / 3.0, 0.0001, "%s: 10.4 s on its card (Step 84; Step 78: 31.25)" % g["action"])
	assert_eq(ContextPanel.seconds_text(2.5), "2.5", "said with its half (it read '2 sec')")
	assert_eq(ContextPanel.seconds_text(6.25), "6.3", "Step 69's 6.25 s: rounded up, never shorter than it takes")
	assert_eq(ContextPanel.seconds_text(10.0), "10", "whole seconds as they are")


## Step 69: once per stage -- the slowdown is one multiplier on the data's
## seconds, whoever works and however it is reached; a stage is never timed
## at 2.5 x 2.5 x 2.5 (15.6x), and a later speed-up is relative to it.
func test_the_slowdown_is_applied_once() -> void:
	for type: String in ["farm", "mine", "lumberyard", "research", "smelter", "steam_engine", "car_factory", "game_studio"]:
		var id := bs.place_instant(type, Vector2i(1, 0))
		var b := bs.get_building(id)
		for st: Dictionary in bs.stages(b):
			assert_near(bs.stage_seconds(b, st) / float(st["seconds"]), 31.25 / 3.0, 0.0001, "%s %s: x10.42 of its data, once (not x6.25 x 5/3 x 5/3)" % [type, st.get("action", "")])
			if float(st.get("cooldown", 0.0)) > 0.0:
				assert_near(bs.stage_cooldown(b, st) / float(st["cooldown"]), 5.0 / 3.0, 0.0001, "%s %s: its wait x5/3 of its data, once" % [type, st.get("action", "")])
		bs.demolish(id)
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var end := int(sim.execute({"type": "building.tap", "id": farm})["ends_ms"])
	var est := bs.cycle_estimate(bs.get_building(farm))
	assert_near(float(est["work_seconds"]), 31.25, 0.0001, "the panel's estimate counts it once too (3 x 10.42 s)")
	assert_near(float(est["wait_seconds"]), 10.0 / 3.0, 0.0001, "and the wait once")
	assert_eq(end - sim.now_ms(), 10417, "and the timer the tap starts")


## Step 69: construction is a timer of its own, x2.5 by build_scale, once
## (x12.5 since Step 78, x4.17 since Step 84): the timer the placing starts, the refit's, the build
## list and the card.
func test_construction_takes_its_data_times_the_build_scales_once() -> void:
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		world.add_land(Vector2i(x, 2))
	(sim.system(&"economy") as EconomySystem).earn(1000000, "test")
	(sim.system(&"progression") as ProgressionSystem).add_exp(1000000, "test")
	for type: String in ["farm", "mine", "lumberyard", "research"]:
		var data_s := float(sim.data.building_type(type)["build_seconds"])
		assert_near(bs.build_seconds_of(type), data_s * 12.5 / 3.0, 0.0001, "%s: %.1f s to build (data %.1f)" % [type, data_s * 12.5 / 3.0, data_s])
	var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 2]})
	assert_true(r["ok"], "a farm placed")
	var b := bs.get_building(bs.building_at(Vector2i(0, 2)))
	assert_eq(int(b["build_end"]) - int(b["build_start"]), ms(bs.build_seconds_of("farm")), "its timer: the scaled time, once")
	var listed := bs.catalog().filter(func(o: Dictionary) -> bool: return String(o["type"]) == "farm")
	if not listed.is_empty():
		assert_near(float(listed[0]["build_seconds"]), bs.build_seconds_of("farm"), 0.0001, "the build list says the same")
	sim.advance_ms(ms(bs.build_seconds_of("farm")) - 1)
	assert_eq(b["state"], BuildingSystem.CONSTRUCTING, "1 ms before: still building")
	sim.advance_ms(1)
	assert_eq(b["state"], BuildingSystem.IDLE, "built on time")
