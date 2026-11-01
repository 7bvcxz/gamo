extends SceneTree

## Step 85 (design/ROUTES85.md): how a scheduled Momo spends its time, on
## real schedules, by each strategy -- A the strict order (the `strict`
## route, Step 61), B ordered priority with smart skipping (`order`,
## strategy `priority`), C the soonest useful stop with ageing (`order`,
## strategy `soonest`). Each scenario is the same island, the same stops in
## the same tap order and the same Momo, played in simulated time at this
## game's pace; what is measured: stages completed (per active 10 min),
## walking, idling, ready work left undone while a Momo stood idle, the
## worst wait of a ready stop, the stages each stop got (fairness), mid-walk
## changes of destination (must be 0) and the cost of a decision.
##
##   godot --headless --path momonium --script res://tools/route_bench.gd [-- --minutes 20 --json out.json]

const STRATEGIES := [["A strict", "strict", "soonest"], ["B priority", "order", "priority"], ["C soonest", "order", "soonest"]]
const STEP_MS := 250

## name -> island size, the buildings [type, x, y], and each Momo's start and
## its stops (indices into the buildings, in tap order).
const SCENARIOS := {
	"four farms, tapped crosswise": {"size": 6, "buildings": [["farm", 0, 0], ["farm", 5, 5], ["farm", 5, 0], ["farm", 0, 5]],
		"momos": [[[2.5, 2.5], [0, 1, 2, 3]]]},
	"mixed: farm, lab, mine, farm, lumberyard": {"size": 6, "buildings": [["farm", 0, 0], ["research", 5, 5], ["mine", 5, 0], ["farm", 2, 2], ["lumberyard", 0, 5]],
		"momos": [[[2.5, 2.5], [0, 1, 2, 3, 4]]]},
	"three farms beside, a lab far away": {"size": 8, "buildings": [["farm", 0, 0], ["farm", 1, 0], ["farm", 0, 1], ["research", 7, 7]],
		"momos": [[[1.5, 1.5], [0, 1, 2, 3]]]},
	"two Momo sharing six stops": {"size": 7, "buildings": [["farm", 0, 0], ["farm", 6, 0], ["mine", 3, 0], ["farm", 0, 6], ["lumberyard", 6, 6], ["farm", 3, 6]],
		"momos": [[[1.5, 3.5], [0, 1, 2, 3, 4, 5]], [[5.5, 3.5], [5, 4, 3, 2, 1, 0]]]},
	"large: four Momo, sixteen stops": {"size": 12, "buildings": [
		["farm", 0, 0], ["farm", 3, 0], ["mine", 6, 0], ["farm", 9, 0], ["farm", 0, 3], ["lumberyard", 3, 3], ["farm", 6, 3], ["research", 9, 3],
		["farm", 0, 6], ["farm", 3, 6], ["lumberyard", 6, 6], ["farm", 9, 6], ["mine", 0, 9], ["farm", 3, 9], ["farm", 6, 9], ["farm", 9, 9]],
		"momos": [[[1.5, 1.5], [0, 5, 1, 4, 8, 2]], [[8.5, 1.5], [3, 7, 2, 6, 11, 1]], [[1.5, 8.5], [12, 9, 13, 8, 4, 14]], [[8.5, 8.5], [15, 10, 14, 11, 7, 6]]]},
}

var minutes := 20.0
## -1: the data's starve_seconds; else this (tuning).
var starve := -1.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var json_out := ""
	for i in args.size():
		if args[i] == "--minutes" and i + 1 < args.size():
			minutes = float(args[i + 1])
		elif args[i] == "--json" and i + 1 < args.size():
			json_out = args[i + 1]
		elif args[i] == "--starve" and i + 1 < args.size():
			starve = float(args[i + 1])
	var all := {}
	for name: String in SCENARIOS:
		all[name] = {}
		for st: Array in STRATEGIES:
			all[name][st[0]] = _run(SCENARIOS[name], String(st[1]), String(st[2]))
	print("| Scenario | Strategy | Stages / 10 min | Walking | Idle | Ready work left while idle | Worst wait of a ready stop | Stages per stop (min-max) | Mid-walk retargets | Distance (tiles) | us / decision |")
	print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for name: String in all:
		for st: String in all[name]:
			var r: Dictionary = all[name][st]
			print("| %s | %s | %.1f | %d%% | %d%% | %.0f s | %.0f s | %d-%d | %d | %.0f | %.0f |" % [name, st, r["stages_per_10"], r["walk_pct"], r["idle_pct"], r["missed_s"], r["worst_wait_s"], r["min_stop"], r["max_stop"], r["retargets"], r["distance"], r["us_per_decision"]])
	if json_out != "":
		var f := FileAccess.open(json_out, FileAccess.WRITE)
		f.store_string(JSON.stringify(all, "  "))
		f.close()
	quit()


