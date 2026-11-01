extends "res://tests/framework/test_case.gd"

## Step 78: every building's production x5 slower again -- the active work of
## every stage, the wait after it (a watered crop ripening) and construction
## (balance.pace.production, design/PACE78.md). Played in real simulated time,
## side by side with the 0.77 game (the same data with the three factors at
## 1): every start and completion comes exactly five times as late, by hand,
## by a Momo, by a drip line, at a farm (both crops), a mine, a lumberyard, a
## lab and a smelter; research, the Clock Tower and a Momo's own multiplier
## compose on top, once (never x25); floors move with their timer; rewards
## come once, at the new completion; a stage running in a save keeps the end
## it started with; walking, the day and research topics keep their times.

## The 0.77 game: the same data, Step 78's three factors at 1.
func _pace77() -> GameData:
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	for k: String in ["work", "wait", "build"]:
		bal["pace"]["production"][k] = 1.0
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


## Every start and completion at building `id`, [event, stage, ms] in order,
## from `from_ms` -- by hand: tapped whenever it is ready, for `stages`.
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


## The same, worked by Momo 1 (assigned once) until `stages` are done.
func _by_momo(sim: Simulation, id: int, stages: int) -> Array:
	var log: Array = []
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if int(p.get("id", 0)) != id:
			return
		if t == &"task_started":
			log.append(["start", String(p["stage"]), clock.now_ms, int(p.get("worker", 0))])
		elif t == &"task_completed":
			log.append(["done", String(p["stage"]), clock.now_ms, int(p.get("worker", 0))]))
	sim.execute({"type": "momo.assign", "momo": 1, "building": id})
	var waited := 0
	while log.filter(func(e: Array) -> bool: return e[0] == "done").size() < stages and waited < 4 * 3600 * 1000:
		sim.advance_ms(500)
		waited += 500
	return log


## The spans of a log: each start -> its completion, and each completion ->
## the next start (the wait, and walking or a tap's delay).
func _spans(log: Array) -> Array:
	var out: Array = []
	for i in range(1, log.size()):
		out.append([String(log[i - 1][0]) + ">" + String(log[i][0]), String(log[i][1]), int(log[i][2]) - int(log[i - 1][2])])
	return out


func test_a_watered_farm_ripens_five_times_as_long() -> void:
	var now := _island()
	var old := _island(_pace77())
	var a := (now.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 1))
	var b := (old.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 1))
	var la := _by_hand(now, a, 3)
	var lb := _by_hand(old, b, 3)
	assert_eq(la.map(func(e: Array) -> String: return e[1]), ["sow", "sow", "water", "water", "harvest", "harvest"], "sow, water, harvest by hand")
	for i in la.size():
		assert_eq(int(la[i][2]), int(lb[i][2]) * 5, "%s %s at %d ms (0.77: %d): five times as late" % [la[i][0], la[i][1], la[i][2], lb[i][2]])
	# After watering: refused until the crop is ripe -- 10 s now, 2 s before.
	var bs: BuildingSystem = now.system(&"buildings")
	assert_true(now.execute({"type": "building.tap", "id": a})["ok"], "sow again")
	now.advance_ms(bs.remaining_ms(bs.get_building(a)))
	assert_true(now.execute({"type": "building.tap", "id": a})["ok"], "water")
	now.advance_ms(bs.remaining_ms(bs.get_building(a)))
	var r := now.execute({"type": "building.tap", "id": a})
	assert_eq(r["reason"], "err.cooldown", "the harvest waits for the crop")
	assert_eq(int(r["remaining_ms"]), 10000, "ten seconds after watering (0.77: two)")
	var money := (now.system(&"economy") as EconomySystem).money
	now.advance_ms(9999)
	assert_eq(now.execute({"type": "building.tap", "id": a})["reason"], "err.cooldown", "not ripe 1 ms before")
	assert_eq((now.system(&"economy") as EconomySystem).money, money, "nothing picked or paid before it is ripe")
	now.advance_ms(1)
	assert_true(now.execute({"type": "building.tap", "id": a})["ok"], "ripe on the dot: the harvest starts")
	now.advance_ms(bs.remaining_ms(bs.get_building(a)))
	assert_eq((now.system(&"economy") as EconomySystem).money - money, (now.system(&"economy") as EconomySystem).unit_price("crop"), "paid once, at the harvest's new end")


