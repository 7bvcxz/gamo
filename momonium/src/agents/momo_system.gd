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
##
## Each Momo also watches a set of tiles (`watch`): it works the buildings on
## them, going to whichever is ready (JobSystem decides). Being assigned to a
## building -- dragged there, or by the manager -- makes that building's tiles
## the whole set, so nobody has to paint zones to play; Schedule (Step 60)
## adds and removes tiles one at a time, up to watch_capacity().
##
## Step 61: tiles added in Schedule mode are an ordered schedule -- the route
## `order`: the watch list keeps the order of the player's taps (a stroke:
## the order it crossed them; a tile taken away and added again goes last),
## and JobSystem works its buildings one stage each, 1 -> 2 -> 3 -> 1, never
## turning aside. `stop` is the building it is committed to now and `cursor`
## where that stop stood in the list (so a stop taken away hands over to the
## one after it). Every other route keeps its watch sorted, as before.
##
## Step 53: a new island has no Momo -- the player works alone and chooses to
## hire the first. A Momo is never put to work by itself: a hire (or one of
## the legacy's free hires) arrives idle and wanders until the player places
## it. Only a Momo the player has placed, edited or let the manager move
## (`opted_in`) is ever moved or given work by the island's own automation.

const ROAM := "momo.roam"
const ARRIVE := "momo.arrive"
const NEIGHBOURS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## How a Momo picks its next watched building (JobSystem): in the player's
## own order (Step 61, set by Schedule); nearest ready one; in reading order,
## row by row; rows alternating direction; only the buildings nearer its own
## tiles than any other watcher's; and, once researched, planning around
## waits (setting off for what will be ready).
const ROUTES: PackedStringArray = ["order", "nearest", "rows", "zigzag", "zone", "auto"]

## id -> {id, name, from [x,y], to [x,y], start, end (ms), assigned (building id), token, hired,
##        watch [[x,y]...] (sorted; in the player's order on the `order` route),
##        pinned, opted_in, stop, cursor, wait (Step 61)}
var momos: Dictionary = {}
var next_id := 1
var hired := 0
## Hires the legacy pays for (Step 53: the head start a sale gives is no
## longer Momo standing on the new island but hires the player makes).
var free_hires := 0
## Whether the island's first Momo was bought at `momo.hire.first`; later
## hires then cost what they always did (the first is not one of them).
var bought_first := false
var rng := RandomNumberGenerator.new()


func _init() -> void:
	key = &"momo"


func handled_events() -> PackedStringArray:
	return PackedStringArray([ROAM, ARRIVE])


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["momo.hire", "momo.assign", "momo.unassign", "momo.move", "momo.pin", "momo.watch", "momo.route"])


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


## A building that disappears (a cancelled construction) lets its workers go;
## a stage a Momo finishes is experience at that kind of building.
func _on_event(type: StringName, payload: Dictionary) -> void:
	if type == &"building_removed":
		for id: int in workers_at(int(payload.get("id", 0))):
			unassign(id, true)
	elif type == &"building_built":
		_auto_watch_building(int(payload.get("id", 0)))
	elif type == &"task_completed":
		var worker := int(payload.get("worker", 0))
		if momos.has(worker):
			var exp: Dictionary = momos[worker]["experience"]
			var t := String(payload.get("type", ""))
			var before := proficiency(worker, t)
			# One stage, one point -- times the School, its fraction carried.
			var specials: SpecialSystem = sim.system(&"specials")
			var gain := 1
			if specials != null:
				gain = specials.scaled_exp(1, momos[worker]["exp_carry"], t)
			exp[t] = int(exp.get(t, 0)) + gain
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
	var legacy: PrestigeSystem = sim.system(&"prestige")
	if legacy != null:
		m *= legacy.work_factor()
	return m


