class_name MomoSystem
extends SimSystem

## The Momo who live on the island, as simulation state.
##
## Each Momo is a record that saves with the game: name, where it is going,
## and which building (if any) it works at. Movement is a straight segment
## with a start and end time, so a Momo's position is a pure function of the
## clock -- the view interpolates it, a save restores it mid-stride, and
## offline catch-up needs no frame loop.
##
## Unassigned Momo wander: rest a few seconds, then stroll to a random point
## of their own cell or an edge-neighbouring owned cell (a straight line
## between neighbours never leaves the land), rest again. Decisions use this
## system's own seeded RNG, saved with it, so a wander is reproducible.
##
## Assigned Momo walk to their building and stay; Step 19 gives them the work.

const ROAM := "momo.roam"
const ARRIVE := "momo.arrive"
const NEIGHBOURS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## id -> {id, name, from [x,y], to [x,y], start, end (ms), assigned (building id), token, hired}
var momos: Dictionary = {}
var next_id := 1
var hired := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	key = &"momo"


func handled_events() -> PackedStringArray:
	return PackedStringArray([ROAM, ARRIVE])


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["momo.hire", "momo.assign", "momo.unassign", "momo.move", "momo.pin"])


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


## A building that disappears (a cancelled construction) lets its workers go;
## a stage a Momo finishes is experience at that kind of building.
func _on_event(type: StringName, payload: Dictionary) -> void:
	if type == &"building_removed":
		for id: int in workers_at(int(payload.get("id", 0))):
			unassign(id)
	elif type == &"task_completed":
		var worker := int(payload.get("worker", 0))
		if momos.has(worker):
			var exp: Dictionary = momos[worker]["experience"]
			var t := String(payload.get("type", ""))
			var before := proficiency(worker, t)
			exp[t] = int(exp.get(t, 0)) + 1
			if proficiency(worker, t) > before:
				sim.bus.emit(&"momo_skilled", {"id": worker, "type": t, "level": proficiency(worker, t)})


## Skill level (0..) of a Momo at a kind of building, from the stages it has done there.
func proficiency(id: int, type: String) -> int:
	var done := int((momos.get(id, {}).get("experience", {}) as Dictionary).get(type, 0))
	var level := 0
	for need: Variant in sim.data.get_value("balance", "momo.proficiency.thresholds", []):
		if done >= int(need):
			level += 1
	return level


## How many times the player's time this Momo takes for a stage at this kind
## of building: the Momo base, its own skill there, and Momo research.
func work_multiplier(id: int, type: String) -> float:
	var m := sim.data.get_float("balance", "momo.work_time_multiplier", 4.0)
	var mults: Array = sim.data.get_value("balance", "momo.proficiency.multipliers", [1.0])
	m *= float(mults[mini(proficiency(id, type), mults.size() - 1)])
	var research: ResearchSystem = sim.system(&"research")
	if research != null:
		m *= research.momo_multiplier(type)
	var community: CommunitySystem = sim.system(&"community")
	if community != null:
		m *= community.work_factor(id)
	return m


func on_new_game() -> void:
	momos.clear()
	next_id = 1
	hired = 0
	rng.seed = sim.data.get_int("balance", "momo.seed", 1)
	var spots: Array[Vector2] = [Vector2(0.55, 1.35), Vector2(1.4, 0.6), Vector2(0.5, 0.5), Vector2(1.5, 1.5)]
	for i in sim.data.get_int("balance", "start.momos", 1):
		add_momo(spots[i % spots.size()])


func add_momo(pos: Vector2) -> int:
	var id := next_id
	next_id += 1
	var names := maxi(sim.data.get_int("balance", "momo.names", 10), 1)
	var now := sim.now_ms()
	momos[id] = {"id": id, "name": "momo.name.%d" % ((id - 1) % names), "from": [pos.x, pos.y], "to": [pos.x, pos.y],
		"start": now, "end": now, "assigned": 0, "token": 0, "experience": {}, "history": [], "pinned": false}
	sim.bus.emit(&"momo_added", {"id": id})
	_schedule_roam(momos[id], _rest_ms())
	return id


