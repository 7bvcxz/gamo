extends "res://tests/framework/test_case.gd"

## Power as capacity: generators that differ in kind (sun, wind, a stoked
## boiler, a wheel on the shore), buildings that draw while they work and
## speed up with the share they get, brownouts that slow -- or, for a
## building that needs power, stop -- what starts during them.

var sim: Simulation
var bs: BuildingSystem
var power: PowerSystem
var research: ResearchSystem
var inv: InventorySystem


func before_each() -> void:
	sim = Simulation.new_game()
	bs = sim.system(&"buildings")
	power = sim.system(&"power")
	research = sim.system(&"research")
	inv = sim.system(&"inventory")


func test_solar_follows_the_sun() -> void:
	var p := bs.place_instant("solar_panel", Vector2i(0, 0))
	var day := sim.clock.day_ms
	var noon := int(day * fposmod(0.92 + 0.78 * 0.5, 1.0))
	assert_near(power.output_of(p, noon), 4.0, 0.001, "full 4 kW at midday")
	assert_eq(power.output_of(p, int(day * 0.8)), 0.0, "nothing at night")
	assert_true(power.output_of(p, int(day * 0.1)) > 0.0 and power.output_of(p, int(day * 0.1)) < 4.0, "some in the morning")
	assert_near(power.output_of(p, noon - 3000), power.output_of(p, noon + 3000), 0.001, "a symmetric arc")
	assert_eq(power.output_of(p, noon + day * 5), power.output_of(p, noon), "the same every day")


func test_wind_varies_smoothly_day_and_night() -> void:
	var w := bs.place_instant("wind_turbine", Vector2i(0, 0))
	var lo := 9.0
	var hi := 0.0
	var prev := power.wind(0)
	var biggest_step := 0.0
	for s in range(0, 30 * 9 * 1000, 1000):
		var v := power.wind(s)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		biggest_step = maxf(biggest_step, absf(v - prev))
		prev = v
	assert_true(lo >= 0.1 and hi <= 1.0, "between the floor and full (%.2f..%.2f)" % [lo, hi])
	assert_true(hi - lo > 0.3, "it really varies over days")
	assert_true(biggest_step < 0.08, "and smoothly, no jumps (%.3f a second -- days are 30 s)" % biggest_step)
	assert_true(power.output_of(w, int(sim.clock.day_ms * 0.8)) > 0.0, "at night too")
	assert_eq(power.wind(123456), power.wind(123456), "deterministic")


func test_steam_runs_while_stoked() -> void:
	var e := bs.place_instant("steam_engine", Vector2i(0, 0))
	assert_eq(power.output_of(e, sim.now_ms()), 0.0, "a cold boiler gives nothing")
	assert_eq(sim.execute({"type": "building.tap", "id": e})["reason"], "err.missing_inputs", "no wood, no fire")
	inv.add("wood", 2, "test")
	assert_true(sim.execute({"type": "building.tap", "id": e})["ok"], "stoked")
	assert_eq(inv.count("wood"), 1, "one log into the firebox")
	sim.advance_ms(3000)
	assert_eq(power.output_of(e, sim.now_ms()), 5.0, "5 kW once the fire is going")
	sim.advance_ms(29000)
	assert_eq(power.output_of(e, sim.now_ms()), 5.0, "for 30 s")
	sim.advance_ms(1500)
	assert_eq(power.output_of(e, sim.now_ms()), 0.0, "then cold again")


func test_a_momo_keeps_the_boiler_fired() -> void:
	var e := bs.place_instant("steam_engine", Vector2i(0, 0))
	inv.add("wood", 10, "test")
	var stokes := [0]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and p["stage"] == "stoke":
			stokes[0] += 1)
	sim.execute({"type": "momo.assign", "momo": 1, "building": e})
	var on := 0
	for i in 200:
		sim.advance_ms(1000)
		if power.output_of(e, sim.now_ms()) > 0.0:
			on += 1
	assert_true(on > 120, "running most of the time while there is wood (%d of 200 s)" % on)
	assert_eq(inv.count("wood"), 10 - stokes[0], "one log per stoking, no more, no less")
	sim.advance_ms(200000)
	assert_eq(power.output_of(e, sim.now_ms()), 0.0, "cold when the wood is gone")
	assert_eq(bs.blocked(bs.get_building(e)), {"missing": {"wood": 1}}, "and it says so")