func on_new_game() -> void:
	momos.clear()
	_ids.clear()
	_watch_sig = -1
	next_id = 1
	hired = 0
	free_hires = 0
	bought_first = false
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
		"start": now, "end": now, "assigned": 0, "token": 0, "experience": {}, "history": [], "pinned": false, "watch": [],
		"route": "nearest", "route_since": now, "exp_carry": {}, "opted_in": false, "stop": 0, "cursor": 0, "wait": 0}
	sim.bus.emit(&"momo_added", {"id": id})
	_schedule_roam(momos[id], _rest_ms())
	return id


# --- queries ------------------------------------------------------------------------

## Momo ids in order (a copy). Kept sorted until the Momo change.
func ids() -> Array[int]:
	if _ids.size() != momos.size():
		_ids.clear()
		for id: int in momos:
			_ids.append(id)
		_ids.sort()
	return _ids.duplicate()


var _ids: Array[int] = []
## The day's parts, read once from the data.
var _cycle: DayCycle
## cell -> Momo watching it (sorted), rebuilt when any watch set changes.
var _watch_index: Dictionary = {}
var _watch_sig := -1


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
	for id: int in momos:
		if int(momos[id]["assigned"]) == building:
			out.append(id)
	out.sort()
	return out


func slots_of(building: int) -> int:
	var b := (sim.system(&"buildings") as BuildingSystem).get_building(building)
	return int((sim.system(&"buildings") as BuildingSystem).type_def(b).get("workers", 0)) if not b.is_empty() else 0


## The next hire's price: nothing while the legacy pays; the island's first
## Momo at `first`; after that the old ladder, as if the first were free.
func hire_cost() -> int:
	if free_hires > 0:
		return 0
	if momos.is_empty() and hired == 0:
		return sim.data.get_int("balance", "momo.hire.first", 15)
	var base := sim.data.get_float("balance", "momo.hire.base", 30.0)
	var growth := sim.data.get_float("balance", "momo.hire.growth", 1.6)
	var step := maxi(sim.data.get_int("balance", "momo.hire.round_to", 5), 1)
	return int(ceil(base * pow(growth, hired - int(bought_first)) / step)) * step


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
		"momo.watch":
			var cells: Array[Vector2i] = []
			for c: Variant in command.get("cells", []):
				if typeof(c) == TYPE_ARRAY and (c as Array).size() == 2:
					cells.append(Vector2i(int(c[0]), int(c[1])))
			return set_watch(Cmd.integer(command, "momo"), cells, Cmd.text(command, "op"), bool(command.get("schedule", false)))
		"momo.route":
			return set_route(Cmd.integer(command, "momo"), Cmd.text(command, "route"))
		"momo.move":
			var p: Variant = command.get("pos")
			return move_to(Cmd.integer(command, "momo"), Vector2(float(p[0]), float(p[1])) if typeof(p) == TYPE_ARRAY else Vector2(-999, -999))
	return SimResult.fail("err.unknown_command")


func hire() -> Dictionary:
	var cost := hire_cost()
	var economy: EconomySystem = sim.system(&"economy")
	if not economy.can_afford(cost):
		return SimResult.fail("err.not_enough_money", {"cost": cost})
	if free_hires > 0:
		free_hires -= 1
	else:
		bought_first = bought_first or (momos.is_empty() and hired == 0)
		economy.spend(cost, "hire")
		hired += 1
	var world: WorldSystem = sim.system(&"world")
	var cells := world.owned_cells()
	var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var id := add_momo(Vector2(cell) + Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75)))
	# It arrives idle: the player decides where it works (Step 53).
	sim.bus.emit(&"momo_hired", {"id": id, "cost": cost})
	return SimResult.ok({"id": id, "cost": cost, "next_cost": hire_cost()})