# --- queries ------------------------------------------------------------------------

func ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in momos:
		out.append(id)
	out.sort()
	return out


func get_momo(id: int) -> Dictionary:
	return momos.get(id, {})


## Where a Momo is now (logical tile coordinates).
func position_of(id: int) -> Vector2:
	return position_at(id, sim.now_ms())


func position_at(id: int, t: int) -> Vector2:
	var m: Dictionary = momos[id]
	var from := _v(m["from"])
	var to := _v(m["to"])
	var span := int(m["end"]) - int(m["start"])
	if span <= 0 or t >= int(m["end"]):
		return to
	if t <= int(m["start"]):
		return from
	return from.lerp(to, float(t - int(m["start"])) / span)


func is_moving(id: int) -> bool:
	var m: Dictionary = momos[id]
	var now := sim.now_ms()
	return now >= int(m["start"]) and now < int(m["end"])


## Screen-agnostic direction of travel (logical), zero when standing.
func heading(id: int) -> Vector2:
	var m: Dictionary = momos[id]
	return (_v(m["to"]) - _v(m["from"])).normalized() if is_moving(id) else Vector2.ZERO


func workers_at(building: int) -> Array[int]:
	var out: Array[int] = []
	for id: int in ids():
		if int(momos[id]["assigned"]) == building:
			out.append(id)
	return out


func slots_of(building: int) -> int:
	var b := (sim.system(&"buildings") as BuildingSystem).get_building(building)
	return int((sim.system(&"buildings") as BuildingSystem).type_def(b).get("workers", 0)) if not b.is_empty() else 0


func hire_cost() -> int:
	var base := sim.data.get_float("balance", "momo.hire.base", 30.0)
	var growth := sim.data.get_float("balance", "momo.hire.growth", 1.6)
	var step := maxi(sim.data.get_int("balance", "momo.hire.round_to", 5), 1)
	return int(ceil(base * pow(growth, hired) / step)) * step


## Whether `momo` could be assigned to `building` now, and why not.
func can_assign(momo: int, building: int) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	var buildings: BuildingSystem = sim.system(&"buildings")
	if buildings.get_building(building).is_empty():
		return SimResult.fail("err.no_building")
	if int(momos[momo]["assigned"]) == building:
		return SimResult.ok()
	var slots := slots_of(building)
	if slots <= 0:
		return SimResult.fail("err.no_job")
	if workers_at(building).size() >= slots:
		return SimResult.fail("err.slots_full", {"slots": slots})
	return SimResult.ok()


# --- commands -----------------------------------------------------------------------

func execute(command: Dictionary) -> Dictionary:
	match String(command.get("type", "")):
		"momo.hire":
			return hire()
		"momo.assign":
			return assign(Cmd.integer(command, "momo"), Cmd.integer(command, "building"))
		"momo.unassign":
			return unassign(Cmd.integer(command, "momo"))
		"momo.pin":
			return set_pinned(Cmd.integer(command, "momo"), bool(command.get("pinned", true)))
		"momo.move":
			var p: Variant = command.get("pos")
			return move_to(Cmd.integer(command, "momo"), Vector2(float(p[0]), float(p[1])) if typeof(p) == TYPE_ARRAY else Vector2(-999, -999))
	return SimResult.fail("err.unknown_command")


func hire() -> Dictionary:
	var cost := hire_cost()
	var economy: EconomySystem = sim.system(&"economy")
	if not economy.can_afford(cost):
		return SimResult.fail("err.not_enough_money", {"cost": cost})
	economy.spend(cost, "hire")
	hired += 1
	var world: WorldSystem = sim.system(&"world")
	var cells := world.owned_cells()
	var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var id := add_momo(Vector2(cell) + Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75)))
	sim.bus.emit(&"momo_hired", {"id": id, "cost": cost})
	return SimResult.ok({"id": id, "cost": cost, "next_cost": hire_cost()})


