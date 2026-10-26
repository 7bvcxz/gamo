extends "res://tests/framework/test_case.gd"

## Farming technology: better tools shorten the work, irrigation waters by
## itself, a greenhouse shortens the waits, bred varieties give more or grow
## differently -- and the usual crop is always sown, watered and harvested,
## whatever has been researched. Times are read from the data.

var sim: Simulation
var research: ResearchSystem
var buildings: BuildingSystem
var inv: InventorySystem
var farm := 0



## The wait after a watering and its floor, as the farm data gives them (s).
func _wait() -> float:
	return float(sim.data.building_type("farm")["cycle"]["stages"][1]["cooldown"])


func _floor() -> float:
	return float(sim.data.building_type("farm")["cycle"]["stages"][1]["cooldown_floor"])


func _work(i: int) -> float:
	return float(sim.data.building_type("farm")["cycle"]["stages"][i]["seconds"]) * work_scale(sim)

func before_each() -> void:
	sim = Simulation.new_game()
	research = sim.system(&"research")
	buildings = sim.system(&"buildings")
	inv = sim.system(&"inventory")
	farm = buildings.place_instant("farm", Vector2i(1, 0))


func _done(ids: Array) -> void:
	for id: String in ids:
		research.completed[id] = 0
	sim.bus.emit(&"research_completed", {"id": ids.back()})


func _all_research() -> void:
	_done(research.nodes().map(func(n: Dictionary) -> String: return String(n["id"])))


func test_the_usual_crop_always_gets_its_watering() -> void:
	_all_research()
	var b := buildings.get_building(farm)
	var stages := buildings.stages(b)
	assert_eq(stages.map(func(st: Dictionary) -> String: return st["action"]), ["sow", "water", "harvest"], "sow, water, harvest -- with everything researched")
	for st: Dictionary in stages:
		assert_true(bool(st.get("required", false)), "%s is still required" % st["id"])
	# In play: count waterings between each sowing and its harvest.
	var since_sow := [0]
	var per_harvest: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t != &"task_completed":
			return
		var stage := String(p["stage"])
		if stage == "sow":
			since_sow[0] = 0
		elif stage == "harvest":
			per_harvest.append(since_sow[0])
		else:
			since_sow[0] += 1)
	for i in 40:
		sim.execute({"type": "building.tap", "id": farm})
		sim.advance_ms(1500)
	assert_true(per_harvest.size() >= 2, "several harvests (%d)" % per_harvest.size())
	for n: int in per_harvest:
		assert_eq(n, 1, "every harvest came after its watering")


func test_a_watering_can_shortens_the_work_not_the_wait() -> void:
	_done(["farm_expansion", "watering_efficiency", "watering_can"])
	var b := buildings.get_building(farm)
	var water: Dictionary = buildings.stages(b)[1]
	assert_near(buildings.stage_seconds(b, water), maxf(_work(1) * 0.6, BuildingSystem.MIN_WORK_SECONDS), 0.0001, "watering x 0.6")
	assert_eq(buildings.stage_seconds(b, buildings.stages(b)[0]), _work(0), "sowing unchanged")
	assert_eq(buildings.stage_cooldown(b, water), _wait() * 0.75, "the wait is mulch's, not the can's")


func test_drip_irrigation_waters_by_itself_but_not_sows_or_harvests() -> void:
	_done(["farm_expansion", "watering_efficiency", "watering_can", "drip_irrigation"])
	var b := buildings.get_building(farm)
	var workers: Array = []
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started":
			workers.append([p["stage"], p["worker"]]))
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(200000)
	assert_eq(workers, [["sow", 0], ["water", -1]], "you sow; the drip line waters")
	assert_eq(int(b["stage"]), 2, "and the harvest waits for hands")
	assert_eq(b["state"], BuildingSystem.IDLE, "nobody harvests by magic")
	var water: Dictionary = buildings.stages(b)[1]
	assert_near(buildings.stage_seconds(b, water), maxf(_work(1) * 0.6, BuildingSystem.MIN_WORK_SECONDS), 0.0001, "a drip watering takes the time of a watering")
	assert_near(buildings.stage_cooldown(b, water), maxf(_wait() * 0.75 * 0.8, _floor()), 0.0001, "and the waits remain (wait x 0.75 x 0.8)")