## `by_player`: placed by the player (dragged, or the Assign button) -- such
## a Momo is pinned and a manager never moves it. A manager assigns unpinned.
##
## `keep_watch`: the Momo goes to a building it already watches (its rounds,
## JobSystem); otherwise the building's tiles become everything it watches.
func assign(momo: int, building: int, by_player: bool = true, keep_watch: bool = false) -> Dictionary:
	var check := can_assign(momo, building)
	if not check["ok"] and by_player and not keep_watch and String(check["reason"]) == "err.slots_full":
		# The player's choice wins over a Momo that only took the place by
		# itself (a new building or a hire looked after automatically, the
		# manager): that one leaves it and goes on with its other tiles.
		var other := _displaceable(building)
		if other != 0:
			_give_up(other, building)
			check = can_assign(momo, building)
	if not check["ok"]:
		return check
	var m: Dictionary = momos[momo]
	if not keep_watch:
		var cells: Array = []
		var bs: BuildingSystem = sim.system(&"buildings")
		for c: Vector2i in bs.cells_of(bs.get_building(building)):
			cells.append([c.x, c.y])
		cells.sort()
		m["watch"] = cells
		_watch_sig = -1
	elif int(m["assigned"]) == building:
		var again := _walk_to(m, work_spot(building))
		m["token"] = int(m["token"]) + 1
		sim.scheduler.schedule(again, ARRIVE, {"id": momo, "token": m["token"]})
		return SimResult.ok()
	if keep_watch:
		by_player = bool(m.get("pinned", false))
	if int(m["assigned"]) != 0 and int(m["assigned"]) != building:
		_close_history(m)
	m["assigned"] = building
	m["pinned"] = by_player
	m["opted_in"] = bool(m.get("opted_in", false)) or by_player
	var b := (sim.system(&"buildings") as BuildingSystem).get_building(building)
	var hist: Array = m["history"]
	hist.append({"building": building, "type": String(b.get("type", "")), "from": sim.now_ms(), "to": -1, "by": "player" if by_player else "manager"})
	while hist.size() > sim.data.get_int("balance", "momo.history_kept", 12):
		hist.pop_front()
	var arrive := _walk_to(m, work_spot(building))
	m["token"] = int(m["token"]) + 1
	sim.scheduler.schedule(arrive, ARRIVE, {"id": momo, "token": m["token"]})
	sim.bus.emit(&"momo_assigned", {"id": momo, "building": building})
	if not keep_watch:
		sim.bus.emit(&"momo_watch_changed", {"id": momo})
	return SimResult.ok()


## A Momo at `building` the player did not put there (unpinned), or one that
## is only passing on its rounds (it watches more than this building: it keeps
## the rest), or 0. (Step 50: a hired Momo was refused every building -- the
## first Momo, given its farm in the tutorial, was at each in turn.)
func _displaceable(building: int) -> int:
	for id: int in workers_at(building):
		if not bool(momos[id].get("pinned", false)) or _watches_elsewhere(id, building):
			return id
	return 0


func _watches_elsewhere(momo: int, building: int) -> bool:
	var bs: BuildingSystem = sim.system(&"buildings")
	var own := bs.cells_of(bs.get_building(building))
	for c: Array in momos[momo]["watch"]:
		if not own.has(Vector2i(int(c[0]), int(c[1]))):
			return true
	return false


## `momo` stops looking after `building`: its tiles leave its rounds and it
## lets the building go (a stage under way finishes by itself).
func _give_up(momo: int, building: int) -> void:
	var m: Dictionary = momos[momo]
	var bs: BuildingSystem = sim.system(&"buildings")
	var watch: Array = m["watch"]
	for c: Vector2i in bs.cells_of(bs.get_building(building)):
		watch.erase([c.x, c.y])
	_watch_sig = -1
	if int(m["assigned"]) == building:
		unassign(momo, true)
	sim.bus.emit(&"momo_watch_changed", {"id": momo})


## Whether an assigned Momo has reached its building and can work.
func at_work(id: int) -> bool:
	var m: Dictionary = momos.get(id, {})
	return not m.is_empty() and int(m["assigned"]) != 0 and not is_moving(id) \
		and position_of(id).distance_to(work_spot(int(m["assigned"]))) < 0.01