## `by_player`: placed by the player (dragged, or the Assign button) -- such
## a Momo is pinned and a manager never moves it. A manager assigns unpinned.
func assign(momo: int, building: int, by_player: bool = true) -> Dictionary:
	var check := can_assign(momo, building)
	if not check["ok"]:
		return check
	var m: Dictionary = momos[momo]
	if int(m["assigned"]) != 0 and int(m["assigned"]) != building:
		_close_history(m)
	m["assigned"] = building
	m["pinned"] = by_player
	var b := (sim.system(&"buildings") as BuildingSystem).get_building(building)
	var hist: Array = m["history"]
	hist.append({"building": building, "type": String(b.get("type", "")), "from": sim.now_ms(), "to": -1, "by": "player" if by_player else "manager"})
	while hist.size() > sim.data.get_int("balance", "momo.history_kept", 12):
		hist.pop_front()
	var arrive := _walk_to(m, work_spot(building))
	m["token"] = int(m["token"]) + 1
	sim.scheduler.schedule(arrive, ARRIVE, {"id": momo, "token": m["token"]})
	sim.bus.emit(&"momo_assigned", {"id": momo, "building": building})
	return SimResult.ok()


## Whether an assigned Momo has reached its building and can work.
func at_work(id: int) -> bool:
	var m: Dictionary = momos.get(id, {})
	return not m.is_empty() and int(m["assigned"]) != 0 and not is_moving(id) \
		and position_of(id).distance_to(work_spot(int(m["assigned"]))) < 0.01


func unassign(momo: int) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	var m: Dictionary = momos[momo]
	var was := int(m["assigned"])
	if was == 0:
		return SimResult.fail("err.not_assigned")
	_close_history(m)
	m["assigned"] = 0
	m["pinned"] = false
	_stop(m)
	_schedule_roam(m, _rest_ms())
	sim.bus.emit(&"momo_unassigned", {"id": momo, "building": was})
	return SimResult.ok()


func _close_history(m: Dictionary) -> void:
	var hist: Array = m["history"]
	if not hist.is_empty() and int(hist.back()["to"]) < 0:
		hist.back()["to"] = sim.now_ms()


## Lets the manager move this Momo (false), or keeps it where the player put it (true).
func set_pinned(momo: int, pinned: bool) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	momos[momo]["pinned"] = pinned
	sim.bus.emit(&"momo_pinned", {"id": momo, "pinned": pinned})
	return SimResult.ok()


## Picks a Momo up and puts it down somewhere on its island (a drag that ends
## on land). An assigned Momo dropped away from its building is unassigned.
func move_to(momo: int, pos: Vector2) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	var world: WorldSystem = sim.system(&"world")
	if not world.is_owned(Vector2i(floori(pos.x), floori(pos.y))):
		return SimResult.fail("err.not_owned")
	var m: Dictionary = momos[momo]
	if int(m["assigned"]) != 0:
		unassign(momo)
	var now := sim.now_ms()
	m["from"] = [pos.x, pos.y]
	m["to"] = [pos.x, pos.y]
	m["start"] = now
	m["end"] = now
	_schedule_roam(m, _rest_ms())
	sim.bus.emit(&"momo_moved", {"id": momo})
	return SimResult.ok()


## Where an assigned Momo stands to work: just in front of the building's
## footprint (its south corner side), so it is seen beside it, not under it.
func work_spot(building: int) -> Vector2:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var cells := buildings.cells_of(buildings.get_building(building))
	var c := Vector2.ZERO
	for cell: Vector2i in cells:
		c += Vector2(cell) + Vector2(0.5, 0.5)
	c /= maxf(cells.size(), 1.0)
	return c + Vector2(0.28, 0.32)


# --- movement -------------------------------------------------------------------------

