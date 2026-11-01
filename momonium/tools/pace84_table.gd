extends SceneTree

## Step 84 (design/PACE84.md): the before -> after table of the island's
## timers, read off the simulator itself -- each scene played in simulated
## time on the Step 78 game (the production factors at 5) and on this one,
## the moment of every start and completion written down (ms from the first
## action), and their ratio. By hand: a farm's sow, water, the ripening after
## it and the harvest; a millet farm; a mine; a lumberyard (its sapling taking
## root); a lab; a smelter. A Momo working a farm (its own stages, walking
## left out). A drip line watering by itself. A researched farm and a Clock
## Tower burst. Construction.
##
##   godot --headless --path momonium --script res://tools/pace84_table.gd

var rows: Array = []


func _init() -> void:
	var old := _data(5.0)
	var now := GameData.load_default()
	for spec: Array in [["farm", "", 3, "Farm (by hand)"], ["farm", "millet", 3, "Millet farm (by hand)"], ["mine", "", 2, "Mine (by hand)"],
			["lumberyard", "", 3, "Lumberyard (by hand)"], ["research", "", 2, "Lab (by hand)"], ["smelter", "", 2, "Smelter (by hand)"]]:
		_compare(String(spec[3]), _by_hand(old, spec), _by_hand(now, spec))
	_compare("Momo at a farm (its stages)", _momo(old), _momo(now))
	_compare("Drip line (automatic watering)", _drip(old), _drip(now))
	_compare("Researched farm (water, ripening)", _researched(old), _researched(now))
	_compare("Clock Tower burst (a chop)", _burst(old), _burst(now))
	_compare("Construction", _construction(old), _construction(now))
	print("| Scene | Event | Step 78 (ms) | Step 84 (ms) | Ratio |")
	print("|---|---|---:|---:|---:|")
	for r: Array in rows:
		print("| %s | %s | %d | %d | %s |" % [r[0], r[1], r[2], r[3], ("%.4f" % (float(r[3]) / float(r[2]))) if int(r[2]) > 0 else "-"])
	quit()


func _data(production: float) -> GameData:
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	for k: String in ["work", "wait", "build"]:
		bal["pace"]["production"][k] = production
	return GameData.from_tables({"balance": bal})


func _island(data: GameData) -> Simulation:
	var sim := Simulation.new_game(data)
	(sim.system(&"momo") as MomoSystem).add_momo(Vector2(0.55, 1.35))
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 4:
			world.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	return sim


func _compare(scene: String, a: Array, b: Array) -> void:
	for i in mini(a.size(), b.size()):
		rows.append([scene, String(a[i][0]), int(a[i][1]), int(b[i][1])])


## [event, ms] for every start, completion and ready of building `id`.
func _logger(sim: Simulation, id: int, log: Array, t0: int) -> void:
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if int(p.get("id", 0)) != id:
			return
		if t == &"task_started":
			log.append(["%s starts" % p["stage"], clock.now_ms - t0])
		elif t == &"task_completed":
			log.append(["%s done" % p["stage"], clock.now_ms - t0])
		elif t == &"building_ready":
			log.append(["ready again (after the wait)", clock.now_ms - t0]))


func _by_hand(data: GameData, spec: Array) -> Array:
	var sim := _island(data)
	var bs: BuildingSystem = sim.system(&"buildings")
	var id := bs.place_instant(String(spec[0]), Vector2i(1, 1))
	if String(spec[1]) != "":
		bs.get_building(id)["variety"] = String(spec[1])
	var inv: InventorySystem = sim.system(&"inventory")
	for st: Dictionary in bs.stages(bs.get_building(id)):
		for item: String in st.get("consumes", {}):
			inv.add(item, 50, "table")
	var log: Array = []
	_logger(sim, id, log, sim.clock.now_ms)
	for i in int(spec[2]):
		var b := bs.get_building(id)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(bs.remaining_ms(b))
		sim.execute({"type": "building.tap", "id": id})
		sim.advance_ms(bs.remaining_ms(bs.get_building(id)))
	var b2 := bs.get_building(id)
	if b2["state"] == BuildingSystem.COOLDOWN:
		sim.advance_ms(bs.remaining_ms(b2))
	return log


## A Momo's own stages at a farm: how long each takes (its walking left out).
func _momo(data: GameData) -> Array:
	var sim := _island(data)
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 1))
	var out: Array = []
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p["id"]) == farm and int(p["worker"]) == 1 and out.size() < 4:
			out.append(["Momo %s (%d of 4)" % [p["stage"], out.size() + 1], int(p["ends_ms"]) - clock.now_ms]))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var waited := 0
	while out.size() < 4 and waited < 3600000:
		sim.advance_ms(500)
		waited += 500
	return out


func _drip(data: GameData) -> Array:
	var sim := _island(data)
	var research: ResearchSystem = sim.system(&"research")
	for id: String in ["farm_expansion", "watering_efficiency", "watering_can", "drip_irrigation"]:
		research.completed[id] = 0
		research.bought[id] = 1
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 1))
	var out: Array = []
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p["id"]) == farm and int(p["worker"]) == JobSystem.AUTO_WORKER:
			out.append(["automatic %s" % p["stage"], int(p["ends_ms"]) - clock.now_ms]))
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(bs.remaining_ms(bs.get_building(farm)) + 1)
	return out


func _researched(data: GameData) -> Array:
	var sim := _island(data)
	var research: ResearchSystem = sim.system(&"research")
	for id: String in ["farm_expansion", "watering_efficiency", "watering_can"]:
		research.completed[id] = 0
		research.bought[id] = 1
	var bs: BuildingSystem = sim.system(&"buildings")
	var f := bs.get_building(bs.place_instant("farm", Vector2i(1, 1)))
	var w: Dictionary = bs.stages(f)[1]
	return [["watering (researched)", int(round(bs.stage_seconds(f, w) * 1000.0))], ["ripening (researched)", int(round(bs.stage_cooldown(f, w) * 1000.0))]]


func _burst(data: GameData) -> Array:
	var sim := _island(data)
	var bs: BuildingSystem = sim.system(&"buildings")
	var y := bs.get_building(bs.place_instant("lumberyard", Vector2i(1, 1)))
	bs.place_instant("clock_tower", Vector2i(0, 3))
	var specials: SpecialSystem = sim.system(&"specials")
	# Outside a burst first (the tower may start in one), then in the next.
	if specials.burst()["active"]:
		sim.advance_ms(int(specials.burst()["remaining_ms"]) + 1)
	var plain := bs.stage_seconds(y, bs.stages(y)[0])
	if not specials.burst()["active"]:
		sim.advance_ms(int(specials.burst()["remaining_ms"]) + 1)
	return [["chop outside a burst", int(round(plain * 1000.0))], ["chop in a burst", int(round(bs.stage_seconds(y, bs.stages(y)[0]) * 1000.0))]]


func _construction(data: GameData) -> Array:
	var out: Array = []
	for type: String in ["farm", "mine", "lumberyard", "research"]:
		var sim := _island(data)
		(sim.system(&"economy") as EconomySystem).earn(100000, "table")
		(sim.system(&"progression") as ProgressionSystem).add_exp(1000000, "table")
		var inv: InventorySystem = sim.system(&"inventory")
		for item: String in ["wood", "stone", "notes"]:
			inv.add(item, 200, "table")
		var r := (sim.system(&"buildings") as BuildingSystem).place(type, Vector2i(1, 1))
		var b := (sim.system(&"buildings") as BuildingSystem).get_building(int(r.get("id", 0)))
		out.append(["%s built" % type, int(b.get("build_end", 0)) - int(b.get("build_start", 0))])
	return out