## Lets a Momo go from its building. Unless `keep_watch` (its rounds go on
## elsewhere, or its building is gone), it stops watching anything too.
func unassign(momo: int, keep_watch: bool = false) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	var m: Dictionary = momos[momo]
	var was := int(m["assigned"])
	if was == 0:
		return SimResult.fail("err.not_assigned")
	_close_history(m)
	m["assigned"] = 0
	if not keep_watch:
		m["pinned"] = false
		if not (m["watch"] as Array).is_empty():
			m["watch"] = []
			_watch_sig = -1
			sim.bus.emit(&"momo_watch_changed", {"id": momo})
	_stop(m)
	_schedule_roam(m, _rest_ms())
	sim.bus.emit(&"momo_unassigned", {"id": momo, "building": was})
	return SimResult.ok()


func _close_history(m: Dictionary) -> void:
	var hist: Array = m["history"]
	if not hist.is_empty() and int(hist.back()["to"]) < 0:
		hist.back()["to"] = sim.now_ms()


# --- watched tiles -----------------------------------------------------------------

## How many tiles one Momo may watch: the base, plus research.
func watch_capacity(_momo: int = 0) -> int:
	var n := sim.data.get_int("balance", "momo.watch.base_tiles", 4)
	var research: ResearchSystem = sim.system(&"research")
	if research != null:
		n += research.watch_bonus()
	return n