func test_the_water_wheel_needs_the_shore() -> void:
	(sim.system(&"economy") as EconomySystem).earn(5000, "test")
	for c: Array in [[2, 0], [2, 1], [2, 2], [0, 2], [1, 2]]:
		sim.execute({"type": "land.buy", "cell": c})
	(sim.system(&"progression") as ProgressionSystem).add_exp(5000, "test")
	research.completed["hydropower"] = 0
	inv.add("wood", 30, "test")
	inv.add("iron_ingot", 2, "test")
	var inner := bs.place_instant("lumberyard", Vector2i(1, 1))
	var edge := bs.place_instant("lumberyard", Vector2i(0, 1))
	assert_eq(sim.execute({"type": "building.refit", "id": inner, "building": "water_wheel"})["reason"], "err.needs_shore", "not in the middle of the island")
	assert_true(sim.execute({"type": "building.refit", "id": edge, "building": "water_wheel"})["ok"], "on the edge, beside the sea")
	sim.advance_ms(16000)
	var w := edge
	assert_eq(power.output_of(w, 0), 3.0, "steady")
	assert_eq(power.output_of(w, int(sim.clock.day_ms * 0.8)), 3.0, "night and day")


func test_generators_open_through_research() -> void:
	(sim.system(&"progression") as ProgressionSystem).add_exp(5000, "test")
	(sim.system(&"economy") as EconomySystem).earn(1000, "test")
	inv.add("copper_ingot", 5, "test")
	inv.add("stone", 10, "test")
	var lab := bs.place_instant("research", Vector2i(0, 0))
	assert_eq(sim.execute({"type": "building.refit", "id": lab, "building": "solar_panel"})["reason"], "err.needs_research", "the level is there, the research is not")
	var entry: Dictionary = bs.refits(lab).filter(func(e: Dictionary) -> bool: return e["type"] == "solar_panel")[0]
	assert_eq([entry["level_met"], entry["research"], entry["research_met"]], [true, "photovoltaics", false], "the refit list says which research")
	research.completed["photovoltaics"] = 0
	assert_true(sim.execute({"type": "building.refit", "id": lab, "building": "solar_panel"})["ok"], "researched: the lab gets its solar roof")


func test_power_speeds_up_what_uses_it() -> void:
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	var m := bs.get_building(mine)
	assert_eq(bs.stage_seconds(m, bs.current_stage(m)), 8.0, "a plain mine: 8 s")
	research.completed["electric_drill"] = 0
	assert_eq(bs.stage_seconds(m, bs.current_stage(m)), 8.0, "an electric drill with no power: still 8 s, never worse")
	bs.place_instant("water_wheel", Vector2i(0, 0))
	assert_near(bs.stage_seconds(m, bs.current_stage(m)), 4.8, 0.001, "with power: 8 x 0.6")
	sim.execute({"type": "building.tap", "id": mine})
	assert_eq(power.demand(), 1.5, "it draws 1.5 kW while it digs")
	assert_eq(float(power.shares[mine]), 1.0, "and got all of it")
	sim.advance_ms(4800)
	assert_eq(power.demand(), 0.0, "nothing when it stops")


func test_a_brownout_slows_what_starts_during_it() -> void:
	research.completed["electric_drill"] = 0
	research.completed["electric_furnace"] = 0
	bs.place_instant("water_wheel", Vector2i(0, 0))
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	var smelter := bs.place_instant("smelter", Vector2i(0, 1))
	inv.add("copper_ore", 2, "test")
	inv.add("wood", 1, "test")
	sim.execute({"type": "building.tap", "id": mine})
	sim.execute({"type": "building.tap", "id": smelter})
	assert_near(power.ratio(), 3.0 / 4.5, 0.001, "3 kW for 4.5 kW of draw")
	assert_near(float(power.shares[smelter]), 3.0 / 4.5, 0.001, "the furnace got two thirds")
	var s := bs.get_building(smelter)
	assert_near((int(s["task_end"]) - int(s["task_start"])) / 1000.0, 10.0 * lerpf(1.0, 0.6, 3.0 / 4.5), 0.01, "so it smelts proportionally slower than fully powered")
	assert_near((int(s["task_end"]) - int(s["task_start"])) / 1000.0, 7.33, 0.01, "7.3 s instead of 6")