func test_irrigation_runs_at_night_and_is_not_momo_experience() -> void:
	_done(["farm_expansion", "watering_efficiency", "watering_can", "drip_irrigation"])
	sim.advance_to(int(0.8 * sim.clock.day_ms))
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(int(_work(0) * 1000.0) + 100)
	assert_eq(buildings.get_building(farm)["worker"], -1, "watering under the moon")
	sim.advance_ms(100000)
	assert_eq(int((sim.system(&"mail") as MailSystem).work.get("farm", 0)), 0, "the drip line writes no letters")


func test_a_greenhouse_shortens_the_waits_down_to_the_floor() -> void:
	_done(["farm_expansion", "watering_efficiency", "harvest_boost", "greenhouse"])
	var b := buildings.get_building(farm)
	assert_near(buildings.stage_cooldown(b, buildings.stages(b)[1]), maxf(_wait() * 0.75 * 0.8, _floor()), 0.001, "wait x 0.75 x 0.8")
	_all_research()
	assert_near(buildings.stage_cooldown(b, buildings.stages(b)[1]), maxf(_wait() * 0.75 * 0.8 * 0.8, _floor()), 0.0001, "with drip too: wait x 0.75 x 0.8 x 0.8")
	var r: Dictionary = GameData.load_default().table("research").duplicate(true)
	for n: Dictionary in r["nodes"]:
		for e: Dictionary in n["effects"]:
			if e.has("multiply"):
				e["multiply"] = 0.1
	var s2 := Simulation.new_game(GameData.from_tables({"research": r}))
	var b2: BuildingSystem = s2.system(&"buildings")
	var f2 := b2.place_instant("farm", Vector2i(1, 0))
	for n: Dictionary in r["nodes"]:
		(s2.system(&"research") as ResearchSystem).completed[n["id"]] = 0
	var rec := b2.get_building(f2)
	assert_eq(b2.stage_cooldown(rec, b2.stages(rec)[1]), _floor(), "however strong the research, the plants get their floor")
	assert_eq(b2.stage_seconds(rec, b2.stages(rec)[1]), 0.5 * work_scale(s2), "and a watering at least its floor (half a second of data, times the work scale)")


func test_varieties_open_through_research_and_change_between_cycles() -> void:
	assert_eq(buildings.varieties("farm"), ["base", "hardy", "millet"] as Array[String], "three varieties")
	assert_eq(sim.execute({"type": "building.variety", "id": farm, "variety": "hardy"})["reason"], "err.variety_locked", "not before seed selection")
	assert_eq(sim.execute({"type": "building.variety", "id": farm, "variety": "rice"})["reason"], "err.no_variety", "unknown")
	_done(["farm_expansion", "harvest_boost", "seed_selection"])
	sim.execute({"type": "building.tap", "id": farm})
	assert_eq(sim.execute({"type": "building.variety", "id": farm, "variety": "hardy"})["reason"], "err.variety_busy", "not with seed in the ground")
	sim.advance_ms(int(_work(0) * 1000.0))
	assert_eq(sim.execute({"type": "building.variety", "id": farm, "variety": "hardy"})["reason"], "err.variety_busy", "nor once it is sown")
	var b := buildings.get_building(farm)
	b["stage"] = 0
	b["state"] = BuildingSystem.IDLE
	assert_true(sim.execute({"type": "building.variety", "id": farm, "variety": "hardy"})["ok"], "between cycles it changes")
	assert_eq(buildings.stages(b).filter(func(st: Dictionary) -> bool: return st["action"] == "water").size(), 1, "the hardy crop is watered too")
	assert_eq(buildings.cycle_estimate(b)["yield"], {"crop": 4.0}, "and gives 2, plus field expansion and soil care: 4")


