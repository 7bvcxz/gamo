extends "res://tests/framework/test_case.gd"

## What the landmarks do: the Clock Tower's burst of double-speed work, on
## the game clock (the same live, after a reload, offline, and whatever is
## pulled down and rebuilt); the School's +20% experience, fractions carried;
## the Momo Monument's +10% legacy, rounded half up. Effects only while one
## stands finished, and through the same pipeline as research.

var sim: Simulation
var bs: BuildingSystem
var sp: SpecialSystem


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	bs = sim.system(&"buildings")
	sp = sim.system(&"specials")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))


func test_the_burst_follows_the_game_clock() -> void:
	assert_false(sp.burst()["standing"], "no tower, no burst")
	var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	assert_true(r["ok"], "")
	bs.place_instant("clock_tower", Vector2i(2, 2))
	var at := func(ms: int) -> Dictionary: return sp.burst(ms)
	assert_true(at.call(0)["active"], "the first 30 s of each 3 minutes")
	assert_eq(at.call(29999)["remaining_ms"], 1, "to the millisecond")
	assert_false(at.call(30000)["active"], "then a wait")
	assert_eq(at.call(30000)["remaining_ms"], 150000, "of 150 s")
	assert_true(at.call(180000 * 7 + 5)["active"], "every cycle, forever")


func test_work_in_a_burst_takes_half_as_long() -> void:
	var yard := bs.place_instant("lumberyard", Vector2i(0, 0))
	var b := bs.get_building(yard)
	var stage: Dictionary = bs.stages(b)[0]
	var plain := bs.stage_seconds(b, stage)
	bs.place_instant("clock_tower", Vector2i(2, 2))
	sim.advance_to(185000)
	assert_true(sp.burst()["active"], "a burst")
	assert_near(bs.stage_seconds(b, stage), plain * 0.5, 0.001, "chopping takes half as long")
	(sim.system(&"research") as ResearchSystem).completed["sharp_axes"] = 0
	var axes := float((sim.system(&"research") as ResearchSystem).effects_at("sharp_axes", 1)[0]["multiply"])
	assert_near(bs.stage_seconds(b, stage), maxf(plain * 0.5 * axes, 1.0), 0.001, "times research, never under the floor")
	sim.advance_to(240000)
	assert_false(sp.burst()["active"], "between bursts")
	assert_near(bs.stage_seconds(b, stage), plain * axes, 0.001, "research alone")


func test_only_while_it_stands_finished() -> void:
	(sim.system(&"progression") as ProgressionSystem).level = 6
	(sim.system(&"economy") as EconomySystem).earn(2000, "test")
	(sim.system(&"inventory") as InventorySystem).add("stone", 50, "test")
	(sim.system(&"inventory") as InventorySystem).add("copper_ingot", 10, "test")
	var r := sim.execute({"type": "building.place", "building": "clock_tower", "anchor": [2, 2]})
	assert_false(sp.burst()["standing"], "rising: no burst yet")
	sim.advance_ms(31000)
	assert_true(sp.burst()["standing"], "finished: it rings")
	sim.execute({"type": "building.demolish", "id": r["id"]})
	assert_false(sp.burst()["standing"], "pulled down: gone")
	assert_eq(sp.stage_multiplier("work", "farm", "sow"), 1.0, "and its effect with it")


func test_a_rebuild_or_a_reload_never_moves_the_cycle() -> void:
	bs.place_instant("clock_tower", Vector2i(2, 2))
	sim.advance_to(100000)
	var before := sp.burst()
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_eq((copy.system(&"specials") as SpecialSystem).burst(), before, "the same after a reload")
	bs.demolish(bs.special_built("clock_tower"))
	bs.special_cooldowns.clear()
	bs.place_instant("clock_tower", Vector2i(2, 2))
	assert_eq(sp.burst(), before, "and after pulling down and rebuilding at once")


