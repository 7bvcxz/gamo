extends "res://tests/framework/test_case.gd"

## Step 84 (design/PACE84.md): Step 78 made every building's production x5
## slower and the owner, playing a reset island, found it far too slow --
## production three times as fast as Step 78 (balance.pace.production work,
## wait and build 5 -> 5/3). Played in real simulated time, side by side with
## the Step 78 game (the same data with the three factors at 5): every start
## and completion comes at a third of the time -- by hand (sow, water, the
## ripening after it, harvest), a millet farm, a mine, a lumberyard (its
## sapling taking root), a lab, a smelter, construction, a Momo (once, never
## a ninth), a drip line by itself; research and the Clock Tower compose on
## top once and the floors move with their timer; rewards come once, at the
## new completion; a stage running in a Step 78 save keeps the end it
## started with and the next takes the new time; walking, the day, research
## topics, letters, prices and the three hands keep theirs.

## A third, give or take the rounding of each stage to whole milliseconds.
const ROUNDING_MS := 4


## The Step 78 game: the same data with its three factors at 5.
func _pace78() -> GameData:
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	for k: String in ["work", "wait", "build"]:
		bal["pace"]["production"][k] = 5.0
	return GameData.from_tables({"balance": bal})


func _island(data: GameData = null) -> Simulation:
	var sim := with_starter_momo(Simulation.new_game(data))
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 4:
			world.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	return sim


## Every start and completion at `id`, [event, stage, ms from the first tap],
## by hand: tapped whenever it is ready, for `stages`.
func _by_hand(sim: Simulation, id: int, stages: int) -> Array:
	var log: Array = []
	var clock := sim.clock
	var t0 := clock.now_ms
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if int(p.get("id", 0)) != id:
			return
		if t == &"task_started":
			log.append(["start", String(p["stage"]), clock.now_ms - t0])
		elif t == &"task_completed":
			log.append(["done", String(p["stage"]), clock.now_ms - t0]))
	var bs: BuildingSystem = sim.system(&"buildings")
	for i in stages:
		var b := bs.get_building(id)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(bs.remaining_ms(b))
		assert_true(sim.execute({"type": "building.tap", "id": id})["ok"], "stage %d starts" % i)
		sim.advance_ms(bs.remaining_ms(bs.get_building(id)))
	return log


func _third(now: int, step78: int, what: String) -> void:
	assert_true(absi(now * 3 - step78) <= ROUNDING_MS * 3, "%s: %d ms, a third of Step 78's %d" % [what, now, step78])


func test_a_watered_farm_sows_waters_ripens_and_harvests_in_a_third() -> void:
	var now := _island()
	var old := _island(_pace78())
	var a := (now.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 1))
	var b := (old.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 1))
	var la := _by_hand(now, a, 3)
	var lb := _by_hand(old, b, 3)
	assert_eq(la.map(func(e: Array) -> String: return e[1]), ["sow", "sow", "water", "water", "harvest", "harvest"], "sow, water, harvest by hand")
	for i in la.size():
		_third(int(la[i][2]), int(lb[i][2]), "%s %s" % [la[i][0], la[i][1]])
	# The ripening after watering: 10 s at Step 78, about 3.3 s now.
	var bs: BuildingSystem = now.system(&"buildings")
	now.execute({"type": "building.tap", "id": a})
	now.advance_ms(bs.remaining_ms(bs.get_building(a)))
	now.execute({"type": "building.tap", "id": a})
	now.advance_ms(bs.remaining_ms(bs.get_building(a)))
	var r := now.execute({"type": "building.tap", "id": a})
	assert_eq(r["reason"], "err.cooldown", "the harvest waits for the crop")
	_third(int(r["remaining_ms"]), 10000, "the ripening after watering")
	var money := (now.system(&"economy") as EconomySystem).money
	now.advance_ms(int(r["remaining_ms"]) - 1)
	assert_eq(now.execute({"type": "building.tap", "id": a})["reason"], "err.cooldown", "not ripe 1 ms before")
	now.advance_ms(1)
	assert_true(now.execute({"type": "building.tap", "id": a})["ok"], "ripe on the dot: the harvest starts")
	now.advance_ms(bs.remaining_ms(bs.get_building(a)))
	assert_eq((now.system(&"economy") as EconomySystem).money - money, (now.system(&"economy") as EconomySystem).unit_price("crop"), "paid once, the same price, at the new end")
	# The hand cycle: 103.75 s at Step 78, a third now.
	assert_near(float(bs.cycle_estimate(bs.get_building(a))["cycle_seconds"]), 103.75 / 3.0, 0.01, "the panel's cycle by hand: 34.6 s")