func watched(momo: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Array in momos.get(momo, {}).get("watch", []):
		out.append(Vector2i(int(c[0]), int(c[1])))
	return out


func is_watching(momo: int, cell: Vector2i) -> bool:
	return (momos.get(momo, {}).get("watch", []) as Array).has([cell.x, cell.y])


## The Momo watching any tile of `building`.
func watchers_of(building: int) -> Array[int]:
	var bs: BuildingSystem = sim.system(&"buildings")
	var cells := bs.cells_of(bs.get_building(building))
	var index := _watchers_index()
	var out: Array[int] = []
	for c: Vector2i in cells:
		for id: int in index.get(c, []):
			if not out.has(id):
				out.append(id)
	out.sort()
	return out


## Who watches each cell. Rebuilt when the watched tiles change: every write
## to a watch set clears `_watch_sig` on the spot, and the total of watched
## tiles and the Momo count are checked as well.
func _watchers_index() -> Dictionary:
	var total := 0
	for id: int in momos:
		total += (momos[id].get("watch", []) as Array).size()
	var sig := total * 1000 + momos.size()
	if sig == _watch_sig:
		return _watch_index
	_watch_sig = sig
	_watch_index.clear()
	for id: int in ids():
		for c: Array in momos[id].get("watch", []):
			var cell := Vector2i(int(c[0]), int(c[1]))
			if not _watch_index.has(cell):
				_watch_index[cell] = []
			(_watch_index[cell] as Array).append(id)
	return _watch_index


## Whether `momo` may start watching `cell`: its island's land, not a
## building with no Momo work (a solar roof), and room in its rounds.
func can_watch(momo: int, cell: Vector2i) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	if is_watching(momo, cell):
		return SimResult.ok()
	if not (sim.system(&"world") as WorldSystem).is_owned(cell):
		return SimResult.fail("err.not_owned")
	var bs: BuildingSystem = sim.system(&"buildings")
	var on := bs.building_at(cell)
	if on != 0 and slots_of(on) <= 0:
		return SimResult.fail("err.no_work_here")
	if (momos[momo]["watch"] as Array).size() >= watch_capacity(momo):
		return SimResult.fail("err.watch_full", {"capacity": watch_capacity(momo)})
	return SimResult.ok()


## Adds (`op` "add") or removes ("remove") tiles from what a Momo watches --
## the same operation for every tile, so a brush stroke never flips a tile
## twice. Each tile that cannot be added says why; the rest still go in. A
## Momo whose zone the player edits is theirs: the manager leaves it alone.
## `schedule` (Schedule mode, Step 61): tiles added are appended in the order
## given and the Momo follows them in that order (the `order` route).
func set_watch(momo: int, cells: Array[Vector2i], op: String, schedule: bool = false) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	if op == "set":
		return _set_watch_exactly(momo, cells)
	if op != "add" and op != "remove":
		return SimResult.fail("err.bad_command")
	var m: Dictionary = momos[momo]
	var watch: Array = m["watch"]
	var changed: Array = []
	var refused := {}
	var reordered := false
	if schedule and op == "add" and String(m.get("route", "nearest")) != "order":
		# The tiles it has keep their places (sorted, as they were); what the
		# player adds now follows them.
		m["route"] = "order"
		m["route_since"] = sim.now_ms()
		reordered = true
	for c: Vector2i in cells:
		var key := [c.x, c.y]
		if op == "add":
			if watch.has(key):
				continue
			var check := can_watch(momo, c)
			if not check["ok"]:
				refused["%d,%d" % [c.x, c.y]] = check["reason"]
				continue
			watch.append(key)
			changed.append(key)
		elif watch.has(key):
			watch.erase(key)
			changed.append(key)
	if String(m.get("route", "nearest")) != "order":
		watch.sort()
	if reordered:
		sim.bus.emit(&"momo_route_changed", {"id": momo, "route": "order"})
	if not changed.is_empty():
		# Who watches what is read again before anyone hears of it.
		_watch_sig = -1
		m["pinned"] = true
		m["opted_in"] = true
		# Its building is no longer on its rounds: it goes (a stage under way
		# finishes by itself), and JobSystem finds it the next job.
		var at := int(m["assigned"])
		if at != 0 and op == "remove":
			var bs: BuildingSystem = sim.system(&"buildings")
			var still := false
			for c: Vector2i in bs.cells_of(bs.get_building(at)):
				still = still or watch.has([c.x, c.y])
			if not still:
				unassign(momo, true)
		sim.bus.emit(&"momo_watch_changed", {"id": momo})
	return SimResult.ok({"changed": changed, "refused": refused, "count": watch.size(), "capacity": watch_capacity(momo)})


## `op` "set": the watch becomes exactly `cells`, in that order (an undone
## stroke puts a schedule back as it was). Tiles it may not take are left
## out, as an add would.
func _set_watch_exactly(momo: int, cells: Array[Vector2i]) -> Dictionary:
	var m: Dictionary = momos[momo]
	var old: Array = (m["watch"] as Array).duplicate()
	m["watch"] = []
	var refused := {}
	for c: Vector2i in cells:
		if (m["watch"] as Array).has([c.x, c.y]):
			continue
		var check := can_watch(momo, c)
		if check["ok"]:
			(m["watch"] as Array).append([c.x, c.y])
		else:
			refused["%d,%d" % [c.x, c.y]] = check["reason"]
	if String(m.get("route", "nearest")) != "order":
		(m["watch"] as Array).sort()
	_watch_sig = -1
	if m["watch"] != old:
		var at := int(m["assigned"])
		if at != 0:
			var bs: BuildingSystem = sim.system(&"buildings")
			var still := false
			for c: Vector2i in bs.cells_of(bs.get_building(at)):
				still = still or (m["watch"] as Array).has([c.x, c.y])
			if not still:
				unassign(momo, true)
		sim.bus.emit(&"momo_watch_changed", {"id": momo})
	return SimResult.ok({"changed": [], "refused": refused, "count": (m["watch"] as Array).size(), "capacity": watch_capacity(momo)})


# --- looking after new work by itself (Step 50) ---------------------------------------

## With `balance.momo.watch.auto`, nobody has to be told twice: a building
## finished on tiles nobody watches is taken by a Momo with nothing to do, or
## else the nearest Momo with room for all its tiles (lowest id on a tie).
## Only a Momo the player has put to work before (`opted_in`) is asked -- a
## new hire is never placed by itself (Step 53; Step 50 had a hire take the
## unwatched buildings near it, or half of the busiest Momo's). Until the
## player has put some Momo to work, none is. (Step 50: nearest-with-room
## alone put a second island's nine tiles on one Momo while two stood idle.)
## It does not pin the Momo (the player's own edits do) -- the manager may
## still move it.
func _auto_watch_building(building: int) -> void:
	if not bool(sim.data.get_value("balance", "momo.watch.auto", false)) or building == 0:
		return
	var bs: BuildingSystem = sim.system(&"buildings")
	var b := bs.get_building(building)
	if b.is_empty() or slots_of(building) <= 0 or not watchers_of(building).is_empty():
		return
	var cells := bs.cells_of(b)
	var spot := work_spot(building)
	var anyone_working := false
	for id: int in ids():
		anyone_working = anyone_working or not (momos[id]["watch"] as Array).is_empty()
	if not anyone_working:
		return
	# An idle Momo first; otherwise the nearest with room. (Spreading every
	# building to whoever had least scattered each Momo's tiles across the
	# island: income at 20:00 fell from $11,354 to $6,193, all of it walking.)
	var best := 0
	var best_idle := false
	var best_d := INF
	for id: int in ids():
		var n := (momos[id]["watch"] as Array).size()
		if not bool(momos[id].get("opted_in", false)) or n + cells.size() > watch_capacity(id):
			continue
		var idle := n == 0
		var d := position_of(id).distance_to(spot)
		if best == 0 or (idle and not best_idle) or (idle == best_idle and d < best_d):
			best = id
			best_idle = idle
			best_d = d
	if best != 0:
		_watch_more(best, cells)


func _watch_more(momo: int, cells: Array[Vector2i]) -> void:
	var watch: Array = momos[momo]["watch"]
	for c: Vector2i in cells:
		if not watch.has([c.x, c.y]) and can_watch(momo, c)["ok"]:
			watch.append([c.x, c.y])
	# A schedule takes the new building last; any other watch stays sorted.
	if String(momos[momo].get("route", "nearest")) != "order":
		watch.sort()
	_watch_sig = -1
	sim.bus.emit(&"momo_watch_changed", {"id": momo, "auto": true})


# --- routes --------------------------------------------------------------------------

## The strategies this island can use now (auto once researched).
func routes_open() -> PackedStringArray:
	var out: PackedStringArray = []
	var research: ResearchSystem = sim.system(&"research")
	for r: String in ROUTES:
		if r != "auto" or (research != null and research.opens_route("auto")):
			out.append(r)
	return out


## How this Momo picks its jobs now: its choice, or nearest when that choice
## is no longer open (its research points were placed elsewhere).
func route_of(momo: int) -> String:
	var r := String(momos.get(momo, {}).get("route", "nearest"))
	return r if routes_open().has(r) else "nearest"


func set_route(momo: int, route: String) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	if not ROUTES.has(route):
		return SimResult.fail("err.bad_command")
	if not routes_open().has(route):
		return SimResult.fail("err.needs_research", {"research": "smart_schedule"})
	var m: Dictionary = momos[momo]
	if String(m.get("route", "nearest")) == route:
		return SimResult.ok()
	m["route"] = route
	m["route_since"] = sim.now_ms()
	sim.bus.emit(&"momo_route_changed", {"id": momo, "route": route})
	return SimResult.ok()


## Lets the manager move this Momo (false), or keeps it where the player put it (true).
func set_pinned(momo: int, pinned: bool) -> Dictionary:
	if not momos.has(momo):
		return SimResult.fail("err.no_momo")
	momos[momo]["pinned"] = pinned
	# Either way the player has decided about this Momo: letting the manager
	# move it is a placement too.
	momos[momo]["opted_in"] = true
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
	if _cycle == null:
		_cycle = DayCycle.new(sim.data)
	if _cycle.is_night(sim.clock):
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


## Tiles a second a Momo walks: the base over `balance.pace.travel_scale`
## (Step 58: walks take 1.3 times as long), times transport research.
func walk_speed() -> float:
	var speed := maxf(sim.data.get_float("balance", "momo.walk_speed", 0.7), 0.05)
	speed /= maxf(sim.data.get_float("balance", "pace.travel_scale", 1.0), 0.05)
	var research: ResearchSystem = sim.system(&"research")
	if research != null:
		speed *= research.walk_multiplier()
	return speed


func _walk_to(m: Dictionary, target: Vector2) -> int:
	var here := position_at(m["id"], sim.now_ms())
	var speed := walk_speed()
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
	return {"next_id": next_id, "hired": hired, "free_hires": free_hires, "bought_first": bought_first,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state), "momos": list}