func test_at_night_solar_power_goes_but_nothing_breaks() -> void:
	research.completed["electric_drill"] = 0
	bs.place_instant("solar_panel", Vector2i(0, 0))
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	sim.advance_to(int(sim.clock.day_ms * 0.8))
	assert_eq(power.supply(), 0.0, "no sun")
	assert_true(sim.execute({"type": "building.tap", "id": mine})["ok"], "the mine still digs")
	var m := bs.get_building(mine)
	assert_eq(int(m["task_end"]) - int(m["task_start"]), 8000, "at its unpowered pace")
	assert_eq(float(power.shares[mine]), 0.0, "with no share")


func test_a_building_that_needs_power_waits_for_it() -> void:
	var r: Dictionary = GameData.load_default().table("research").duplicate(true)
	for n: Dictionary in r["nodes"]:
		if n["id"] == "electric_drill":
			n["effects"][0]["required"] = true
	sim = Simulation.new_game(GameData.from_tables({"research": r}))
	bs = sim.system(&"buildings")
	(sim.system(&"research") as ResearchSystem).completed["electric_drill"] = 0
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	assert_eq(sim.execute({"type": "building.tap", "id": mine})["reason"], "err.no_power", "no power, no start")
	bs.place_instant("water_wheel", Vector2i(0, 0))
	assert_true(sim.execute({"type": "building.tap", "id": mine})["ok"], "power: it starts")


func test_power_state_survives_a_save() -> void:
	research.completed["electric_drill"] = 0
	var e := bs.place_instant("steam_engine", Vector2i(0, 0))
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	inv.add("wood", 3, "test")
	sim.execute({"type": "building.tap", "id": e})
	sim.advance_ms(3000)
	sim.execute({"type": "building.tap", "id": mine})
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var p2: PowerSystem = copy.system(&"power")
	assert_eq(p2.output_of(e, copy.now_ms()), 5.0, "the boiler is still fired")
	assert_eq(float(p2.shares[mine]), 1.0, "the share is remembered")
	var state := sim.save_state()
	(state["systems"] as Dictionary).erase("power")
	assert_eq((Simulation.from_save(JSON.parse_string(JSON.stringify(state))).system(&"power") as PowerSystem).fired_until, {}, "an old save without power loads")


func test_same_power_whatever_the_step() -> void:
	var out: Array = []
	for chunk: int in [16, 1000, 7777]:
		var s := Simulation.new_game()
		var b2: BuildingSystem = s.system(&"buildings")
		(s.system(&"research") as ResearchSystem).completed["electric_drill"] = 0
		b2.place_instant("solar_panel", Vector2i(0, 0))
		b2.place_instant("wind_turbine", Vector2i(0, 1))
		var mine := b2.place_instant("mine", Vector2i(1, 0))
		s.execute({"type": "momo.assign", "momo": 1, "building": mine})
		var t := 0
		var total := 30000 * 10
		while t < total:
			var step := mini(chunk, total - t)
			s.advance_ms(step)
			t += step
		out.append([b2.get_building(mine)["completed"], (s.system(&"inventory") as InventorySystem).count("stone"), JSON.stringify((s.system(&"power") as PowerSystem).shares)])
	assert_eq(out[1], out[0], "1 s steps")
	assert_eq(out[2], out[0], "7.8 s steps")


func test_bad_power_data_is_refused() -> void:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["solar_panel"]["power"]["generate"]["kind"] = "fusion"
	b["types"]["steam_engine"]["cycle"]["stages"][0].erase("consumes")
	b["types"]["wind_turbine"]["unlock"]["research"] = "warp"
	var text := "\n".join(GameData.from_tables({"buildings": b}).errors)
	assert_true(text.contains("known kind"), "an unknown kind of generator")
	assert_true(text.contains("burns fuel but has no stage"), "a boiler nobody can feed")
	assert_true(text.contains("is not a research node"), "a building waiting for research that does not exist")