func test_millet_mine_lumberyard_lab_and_smelter_all_in_a_third() -> void:
	for spec: Array in [["farm", "millet", 3], ["mine", "", 2], ["lumberyard", "", 3], ["research", "", 2], ["smelter", "", 2]]:
		var logs: Array = []
		for data: GameData in [null, _pace78()]:
			var sim := _island(data)
			var bs: BuildingSystem = sim.system(&"buildings")
			var id := bs.place_instant(String(spec[0]), Vector2i(1, 1))
			if String(spec[1]) != "":
				bs.get_building(id)["variety"] = String(spec[1])
			if spec[0] == "smelter":
				for item: String in bs.current_stage(bs.get_building(id)).get("consumes", {}):
					(sim.system(&"inventory") as InventorySystem).add(item, 50, "test")
			logs.append(_by_hand(sim, id, int(spec[2])))
		var what := "%s%s" % [spec[0], (" " + String(spec[1])) if String(spec[1]) != "" else ""]
		assert_eq((logs[0] as Array).size(), (logs[1] as Array).size(), "%s: the same stages" % what)
		assert_true((logs[0] as Array).size() >= 4, "%s: worked (%s)" % [what, logs[0]])
		for i in (logs[0] as Array).size():
			_third(int(logs[0][i][2]), int(logs[1][i][2]), "%s %s %s" % [what, logs[0][i][0], logs[0][i][1]])


func test_a_momo_takes_a_third_never_a_ninth() -> void:
	var spans: Array = []
	for data: GameData in [null, _pace78()]:
		var sim := _island(data)
		var bs: BuildingSystem = sim.system(&"buildings")
		var farm := bs.place_instant("farm", Vector2i(1, 1))
		var works: Array = []
		var clock := sim.clock
		sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
			if t == &"task_started" and int(p["id"]) == farm and int(p["worker"]) == 1:
				works.append(int(p["ends_ms"]) - clock.now_ms))
		sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
		var waited := 0
		while works.size() < 6 and waited < 3600 * 1000:
			sim.advance_ms(500)
			waited += 500
		spans.append(works)
	assert_true((spans[0] as Array).size() >= 6, "its stages measured (%s)" % [spans[0]])
	for i in mini((spans[0] as Array).size(), (spans[1] as Array).size()):
		# Its skill grows with every stage, the same in both games.
		_third(int(spans[0][i]), int(spans[1][i]), "the Momo's stage %d" % i)


func test_a_drip_line_waters_by_itself_in_a_third() -> void:
	var logs: Array = []
	for data: GameData in [null, _pace78()]:
		var sim := _island(data)
		var research: ResearchSystem = sim.system(&"research")
		for id: String in ["farm_expansion", "watering_efficiency", "watering_can", "drip_irrigation"]:
			research.completed[id] = 0
			research.bought[id] = 1
		var bs: BuildingSystem = sim.system(&"buildings")
		var farm := bs.place_instant("farm", Vector2i(1, 1))
		var log: Array = []
		var clock := sim.clock
		sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
			if t == &"task_started" and int(p["id"]) == farm:
				log.append([String(p["stage"]), int(p["worker"]), int(p["ends_ms"]) - clock.now_ms]))
		sim.execute({"type": "building.tap", "id": farm})
		sim.advance_ms(bs.remaining_ms(bs.get_building(farm)) + 1)
		logs.append(log)
	assert_eq(int(logs[0][1][1]), JobSystem.AUTO_WORKER, "watered by the drip line itself")
	_third(int(logs[0][1][2]), int(logs[1][1][2]), "the automatic watering")