func load_state(state: Dictionary) -> void:
	momos.clear()
	_ids.clear()
	_watch_sig = -1
	next_id = int(state.get("next_id", 1))
	hired = int(state.get("hired", 0))
	free_hires = int(state.get("free_hires", 0))
	bought_first = bool(state.get("bought_first", false))
	rng.seed = int(str(state.get("rng_seed", "1")))
	if state.has("rng_state"):
		rng.state = int(str(state["rng_state"]))
	for raw: Dictionary in state.get("momos", []):
		var m := raw.duplicate(true)
		for k: String in ["id", "assigned", "token", "start", "end", "stop", "cursor", "wait"]:
			m[k] = int(m.get(k, 0))
		var exp := {}
		var raw_exp: Dictionary = m.get("experience", {})
		for t: String in raw_exp:
			exp[t] = int(raw_exp[t])
		m["experience"] = exp
		var carry := {}
		for t: String in m.get("exp_carry", {}):
			carry[t] = clampi(int(m["exp_carry"][t]), 0, 999)
		m["exp_carry"] = carry
		var hist: Array = []
		for h: Dictionary in m.get("history", []):
			hist.append({"building": int(h.get("building", 0)), "type": String(h.get("type", "")), "from": int(h.get("from", 0)), "to": int(h.get("to", -1)), "by": String(h.get("by", "player"))})
		m["history"] = hist
		m["pinned"] = bool(m.get("pinned", int(m["assigned"]) != 0))
		# Before Step 53 nothing recorded it: a Momo already at work or with
		# rounds was put there (by the player or for them) and stays theirs.
		if not m.has("opted_in"):
			m["opted_in"] = int(m["assigned"]) != 0 or not (m.get("watch", []) as Array).is_empty() or not hist.is_empty()
		m["opted_in"] = bool(m["opted_in"])
		# Before watched tiles, a Momo watched exactly its building.
		if not m.has("watch"):
			var cells: Array = []
			var bs: BuildingSystem = sim.system(&"buildings")
			if int(m["assigned"]) != 0 and bs != null and not bs.get_building(int(m["assigned"])).is_empty():
				for c: Vector2i in bs.cells_of(bs.get_building(int(m["assigned"]))):
					cells.append([c.x, c.y])
			m["watch"] = cells
		m["route"] = String(m.get("route", "nearest")) if ROUTES.has(String(m.get("route", "nearest"))) else "nearest"
		m["route_since"] = int(m.get("route_since", 0))
		var w: Array = []
		for c: Variant in m["watch"]:
			w.append([int(c[0]), int(c[1])])
		# A schedule's order is the point of it (Step 61); a save from before
		# it has no `order` route, and its sorted watch is the stable fallback.
		if m["route"] != "order":
			w.sort()
		m["watch"] = w
		if not m.has("from"):
			var p: Array = m.get("pos", [0.5, 0.5])
			m["from"] = p
			m["to"] = p
		momos[m["id"]] = m