func test_millet_mine_lumberyard_lab_and_smelter_all_five_times() -> void:
	for spec: Array in [["farm", "millet", 2], ["mine", "", 2], ["lumberyard", "", 2], ["research", "", 2], ["smelter", "", 2]]:
		var logs: Array = []
		for data: GameData in [null, _pace77()]:
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
			assert_eq(int(logs[0][i][2]), int(logs[1][i][2]) * 5, "%s %s %s: x5 (%d ms, 0.77 %d)" % [what, logs[0][i][0], logs[0][i][1], logs[0][i][2], logs[1][i][2]])


func test_a_momo_takes_five_times_as_long_never_twenty_five() -> void:
	var now := _island()
	var old := _island(_pace77())
	var a := (now.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 1))
	var b := (old.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 1))
	var la := _by_momo(now, a, 6)
	var lb := _by_momo(old, b, 6)
	var x := (now.system(&"momo") as MomoSystem).work_multiplier(1, "farm")
	var sa := _spans(la)
	var sb := _spans(lb)
	var work := 0
	for i in mini(sa.size(), sb.size()):
		if String(sa[i][0]) == "start>done":
			# Its skill grows with every stage, the same in both games.
			assert_eq(int(sa[i][2]), int(sb[i][2]) * 5, "Momo %s: x5 of 0.77 (%d ms against %d)" % [sa[i][1], sa[i][2], sb[i][2]])
			work += 1
	assert_true(work >= 5, "its stages measured (%d)" % work)
	var bs: BuildingSystem = now.system(&"buildings")
	var first: Array = la.filter(func(e: Array) -> bool: return e[0] == "start")[0]
	var ended: Array = la.filter(func(e: Array) -> bool: return e[0] == "done")[0]
	assert_eq(int(ended[2]) - int(first[2]), int(round(bs.stage_seconds({"type": "farm"}, bs.stages({"type": "farm"})[0]) * x * 1000.0)), "its first sowing: the stage's time x its own multiplier (%.2f), once" % x)
	# The ripening after its watering is the world's 10 s, not the Momo's.
	for i in sa.size():
		if String(sa[i][0]) == "done>start" and String(sa[i][1]) == "harvest":
			assert_true(int(sa[i][2]) >= 10000 and int(sa[i][2]) < 10000 + 2000, "the harvest waits the 10 s ripening (%d ms)" % sa[i][2])


func test_two_momos_at_two_farms_each_their_own_slower_clock() -> void:
	var runs: Array = []
	for data: GameData in [null, _pace77()]:
		var sim := _island(data)
		var bs: BuildingSystem = sim.system(&"buildings")
		var second := (sim.system(&"momo") as MomoSystem).add_momo(Vector2(2.5, 2.5))
		var a := bs.place_instant("farm", Vector2i(0, 0))
		var b := bs.place_instant("farm", Vector2i(3, 3))
		var spans := {a: [], b: []}
		var clock := sim.clock
		sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
			if t == &"task_started" and spans.has(int(p["id"])):
				(spans[int(p["id"])] as Array).append(int(p["ends_ms"]) - clock.now_ms))
		sim.execute({"type": "momo.assign", "momo": 1, "building": a})
		sim.execute({"type": "momo.assign", "momo": second, "building": b})
		sim.advance_ms(600000 if data == null else 120000)
		runs.append([spans[a], spans[b]])
	for f in 2:
		var now: Array = runs[0][f]
		var old: Array = runs[1][f]
		assert_true(now.size() >= 4, "farm %d worked by its own Momo, at the same time as the other (%s)" % [f, now])
		for i in mini(now.size(), old.size()):
			assert_eq(int(now[i]), int(old[i]) * 5, "farm %d stage %d: x5 of 0.77 (%d ms against %d)" % [f, i, now[i], old[i]])


func test_a_drip_line_waters_by_itself_five_times_as_long() -> void:
	var logs: Array = []
	for data: GameData in [null, _pace77()]:
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
		assert_true(sim.execute({"type": "building.tap", "id": farm})["ok"], "sown by hand")
		sim.advance_ms(bs.remaining_ms(bs.get_building(farm)) + 1)
		logs.append(log)
	assert_eq(String(logs[0][1][0]), "water", "then watered")
	assert_eq(int(logs[0][1][1]), JobSystem.AUTO_WORKER, "by the drip line itself")
	assert_eq(int(logs[0][1][2]), int(logs[1][1][2]) * 5, "x5 of 0.77 (%d ms against %d)" % [logs[0][1][2], logs[1][1][2]])