func _data(strategy: String) -> GameData:
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	bal["momo"]["schedule"]["strategy"] = strategy
	if starve >= 0.0:
		bal["momo"]["schedule"]["starve_seconds"] = starve
	return GameData.from_tables({"balance": bal})


func _run(sc: Dictionary, route: String, strategy: String) -> Dictionary:
	var sim := Simulation.new_game(_data(strategy))
	var world: WorldSystem = sim.system(&"world")
	for x in int(sc["size"]):
		for y in int(sc["size"]):
			world.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var ids: Array[int] = []
	var cells: Array[Vector2i] = []
	for b: Array in sc["buildings"]:
		ids.append(bs.place_instant(String(b[0]), Vector2i(int(b[1]), int(b[2]))))
		cells.append(Vector2i(int(b[1]), int(b[2])))
	# Plenty for anything that takes inputs; the store's limits are the game's.
	var inv: InventorySystem = sim.system(&"inventory")
	for item: String in ["wood", "stone"]:
		inv.add(item, 30, "bench")
	var momos: MomoSystem = sim.system(&"momo")
	var jobs: JobSystem = sim.system(&"jobs")
	var mine: Array[int] = []
	for spec: Array in sc["momos"]:
		var id := momos.add_momo(Vector2(float(spec[0][0]), float(spec[0][1])))
		mine.append(id)
		var tiles: Array = []
		for i: int in spec[1]:
			tiles.append([cells[i].x, cells[i].y])
		sim.execute({"type": "momo.watch", "momo": id, "cells": tiles, "op": "add", "schedule": true})
		if route == "strict":
			sim.execute({"type": "momo.route", "momo": id, "route": "strict"})
	# The stops: what the Momo were given (a building with no place for a
	# Momo -- a lab without one -- is nobody's stop and not measured).
	var stops: Array[int] = []
	for id: int in mine:
		for s2: int in jobs.stops_of(id):
			if not stops.has(s2):
				stops.append(s2)
	# Counters in a dictionary: a lambda keeps a copy of a plain local.
	var count := {"stages": 0}
	var per_stop := {}
	for id: int in stops:
		per_stop[id] = 0
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_completed" and mine.has(int(p.get("worker", 0))):
			count["stages"] = int(count["stages"]) + 1
			per_stop[int(p["id"])] = int(per_stop.get(int(p["id"]), 0)) + 1)
	var walk := 0
	var idle := 0
	var active := 0
	var missed := 0
	var distance := 0.0
	var retargets := 0
	var prev_pos := {}
	var prev_dest := {}
	var prev_moving := {}
	var ready_since := {}
	var worst := 0
	jobs.dispatch_calls = 0
	jobs.dispatch_usec = 0
	var end := sim.now_ms() + int(minutes * 60000.0)
	while sim.now_ms() < end:
		sim.advance_ms(STEP_MS)
		if jobs.resting():
			continue
		active += STEP_MS
		var idle_ones: Array[int] = []
		for id: int in mine:
			var moving := momos.is_moving(id)
			var working := jobs.is_working(id)
			var dest := int(momos.get_momo(id)["assigned"])
			var pos := momos.position_of(id)
			if moving:
				walk += STEP_MS
			elif not working:
				idle += STEP_MS
				idle_ones.append(id)
			if prev_pos.has(id):
				distance += pos.distance_to(prev_pos[id])
				if bool(prev_moving[id]) and moving and dest != int(prev_dest[id]):
					retargets += 1
			prev_pos[id] = pos
			prev_dest[id] = dest
			prev_moving[id] = moving
		# Ready work: a stop that could start now and nobody is on it -- missed
		# while a Momo with that stop on its own list stood idle.
		var own := {}
		for m2: int in idle_ones:
			for s3: int in jobs.stops_of(m2):
				own[s3] = true
		for id: int in stops:
			var b := bs.get_building(id)
			var ready: bool = b["state"] == BuildingSystem.IDLE and bs.can_start(id)["ok"]
			if ready:
				if not ready_since.has(id):
					ready_since[id] = sim.now_ms()
				worst = maxi(worst, sim.now_ms() - int(ready_since[id]))
				if own.has(id):
					missed += STEP_MS
			else:
				ready_since.erase(id)
	var stages := int(count["stages"])
	var counts: Array = per_stop.values()
	counts.sort()
	var total_momo := float(active * mine.size())
	return {"stages": stages, "stages_per_10": stages * 600000.0 / maxf(float(active), 1.0),
		"walk_pct": int(round(walk * 100.0 / maxf(total_momo, 1.0))), "idle_pct": int(round(idle * 100.0 / maxf(total_momo, 1.0))),
		"missed_s": missed / 1000.0, "worst_wait_s": worst / 1000.0, "min_stop": int(counts[0]), "max_stop": int(counts[-1]),
		"retargets": retargets, "distance": distance, "decisions": jobs.dispatch_calls,
		"us_per_decision": float(jobs.dispatch_usec) / maxf(float(jobs.dispatch_calls), 1.0)}