func handle_event(type: String, data: Dictionary) -> void:
	if type == ARRIVE:
		var a: Dictionary = momos.get(int(data.get("id", 0)), {})
		if not a.is_empty() and int(data.get("token", -1)) == int(a["token"]) and int(a["assigned"]) != 0:
			sim.bus.emit(&"momo_arrived", {"id": a["id"], "building": a["assigned"]})
		return
	var m: Dictionary = momos.get(int(data.get("id", 0)), {})
	if m.is_empty() or int(data.get("token", -1)) != int(m["token"]) or int(m["assigned"]) != 0:
		return
	# Momo sleep at night: no strolls until the morning.
	if DayCycle.new(sim.data).is_night(sim.clock):
		m["token"] = int(m["token"]) + 1
		sim.scheduler.schedule(sim.clock.next_day_start_ms() + _rest_ms(), ROAM, {"id": m["id"], "token": m["token"]})
		return
	var world: WorldSystem = sim.system(&"world")
	var here := position_of(m["id"])
	var cell := Vector2i(floori(here.x), floori(here.y))
	var options: Array[Vector2i] = []
	for d: Vector2i in NEIGHBOURS:
		if world.is_owned(cell + d):
			options.append(cell + d)
	if options.is_empty():
		return
	var target_cell: Vector2i = options[rng.randi_range(0, options.size() - 1)]
	var target := Vector2(target_cell) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))
	var arrive := _walk_to(m, target)
	_schedule_roam(m, arrive - sim.now_ms() + _rest_ms())


func _walk_to(m: Dictionary, target: Vector2) -> int:
	var here := position_at(m["id"], sim.now_ms())
	var speed := maxf(sim.data.get_float("balance", "momo.walk_speed", 0.7), 0.05)
	var now := sim.now_ms()
	m["from"] = [here.x, here.y]
	m["to"] = [target.x, target.y]
	m["start"] = now
	m["end"] = now + int(round(here.distance_to(target) / speed * 1000.0))
	return int(m["end"])


func _stop(m: Dictionary) -> void:
	var here := position_at(m["id"], sim.now_ms())
	m["from"] = [here.x, here.y]
	m["to"] = [here.x, here.y]
	m["start"] = sim.now_ms()
	m["end"] = sim.now_ms()


func _schedule_roam(m: Dictionary, delay_ms: int) -> void:
	m["token"] = int(m["token"]) + 1
	sim.schedule_in(delay_ms, ROAM, {"id": m["id"], "token": m["token"]})


func _rest_ms() -> int:
	var r: Array = sim.data.get_value("balance", "momo.rest_seconds", [2.0, 6.0])
	return int(rng.randf_range(float(r[0]), float(r[1])) * 1000.0)


static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# --- persistence ------------------------------------------------------------------------

func save_state() -> Dictionary:
	var list: Array = []
	for id: int in ids():
		list.append(momos[id].duplicate(true))
	# The RNG state is a 64-bit integer: as a JSON number it would lose its low
	# bits and a loaded game would wander differently. Strings keep it exact.
	return {"next_id": next_id, "hired": hired, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "momos": list}


func load_state(state: Dictionary) -> void:
	momos.clear()
	next_id = int(state.get("next_id", 1))
	hired = int(state.get("hired", 0))
	rng.seed = int(str(state.get("rng_seed", "1")))
	if state.has("rng_state"):
		rng.state = int(str(state["rng_state"]))
	for raw: Dictionary in state.get("momos", []):
		var m := raw.duplicate(true)
		for k: String in ["id", "assigned", "token", "start", "end"]:
			m[k] = int(m.get(k, 0))
		var exp := {}
		var raw_exp: Dictionary = m.get("experience", {})
		for t: String in raw_exp:
			exp[t] = int(raw_exp[t])
		m["experience"] = exp
		var hist: Array = []
		for h: Dictionary in m.get("history", []):
			hist.append({"building": int(h.get("building", 0)), "type": String(h.get("type", "")), "from": int(h.get("from", 0)), "to": int(h.get("to", -1)), "by": String(h.get("by", "player"))})
		m["history"] = hist
		m["pinned"] = bool(m.get("pinned", int(m["assigned"]) != 0))
		if not m.has("from"):
			var p: Array = m.get("pos", [0.5, 0.5])
			m["from"] = p
			m["to"] = p
		momos[m["id"]] = m