func test_offline_is_the_same_as_playing() -> void:
	var make := func() -> Simulation:
		var s := with_starter_momo(Simulation.new_game())
		var w: WorldSystem = s.system(&"world")
		for x in 3:
			for y in 3:
				w.add_land(Vector2i(x, y))
		var b: BuildingSystem = s.system(&"buildings")
		var y1 := b.place_instant("lumberyard", Vector2i(0, 0))
		b.place_instant("clock_tower", Vector2i(2, 2))
		s.execute({"type": "momo.assign", "momo": 1, "building": y1})
		return s
	var live: Simulation = make.call()
	var away: Simulation = make.call()
	live.advance_ms(900000)
	OfflineProgress.catch_up(away, 900000)
	assert_eq((away.system(&"inventory") as InventorySystem).count("wood"), (live.system(&"inventory") as InventorySystem).count("wood"), "15 minutes away make what 15 minutes played make")


func test_the_school_teaches_a_fifth_more() -> void:
	var farm := bs.place_instant("farm", Vector2i(0, 0))
	bs.place_instant("school", Vector2i(2, 2))
	var momos: MomoSystem = sim.system(&"momo")
	for i in 10:
		sim.bus.emit(&"task_completed", {"id": farm, "stage": "sow", "type": "farm", "worker": 1})
	assert_eq(int(momos.get_momo(1)["experience"]["farm"]), 12, "10 jobs, 12 points of skill (1.2 each, fractions carried)")
	var prog: ProgressionSystem = sim.system(&"progression")
	var m0 := int(prog.mastery_of("farm")["exp"])
	prog.add_mastery("farm", 5)
	assert_eq(int(prog.mastery_of("farm")["exp"]) - m0, 6, "mastery too: 5 -> 6")
	bs.demolish(bs.special_built("school"))
	for i in 5:
		sim.bus.emit(&"task_completed", {"id": farm, "stage": "sow", "type": "farm", "worker": 1})
	assert_eq(int(momos.get_momo(1)["experience"]["farm"]), 17, "no school: one each again")


func test_the_monument_rounds_half_up() -> void:
	bs.place_instant("momo_monument", Vector2i(2, 2))
	assert_eq([sp.legacy_bonus(4), sp.legacy_bonus(5), sp.legacy_bonus(10), sp.legacy_bonus(14), sp.legacy_bonus(15)], [0, 1, 1, 1, 2], "10%, half up")
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 8:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	var a := (sim.system(&"prestige") as PrestigeSystem).appraise()
	assert_eq(int(a["points"]), int(a["points_base"]) + sp.legacy_bonus(int(a["points_base"])), "the sale counts it")
	var r := PrestigeSystem.sell(sim)
	assert_eq(((r["sim"] as Simulation).system(&"prestige") as PrestigeSystem).points, int(a["points"]), "and pays it")


func test_the_tower_makes_real_work_go_faster() -> void:
	# The burst shortens work, not the world's waits (a tree still takes its
	# time to grow): a Momo's stage started in a burst really ends sooner.
	var y1 := bs.place_instant("lumberyard", Vector2i(0, 0))
	bs.place_instant("clock_tower", Vector2i(2, 2))
	var spans: Array[int] = []
	# The Momo's own pace when that first stage began (its skill grows with
	# every stage, and five-second work cycles give it many, Step 50).
	var pace := [0.0]
	var watch := func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p["id"]) == y1:
			var b := bs.get_building(y1)
			if spans.is_empty():
				pace[0] = (sim.system(&"momo") as MomoSystem).work_multiplier(1, "lumberyard")
			spans.append(int(b["task_end"]) - int(b["task_start"]))
	sim.bus.emitted.connect(watch)
	sim.advance_to(185000)
	sim.execute({"type": "momo.assign", "momo": 1, "building": y1})
	sim.advance_to(190000)
	assert_true(not spans.is_empty(), "the Momo started chopping in the burst")
	var in_burst := spans[0]
	spans.clear()
	sim.advance_to(180000 * 2 - 1)
	var outside: Array[int] = spans.filter(func(x: int) -> bool: return x > in_burst)
	assert_true(not outside.is_empty(), "stages started between bursts take longer (%d ms in a burst, %s after)" % [in_burst, spans])
	sim.bus.emitted.disconnect(watch)
	sim.advance_to(180000 * 2 + 40000)
	var b := bs.get_building(y1)
	var chop: Dictionary = bs.stages(b)[0]
	assert_eq(in_burst * 2, int(round(bs.stage_seconds(b, chop) * 1000.0 * float(pace[0]))), "exactly half of a chop outside a burst")