func test_research_and_the_clock_tower_compose_once_and_floors_move_with_their_timer() -> void:
	var pairs := []
	for data: GameData in [null, _pace78()]:
		var sim := _island(data)
		var research: ResearchSystem = sim.system(&"research")
		for id: String in ["farm_expansion", "watering_efficiency", "watering_can", "pickaxes"]:
			research.completed[id] = 0
			research.bought[id] = 1
		var bs: BuildingSystem = sim.system(&"buildings")
		var farm := bs.get_building(bs.place_instant("farm", Vector2i(1, 1)))
		var mine := bs.get_building(bs.place_instant("mine", Vector2i(2, 1)))
		var water: Dictionary = bs.stages(farm)[1]
		var dig: Dictionary = bs.stages(mine)[0]
		var row := [bs.stage_seconds(farm, water), bs.stage_cooldown(farm, water), bs.stage_seconds(mine, dig), bs.stage_cooldown(mine, dig)]
		# The Clock Tower's burst on top.
		bs.place_instant("clock_tower", Vector2i(0, 3))
		var specials: SpecialSystem = sim.system(&"specials")
		if not specials.burst()["active"]:
			sim.advance_ms(int(specials.burst()["remaining_ms"]) + 1)
		row.append(bs.stage_seconds(mine, dig))
		pairs.append(row)
	for i in (pairs[0] as Array).size():
		assert_near(float(pairs[0][i]) * 3.0, float(pairs[1][i]), 0.0001, "value %d: researched (and in a burst) a third of Step 78, once (%.3f against %.3f)" % [i, pairs[0][i], pairs[1][i]])
	# However strong the research, the floors -- a third of Step 78's.
	var r: Dictionary = GameData.load_default().table("research").duplicate(true)
	for n: Dictionary in r["nodes"]:
		for e: Dictionary in n.get("effects", []):
			if e.has("multiply"):
				e["multiply"] = 0.01
	var strong := Simulation.new_game(GameData.from_tables({"research": r}))
	var sr: ResearchSystem = strong.system(&"research")
	for id: String in ["farm_expansion", "watering_efficiency", "watering_can", "drip_irrigation"]:
		sr.completed[id] = 0
		sr.bought[id] = 1
	var sb: BuildingSystem = strong.system(&"buildings")
	var f := sb.get_building(sb.place_instant("farm", Vector2i(1, 0)))
	var w: Dictionary = sb.stages(f)[1]
	assert_near(sb.stage_cooldown(f, w), float(w["cooldown_floor"]) * 5.0 / 3.0, 0.0001, "the ripening's floor x5/3 (%.2f s)" % sb.stage_cooldown(f, w))
	assert_near(sb.stage_seconds(f, w), float(w.get("seconds_floor", BuildingSystem.MIN_WORK_SECONDS)) * 31.25 / 3.0, 0.0001, "and the work's floor with the work (%.2f s)" % sb.stage_seconds(f, w))


func test_construction_in_a_third() -> void:
	for type: String in ["farm", "mine", "lumberyard", "research"]:
		var ends: Array[int] = []
		for data: GameData in [null, _pace78()]:
			var sim := _island(data)
			(sim.system(&"economy") as EconomySystem).earn(100000, "test")
			(sim.system(&"progression") as ProgressionSystem).add_exp(1000000, "test")
			var inv: InventorySystem = sim.system(&"inventory")
			for item: String in ["wood", "stone", "notes"]:
				inv.add(item, 200, "test")
			var r := (sim.system(&"buildings") as BuildingSystem).place(type, Vector2i(1, 1))
			assert_true(r["ok"], "%s placed (%s)" % [type, r])
			var b := (sim.system(&"buildings") as BuildingSystem).get_building(int(r.get("id", 0)))
			ends.append(int(b["build_end"]) - int(b["build_start"]))
		_third(ends[0], ends[1], "%s built" % type)