func test_research_and_the_clock_tower_compose_once_and_floors_move_with_their_timer() -> void:
	var now := _island()
	var old := _island(_pace77())
	var pairs := []
	for sim: Simulation in [now, old]:
		var research: ResearchSystem = sim.system(&"research")
		for id: String in ["farm_expansion", "watering_efficiency", "watering_can", "pickaxes"]:
			research.completed[id] = 0
			research.bought[id] = 1
		var bs: BuildingSystem = sim.system(&"buildings")
		var farm := bs.get_building(bs.place_instant("farm", Vector2i(1, 1)))
		var mine := bs.get_building(bs.place_instant("mine", Vector2i(2, 1)))
		var water: Dictionary = bs.stages(farm)[1]
		var dig: Dictionary = bs.stages(mine)[0]
		pairs.append([bs.stage_seconds(farm, water), bs.stage_cooldown(farm, water), bs.stage_seconds(mine, dig), bs.stage_cooldown(mine, dig)])
		bs.place_instant("clock_tower", Vector2i(0, 2))
		var specials: SpecialSystem = sim.system(&"specials")
		if not specials.burst()["active"]:
			sim.advance_ms(int(specials.burst()["remaining_ms"]) + 1)
		assert_true(specials.burst()["active"], "the tower's burst")
		pairs[-1].append(bs.stage_seconds(mine, dig))
	for i in (pairs[0] as Array).size():
		assert_near(float(pairs[0][i]), float(pairs[1][i]) * 5.0, 0.0001, "value %d: researched (and in a burst) x5 of 0.77, once (%.2f against %.2f)" % [i, pairs[0][i], pairs[1][i]])
	# However strong the research, the floors -- five times as long now.
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
	assert_near(sb.stage_cooldown(f, w), float(w["cooldown_floor"]) * 5.0, 0.0001, "the ripening's floor x5 (%.1f s)" % sb.stage_cooldown(f, w))
	assert_near(sb.stage_seconds(f, w), float(w.get("seconds_floor", BuildingSystem.MIN_WORK_SECONDS)) * 31.25, 0.0001, "and the work's floor with the work (%.2f s)" % sb.stage_seconds(f, w))


func test_construction_five_times_as_long() -> void:
	for type: String in ["farm", "mine", "lumberyard", "research"]:
		var ends: Array[int] = []
		for data: GameData in [null, _pace77()]:
			var sim := _island(data)
			(sim.system(&"economy") as EconomySystem).earn(100000, "test")
			(sim.system(&"progression") as ProgressionSystem).add_exp(100000, "test")
			var items: Dictionary = sim.data.building_type(type)["cost"].get("items", {})
			for item: String in items:
				(sim.system(&"inventory") as InventorySystem).add(item, int(items[item]), "test")
			var r := sim.execute({"type": "building.place", "building": type, "anchor": [1, 1]})
			assert_true(r["ok"], "%s placed (%s)" % [type, r.get("reason", "")])
			var b := (sim.system(&"buildings") as BuildingSystem).get_building(int(r["id"]))
			var built := [-1]
			var clock := sim.clock
			var id := int(r["id"])
			sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
				if t == &"building_built" and int(p["id"]) == id:
					built[0] = clock.now_ms)
			var t0 := sim.now_ms()
			sim.advance_ms(int(b["build_end"]) - t0)
			ends.append(built[0] - t0)
		assert_eq(ends[0], ends[1] * 5, "%s built in %d ms (0.77: %d): x5" % [type, ends[0], ends[1]])