func test_millet_is_a_different_crop_with_its_own_process() -> void:
	_done(["farm_expansion", "harvest_boost", "seed_selection", "drought_millet"])
	assert_true(sim.execute({"type": "building.variety", "id": farm, "variety": "millet"})["ok"], "chosen")
	var b := buildings.get_building(farm)
	assert_eq(buildings.stages(b).map(func(st: Dictionary) -> String: return st["action"]), ["sow", "harvest"], "a grain for dry ground: no watering at all")
	var millet: Array = sim.data.building_type("farm")["varieties"]["millet"]["stages"]
	var by_hand := buildings.cycle_estimate(b)
	var usual := buildings.cycle_estimate({"type": "farm", "variety": "base", "stage": 0})
	assert_true(float(by_hand["work_seconds"]) < float(usual["work_seconds"]), "less work")
	assert_true(float(by_hand["wait_seconds"]) > float(usual["wait_seconds"]), "a longer wait (%.1f s)" % float(by_hand["wait_seconds"]))
	assert_eq(buildings.look(b), "", "nothing planted yet")
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(int(float(millet[0]["seconds"]) * work_scale(sim) * 1000.0))
	assert_eq(buildings.look(b), "crop_sprout", "its own looks: growing")
	sim.advance_ms(int(float(millet[0]["cooldown"]) * 1000.0))
	assert_eq(buildings.look(b), "crop_ripe", "then ripe")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var b2 := (copy.system(&"buildings") as BuildingSystem).get_building(farm)
	assert_eq((copy.system(&"buildings") as BuildingSystem).variety_of(b2), "millet", "the variety is saved")


func test_old_farms_grow_the_usual_crop() -> void:
	var state := sim.save_state()
	for rec: Dictionary in state["systems"]["buildings"]["buildings"]:
		rec.erase("variety")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	var bs: BuildingSystem = copy.system(&"buildings")
	assert_eq(bs.variety_of(bs.get_building(farm)), "base", "no variety recorded: the usual crop")


func test_varieties_must_be_reachable_and_real() -> void:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["farm"]["varieties"]["rice"] = {"name": "variety.rice", "stages": [{"id": "sow", "action": "sow", "seconds": 5}], "looks": [""]}
	var data := GameData.from_tables({"buildings": b})
	var text := "\n".join(data.errors)
	assert_true(text.contains("rice is opened by no research"), "a variety nothing opens")
	assert_true(text.contains("rice harvests nothing"), "a crop that gives nothing")


func test_effects_are_described_from_the_data() -> void:
	TranslationServer.set_locale("en")
	assert_eq(ResearchText.effect_lines(sim, research.node("drip_irrigation")), ["Water by itself", "Wait after Water -20%"] as Array[String], "irrigation")
	assert_eq(ResearchText.effect_lines(sim, research.node("watering_can")), ["Water work time -40%"] as Array[String], "tools")
	assert_eq(ResearchText.effect_lines(sim, research.node("drought_millet")), ["New variety: Millet"] as Array[String], "a variety")


func test_unattended_runs_are_the_same_whatever_the_step() -> void:
	var out: Array = []
	for chunk: int in [16, 1000, 7777]:
		var s := Simulation.new_game()
		var bs: BuildingSystem = s.system(&"buildings")
		var f := bs.place_instant("farm", Vector2i(1, 0))
		for id: String in ["farm_expansion", "watering_efficiency", "watering_can", "drip_irrigation"]:
			(s.system(&"research") as ResearchSystem).completed[id] = 0
		s.execute({"type": "momo.assign", "momo": 1, "building": f})
		var t := 0
		while t < 30000 * 15:
			var step := mini(chunk, 30000 * 15 - t)
			s.advance_ms(step)
			t += step
		out.append([bs.get_building(f)["completed"], (s.system(&"inventory") as InventorySystem).count("crop"), (s.system(&"economy") as EconomySystem).money])
	assert_eq(out[1], out[0], "1 s steps")
	assert_eq(out[2], out[0], "7.8 s steps")


func test_fractional_yields_are_written_as_fractions() -> void:
	TranslationServer.set_locale("en")
	assert_eq(ResearchText.effect_lines(sim, research.node("copper_prospecting")), ["Dig: Copper ore +0.25"] as Array[String], "a quarter, not +0")