func test_a_stage_running_in_a_step78_save_keeps_its_end_then_the_next_is_quicker() -> void:
	# A Step 78 save: the farm watered, its crop ripening (10 s), a mine mid-dig.
	var old := _island(_pace78())
	var ob: BuildingSystem = old.system(&"buildings")
	var farm := ob.place_instant("farm", Vector2i(1, 1))
	var mine := ob.place_instant("mine", Vector2i(2, 2))
	for i in 2:
		old.execute({"type": "building.tap", "id": farm})
		old.advance_ms(ob.remaining_ms(ob.get_building(farm)))
	assert_eq(ob.get_building(farm)["state"], BuildingSystem.COOLDOWN, "Step 78: ripening")
	old.execute({"type": "building.tap", "id": mine})
	var ready_at := int(ob.get_building(farm)["ready_at"])
	var dig_end := int(ob.get_building(mine)["task_end"])
	var consumed := JSON.stringify((old.system(&"inventory") as InventorySystem).items)
	var state := SaveService.decode(SaveService.encode(old))
	assert_eq(state["status"], "ok", "the save opens")
	var now := Simulation.from_save(state["state"])
	var nb: BuildingSystem = now.system(&"buildings")
	assert_eq(int(nb.get_building(farm)["ready_at"]), ready_at, "the ripening keeps the end it was promised")
	assert_eq(int(nb.get_building(mine)["task_end"]), dig_end, "the dig keeps its end")
	assert_eq(JSON.stringify((now.system(&"inventory") as InventorySystem).items), consumed, "the store as saved")
	now.advance_to(ready_at - 1)
	assert_eq(nb.get_building(farm)["state"], BuildingSystem.COOLDOWN, "not early")
	now.advance_to(ready_at)
	assert_eq(nb.get_building(farm)["state"], BuildingSystem.IDLE, "ripe on the old schedule")
	now.advance_to(dig_end)
	assert_eq(int(nb.get_building(mine)["completed"]), 1, "dug on the old schedule, once")
	var r := now.execute({"type": "building.tap", "id": farm})
	assert_true(r["ok"], "the harvest starts")
	_third(int(r["ends_ms"]) - now.now_ms(), 31250, "and takes the new time")
	_third(int(nb.get_building(mine)["ready_at"]) - int(nb.get_building(mine)["task_end"]), 30000, "the mine's settling after it")


func test_walking_the_day_research_letters_prices_and_hands_keep_theirs() -> void:
	var now := _island()
	var old := _island(_pace78())
	assert_eq(now.clock.day_ms, 30000, "a day is 30 s")
	assert_near((now.system(&"momo") as MomoSystem).walk_speed(), (old.system(&"momo") as MomoSystem).walk_speed(), 0.0001, "walking as before")
	for id: String in ["farm_expansion", "watering_can", "drip_irrigation", "pickaxes"]:
		assert_eq((now.system(&"research") as ResearchSystem).duration_ms(id), (old.system(&"research") as ResearchSystem).duration_ms(id), "%s: research takes its own time" % id)
	assert_eq(now.data.get_float("balance", "mail.research_gap_seconds", 0.0), old.data.get_float("balance", "mail.research_gap_seconds", 0.0), "letters as before")
	assert_eq((now.system(&"economy") as EconomySystem).unit_price("crop"), (old.system(&"economy") as EconomySystem).unit_price("crop"), "the crop's price as before")
	assert_eq((now.system(&"buildings") as BuildingSystem).manual_limit(), 3, "three hands (Step 83)")