func test_a_stage_running_in_an_old_save_keeps_its_end_then_the_next_is_slower() -> void:
	# A 0.77 save: the farm watered, its crop ripening (2 s), a Momo mid-way
	# through a mine's dig.
	var old := _island(_pace77())
	var ob: BuildingSystem = old.system(&"buildings")
	var farm := ob.place_instant("farm", Vector2i(1, 1))
	var mine := ob.place_instant("mine", Vector2i(2, 2))
	for i in 2:
		old.execute({"type": "building.tap", "id": farm})
		old.advance_ms(ob.remaining_ms(ob.get_building(farm)))
	assert_eq(ob.get_building(farm)["state"], BuildingSystem.COOLDOWN, "0.77: ripening")
	old.execute({"type": "momo.assign", "momo": 1, "building": mine})
	while ob.get_building(mine)["state"] != BuildingSystem.WORKING:
		old.advance_ms(100)
	var ready_at := int(ob.get_building(farm)["ready_at"])
	var dig_end := int(ob.get_building(mine)["task_end"])
	var state := SaveService.decode(SaveService.encode(old))
	assert_eq(state["status"], "ok", "the save opens")
	# Loaded into this game: the stages already running end when they would
	# have (no jump, no sudden x5 of time already promised, nothing stuck).
	var now := Simulation.from_save(state["state"])
	var nb: BuildingSystem = now.system(&"buildings")
	assert_eq(int(nb.get_building(farm)["ready_at"]), ready_at, "the ripening keeps its end")
	assert_eq(int(nb.get_building(mine)["task_end"]), dig_end, "the dig keeps its end")
	now.advance_to(ready_at)
	assert_eq(nb.get_building(farm)["state"], BuildingSystem.IDLE, "ripe on the old schedule")
	now.advance_to(dig_end)
	assert_eq(int(nb.get_building(mine)["completed"]), 1, "dug on the old schedule")
	# Everything started after the update takes the new time.
	var r := now.execute({"type": "building.tap", "id": farm})
	assert_true(r["ok"], "the harvest starts")
	assert_eq(int(r["ends_ms"]) - now.now_ms(), int(round(nb.stage_seconds(nb.get_building(farm), nb.stages(nb.get_building(farm))[2]) * 1000.0)), "and takes the new 31.25 s")
	assert_eq(int(r["ends_ms"]) - now.now_ms(), 31250, "")
	var dig2 := int(nb.get_building(mine)["ready_at"]) - int(nb.get_building(mine)["task_end"])
	assert_eq(dig2, 30000, "the mine's settling after it: the new 30 s (0.77: 6)")


func test_a_save_mid_ripening_resumes_the_same_remaining_time() -> void:
	var sim := _island()
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 1))
	for i in 2:
		sim.execute({"type": "building.tap", "id": farm})
		sim.advance_ms(bs.remaining_ms(bs.get_building(farm)))
	sim.advance_ms(4000)
	var left := bs.remaining_ms(bs.get_building(farm))
	assert_eq(left, 6000, "4 of the 10 s gone")
	var copy := Simulation.from_save(SaveService.decode(SaveService.encode(sim))["state"])
	var cb: BuildingSystem = copy.system(&"buildings")
	assert_eq(cb.remaining_ms(cb.get_building(farm)), left, "loaded: the same 6 s to go")
	copy.advance_ms(left - 1)
	assert_eq(cb.get_building(farm)["state"], BuildingSystem.COOLDOWN, "still ripening 1 ms before")
	copy.advance_ms(1)
	assert_eq(cb.get_building(farm)["state"], BuildingSystem.IDLE, "and ripe on time")


func test_progress_and_countdowns_tell_the_new_time() -> void:
	var sim := _island()
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 1))
	sim.execute({"type": "building.tap", "id": farm})
	var b := bs.get_building(farm)
	assert_eq(bs.remaining_ms(b), 31250, "the card's countdown: 31.25 s")
	sim.advance_ms(15625)
	assert_near(bs.progress(b), 0.5, 0.001, "half way at half the time: the ring is not frozen or early")
	sim.advance_ms(15625)
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(bs.remaining_ms(b))
	assert_eq(b["state"], BuildingSystem.COOLDOWN, "ripening")
	assert_eq(int(b["ready_at"]) - int(b["task_end"]), 10000, "the wait the cooldown ring spans: 10 s (BuildingView)")
	var first := bs.remaining_ms(b)
	sim.advance_ms(2500)
	assert_eq(first - bs.remaining_ms(b), 2500, "the ripening counts down as time passes")
	var est := bs.cycle_estimate(b)
	assert_near(float(est["cycle_seconds"]), 3 * 31.25 + 10.0, 0.0001, "the panel's cycle: 103.75 s by hand")


func test_walking_the_day_and_research_keep_their_times() -> void:
	var now := _island()
	var old := _island(_pace77())
	assert_eq(now.clock.day_ms, 30000, "a day is 30 s")
	assert_near((now.system(&"momo") as MomoSystem).walk_speed(), (old.system(&"momo") as MomoSystem).walk_speed(), 0.0001, "walking as before")
	for id: String in ["farm_expansion", "watering_can", "drip_irrigation", "pickaxes"]:
		assert_eq((now.system(&"research") as ResearchSystem).duration_ms(id), (old.system(&"research") as ResearchSystem).duration_ms(id), "%s: research takes its own time" % id)
	assert_eq(now.data.get_float("balance", "mail.research_gap_seconds", 0.0), old.data.get_float("balance", "mail.research_gap_seconds", 0.0), "letters as before")
	assert_eq((now.system(&"economy") as EconomySystem).unit_price("crop"), (old.system(&"economy") as EconomySystem).unit_price("crop"), "and the crop's price: no money to erase the wait")
