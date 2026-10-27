class_name JobSystem
extends SimSystem

## Assigned Momo work their building by themselves.
##
## Event-driven, never polled: a building becoming idle (a stage done, a
## cooldown over, construction finished), a Momo arriving at its building, a
## new morning, or research or a recipe changing what can run each make this look at
## exactly the buildings concerned. If a worker is there and ready, the
## building's next stage starts with that Momo, taking work_time_multiplier
## times the player's time. Cooldowns are untouched -- the plants do not drink
## faster because a Momo poured.
##
## Rounds: a Momo works the buildings on the tiles it watches. When it is
## free -- its stage done, its zone edited, a watched building turning ready
## -- it goes to the nearest watched building that could start now and has
## room (`dispatch`); with nothing ready it stays where it is. A Momo watching
## only its own building (the default) never leaves it, exactly as before.
##
## Fairness: when several Momo share a building, the one who has waited
## longest goes next. Nothing is ever started twice: the building's own state
## machine refuses a second start, and completion events carry tokens.
##
## The player's own order (Step 61, the `order` route Schedule sets): the
## Momo works its stops -- the buildings on its tiles, in the order it was
## given them, each once -- strictly in turn: one stage at stop 1, then 2,
## then 3, then 1 again. It is committed to the stop it is walking to and
## nothing turns it aside -- not a nearer building coming free, a delivery,
## another Momo, the manager or automation; only the player editing its
## tiles, the stop being pulled down or the island reset. At a stop that is
## not ready it waits: a cooldown, a stage under way or a building going up
## end by themselves; a stop that cannot start for another reason (inputs,
## a full store, power, every place taken) is waited for WAIT_KEY seconds
## (`balance.momo.schedule.wait_seconds`), then passed over until its turn
## comes round again. A stop with no Momo work (gone, or automated) is
## passed over at once.
##
## The calculation lives here; the views only look at who is working where.

## momo id -> ms it last finished a stage (fair rotation; not needing saving
## beyond a session, but saved so a load does not reshuffle turns).
var last_worked: Dictionary = {}

## The `worker` recorded for a stage that ran by itself (irrigation).
const AUTO_WORKER := -1
## The end of a scheduled Momo's patience at a stop that cannot start.
const WAIT := "jobs.wait"


func _init() -> void:
	key = &"jobs"


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


func on_new_game() -> void:
	last_worked.clear()


func handled_events() -> PackedStringArray:
	return PackedStringArray([WAIT])


## A scheduled Momo waited long enough at a stop that still cannot start:
## it goes on to the next (the stop keeps its place in the order).
func handle_event(type: String, data: Dictionary) -> void:
	if type != WAIT:
		return
	var momos: MomoSystem = sim.system(&"momo")
	var id := int(data.get("id", 0))
	var m := momos.get_momo(id)
	if m.is_empty() or int(data.get("token", -1)) != int(m.get("wait", 0)) or momos.route_of(id) != "order":
		return
	var stop := int(data.get("stop", 0))
	if int(m.get("stop", 0)) != stop or is_working(id) or (momos.at_work(id) and _open_for(id, stop)):
		return
	var stops := stops_of(id)
	if stops.size() > 1:
		_advance(id, stops, stop)
	dispatch(id)


func _on_event(type: StringName, payload: Dictionary) -> void:
	match type:
		&"building_idle":
			var id := int(payload["id"])
			if not try_start(id)["ok"]:
				# Nothing to do here for the Momo standing by: their rounds go on.
				var momos: MomoSystem = sim.system(&"momo")
				for w: int in momos.workers_at(id):
					if momos.at_work(w):
						dispatch(w, id)
				_call_watchers(id)
		&"momo_arrived":
			var arrived := int(payload.get("building", 0))
			if (sim.system(&"momo") as MomoSystem).route_of(int(payload.get("id", 0))) == "order":
				# At its stop: start, or wait there (never turn aside).
				dispatch(int(payload.get("id", 0)))
				return
			if not try_start(arrived)["ok"]:
				# The smart route came early on purpose: it waits for the cooldown.
				var b := (sim.system(&"buildings") as BuildingSystem).get_building(arrived)
				var waits: bool = (sim.system(&"momo") as MomoSystem).route_of(int(payload.get("id", 0))) == "auto" \
					and not b.is_empty() and b["state"] == BuildingSystem.COOLDOWN
				if not waits:
					dispatch(int(payload.get("id", 0)), arrived)
		&"momo_assigned":
			try_start(int(payload.get("building", 0)))
		&"momo_watch_changed", &"momo_route_changed":
			dispatch(int(payload.get("id", 0)))
		&"task_completed":
			var worker := int(payload.get("worker", 0))
			if worker > 0:
				last_worked[worker] = sim.now_ms()
				var ms: MomoSystem = sim.system(&"momo")
				if ms.route_of(worker) == "order":
					# One stage done at this stop: on to the next one in order.
					var done := int(payload.get("id", 0))
					if int(ms.get_momo(worker).get("stop", 0)) == done:
						_advance(worker, stops_of(worker), done)
					dispatch(worker)
					return
				# A wait follows: meanwhile it may work elsewhere on its rounds.
				# (No wait: building_idle comes next and starts it again here.)
				var b := (sim.system(&"buildings") as BuildingSystem).get_building(int(payload.get("id", 0)))
				if not b.is_empty() and b["state"] == BuildingSystem.COOLDOWN:
					dispatch(worker, int(payload.get("id", 0)))
		&"research_completed", &"recipe_changed", &"research_started":
			# (Starting research spends notes: room for a lab that was full.)
			_try_all()
		&"inventory_changed":
			# Inputs arriving can unblock a waiting furnace.
			if int(payload.get("delta", 0)) > 0:
				_try_waiting()


func on_day_started(_day: int) -> void:
	_try_all()
	var momos: MomoSystem = sim.system(&"momo")
	for id: int in momos.ids():
		dispatch(id)


## Buildings idle for want of inputs, tried again.
func _try_waiting() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var inv: InventorySystem = sim.system(&"inventory")
	for id: int in _consumer_ids():
		var b := buildings.get_building(id)
		if b.is_empty() or b["state"] != BuildingSystem.IDLE or not _consumer(String(b["type"])):
			continue
		var consumes: Dictionary = buildings.current_stage(b).get("consumes", {})
		# Still short of its inputs: it could not start -- no need to ask.
		if not consumes.is_empty() and inv.has_all(consumes):
			try_start(id)


## Kinds of building that ever take inputs (recipes, or a stage that consumes).
func _consumer(type: String) -> bool:
	if not _consumers.has(type):
		var t := sim.data.building_type(type)
		var takes := not (t.get("recipes", []) as Array).is_empty()
		for st: Dictionary in t.get("cycle", {}).get("stages", []):
			takes = takes or not (st.get("consumes", {}) as Dictionary).is_empty()
		_consumers[type] = takes
	return bool(_consumers[type])


var _consumers: Dictionary = {}
## The buildings of those kinds, in id order; rebuilt when buildings change.
var _consumer_list: Array[int] = []
var _consumer_sig := -1


func _consumer_ids() -> Array[int]:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var sig := buildings.ids_version
	if sig != _consumer_sig:
		_consumer_sig = sig
		_consumer_list.clear()
		for id: int in buildings.ids():
			if _consumer(String(buildings.get_building(id)["type"])):
				_consumer_list.append(id)
	return _consumer_list



func _try_all() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var research: ResearchSystem = sim.system(&"research")
	# Who is posted where, read once: a building nobody is posted to, with no
	# stage that runs by itself, has no one to start it -- it is not asked.
	var staffed := {}
	for m: int in momos.momos:
		staffed[int(momos.momos[m]["assigned"])] = true
	for id: int in buildings.ids():
		if not staffed.has(id):
			var b := buildings.get_building(id)
			if b.is_empty() or b["state"] != BuildingSystem.IDLE:
				continue
			var action := String(buildings.current_stage(b).get("action", ""))
			if research == null or not research.is_auto(String(b["type"]), action):
				continue
		try_start(id)


func resting() -> bool:
	if sim.data.get_value("balance", "momo.works_at_night", false):
		return false
	if _cycle == null:
		_cycle = DayCycle.new(sim.data)
	return _cycle.is_night(sim.clock)


## The day's parts, read once from the data (resting() is asked constantly).
var _cycle: DayCycle


## The worker who would take the building's next stage now, or 0.
func next_worker(building: int) -> int:
	var momos: MomoSystem = sim.system(&"momo")
	var best := 0
	var best_since := 9223372036854775807
	for id: int in momos.workers_at(building):
		if not momos.at_work(id):
			continue
		var since := int(last_worked.get(id, -1))
		if since < best_since:
			best = id
			best_since = since
	return best


## Whether a Momo is in the middle of a stage somewhere.
func is_working(momo: int) -> bool:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var at := int((sim.system(&"momo") as MomoSystem).get_momo(momo).get("assigned", 0))
	var b := buildings.get_building(at)
	return not b.is_empty() and b["state"] == BuildingSystem.WORKING and int(b.get("worker", 0)) == momo


## A free Momo picks its next job among the buildings it watches, in the
## order its route gives (route_order): the first that could start now and has
## room for it. Its own building, when it comes up first and qualifies, is
## simply started; `skip` (just tried) is not walked back to. With the smart
## route it may also set off for a building that will be ready by the time it
## arrives. Returns the building it went to (or stays at), or 0.
func dispatch(momo: int, skip: int = 0) -> int:
	var momos: MomoSystem = sim.system(&"momo")
	var m := momos.get_momo(momo)
	if m.is_empty() or (m.get("watch", []) as Array).is_empty() or resting() or is_working(momo):
		return 0
	if momos.route_of(momo) == "auto":
		return _dispatch_auto(momo, skip)
	if momos.route_of(momo) == "order":
		return _dispatch_order(momo)
	var at := int(m["assigned"])
	for id: int in route_order(momo):
		if id == skip or not _open_for(momo, id):
			continue
		if id == at:
			# Its own building (or the one it is walking to) is ready.
			if momos.at_work(momo):
				try_start(id)
			return id
		if momos.assign(momo, id, false, true)["ok"]:
			return id
	return 0


## The player's order (Step 61): commit to the current stop -- walk there,
## start its stage, or wait for it. Stops with no Momo work are passed over
## at once; one that cannot start for long is passed over after a wait.
func _dispatch_order(momo: int) -> int:
	var momos: MomoSystem = sim.system(&"momo")
	var m := momos.get_momo(momo)
	var stops := stops_of(momo)
	if stops.is_empty():
		m["stop"] = 0
		return 0
	var cur := current_stop(momo, stops)
	for i in stops.size():
		if _job_for_momo(cur):
			break
		cur = _advance(momo, stops, cur)
	if not _job_for_momo(cur):
		return 0
	if int(m["assigned"]) != cur:
		# Committed: it walks there, and only an edit or the stop's end
		# changes that (the events above never call it elsewhere).
		if momos.assign(momo, cur, false, true)["ok"]:
			return cur
		# Every place there is someone else's: its turn waits a little.
		_wait_at(momo, cur)
		return 0
	if momos.at_work(momo):
		if _open_for(momo, cur):
			try_start(cur)
		else:
			_wait_at(momo, cur)
	return cur


## The number each stop shows on the island (1, 2, 3 ... in the player's
## order), or {} for a Momo not on its own order.
func stop_numbers(momo: int) -> Dictionary:
	var out := {}
	if (sim.system(&"momo") as MomoSystem).route_of(momo) != "order":
		return out
	var stops := stops_of(momo)
	for i in stops.size():
		out[stops[i]] = i + 1
	return out


## The stops of a Momo on the player's order: the buildings on its tiles in
## the order the tiles were given, each once (a building on several tiles
## counts at its first); empty tiles and buildings no Momo works are none.
func stops_of(momo: int) -> Array[int]:
	var momos: MomoSystem = sim.system(&"momo")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var out: Array[int] = []
	for c: Vector2i in momos.watched(momo):
		var id := buildings.building_at(c)
		if id != 0 and not out.has(id) and momos.slots_of(id) > 0:
			out.append(id)
	return out


## The stop this Momo is committed to: the one it was, while it is still in
## the list; when it was taken away, the one that came after it (now in its
## place); with none yet, the first.
func current_stop(momo: int, stops: Array[int]) -> int:
	var m := (sim.system(&"momo") as MomoSystem).get_momo(momo)
	var s := int(m.get("stop", 0))
	var i := stops.find(s)
	if i < 0:
		i = int(m.get("cursor", 0)) % stops.size() if s != 0 else 0
	m["stop"] = stops[i]
	m["cursor"] = i
	return stops[i]


## On to the stop after `from` (wrapping round); returns it.
func _advance(momo: int, stops: Array[int], from: int) -> int:
	var m := (sim.system(&"momo") as MomoSystem).get_momo(momo)
	if stops.is_empty():
		m["stop"] = 0
		return 0
	var i := (stops.find(from) + 1) % stops.size()
	m["stop"] = stops[i]
	m["cursor"] = i
	m["wait"] = int(m.get("wait", 0)) + 1
	return stops[i]


## Waiting at a stop that is not ready. A cooldown, a stage under way or a
## building going up ends by itself (its building_idle starts it here); any
## other hold-up is waited out for wait_seconds, then the next stop.
func _wait_at(momo: int, stop: int) -> void:
	var b := (sim.system(&"buildings") as BuildingSystem).get_building(stop)
	if not b.is_empty() and String(b["state"]) in [BuildingSystem.COOLDOWN, BuildingSystem.WORKING, BuildingSystem.CONSTRUCTING] \
			and (sim.system(&"momo") as MomoSystem).workers_at(stop).size() <= (sim.system(&"momo") as MomoSystem).slots_of(stop):
		return
	var m := (sim.system(&"momo") as MomoSystem).get_momo(momo)
	m["wait"] = int(m.get("wait", 0)) + 1
	var ms := int(sim.data.get_float("balance", "momo.schedule.wait_seconds", 15.0) * 1000.0)
	sim.schedule_in(ms, WAIT, {"id": momo, "stop": stop, "token": m["wait"]})


## The watched buildings in the order this Momo's route visits them:
## nearest / zone / auto -- by distance from where it is (zone: only those
## nearer its own tiles than any other watcher's); rows -- reading order, row
## by row; zigzag -- rows alternating left-right and right-left. A row route
## goes on from where the Momo is: the building it is at comes last.
func route_order(momo: int) -> Array[int]:
	var momos: MomoSystem = sim.system(&"momo")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var route := momos.route_of(momo)
	if route == "order":
		# The player's order, from the stop it is committed to.
		var stops := stops_of(momo)
		if stops.is_empty():
			return stops
		var k := maxi(stops.find(int(momos.get_momo(momo).get("stop", 0))), 0)
		var turned: Array[int] = []
		turned.assign(stops.slice(k) + stops.slice(0, k))
		return turned
	var list := _watched_buildings(momo)
	if route == "zone":
		list = list.filter(func(id: int) -> bool: return zone_owner(id) == momo)
	# Sort keys are read once per building, not in every comparison (the
	# order is the same; ordering is asked on every dispatch).
	if route == "rows" or route == "zigzag":
		var anchors := {}
		for id: int in list:
			var c: Array = buildings.get_building(id)["anchor"]
			anchors[id] = Vector2i(int(c[0]), int(c[1]))
		var zigzag := route == "zigzag"
		list.sort_custom(func(a: int, b: int) -> bool:
			var pa: Vector2i = anchors[a]
			var pb: Vector2i = anchors[b]
			if pa.y != pb.y:
				return pa.y < pb.y
			if zigzag and pa.y % 2 != 0:
				return pa.x > pb.x
			return pa.x < pb.x)
		var at := int(momos.get_momo(momo).get("assigned", 0))
		var i := list.find(at)
		if i >= 0:
			list = list.slice(i + 1) + list.slice(0, i + 1)
		return list
	var here := momos.position_of(momo)
	var dist := {}
	for id: int in list:
		dist[id] = here.distance_to(momos.work_spot(id))
	list.sort_custom(func(a: int, b: int) -> bool:
		var da: float = dist[a]
		var db: float = dist[b]
		return da < db - 0.0001 or (absf(da - db) <= 0.0001 and a < b))
	return _neglected_first(list)


## Nearest first, but never forever (Step 50): a watched building that has
## stood ready for `balance.momo.starve_seconds` while nearer ones kept the
## Momo busy goes first, longest-waiting first. With five-second farms always
## ready next door, the lab beside them was never studied.
func _neglected_first(list: Array[int]) -> Array[int]:
	var limit := int(sim.data.get_float("balance", "momo.starve_seconds", 0.0) * 1000.0)
	if limit <= 0:
		return list
	var buildings: BuildingSystem = sim.system(&"buildings")
	var now := sim.now_ms()
	var waiting: Array[int] = []
	var since := {}
	for id: int in list:
		var b := buildings.get_building(id)
		if b.is_empty() or b["state"] != BuildingSystem.IDLE:
			continue
		var ready := maxi(maxi(int(b.get("task_end", 0)), int(b.get("ready_at", 0))), int(b.get("build_end", 0)))
		if now - ready >= limit and buildings.can_start(id)["ok"]:
			waiting.append(id)
			since[id] = ready
	if waiting.is_empty():
		return list
	waiting.sort_custom(func(a: int, b: int) -> bool: return int(since[a]) < int(since[b]) or (int(since[a]) == int(since[b]) and a < b))
	var out: Array[int] = waiting.duplicate()
	for id: int in list:
		if not waiting.has(id):
			out.append(id)
	return out


## Which Momo a building belongs to when several watch it (the zone route):
## the watcher whose own tiles are centred nearest to it (ties: lower id).
func zone_owner(building: int) -> int:
	var momos: MomoSystem = sim.system(&"momo")
	var watchers := momos.watchers_of(building)
	if watchers.size() <= 1:
		return watchers[0] if not watchers.is_empty() else 0
	var spot := momos.work_spot(building)
	var best := 0
	var best_d := INF
	for w: int in watchers:
		var cells := momos.watched(w)
		var home := Vector2.ZERO
		for c: Vector2i in cells:
			home += Vector2(c) + Vector2(0.5, 0.5)
		home /= maxf(cells.size(), 1.0)
		var d := home.distance_to(spot)
		if d < best_d - 0.0001:
			best = w
			best_d = d
	return best


## The smart route: every watched building with a Momo job and room, ready
## now or cooling down; the one where work could start soonest -- the longer
## of the walk and the wait -- wins (ties: nearer, then lower id). Waiting is
## done there, so the stage starts the moment the building is free.
func _dispatch_auto(momo: int, skip: int) -> int:
	var momos: MomoSystem = sim.system(&"momo")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var here := momos.position_of(momo)
	var at := int(momos.get_momo(momo)["assigned"])
	var speed := momos.walk_speed()
	var now := sim.now_ms()
	var best := 0
	var best_eta := INF
	var best_d := INF
	for id: int in _watched_buildings(momo):
		if id == skip or not _job_for_momo(id):
			continue
		var others := momos.workers_at(id)
		others.erase(momo)
		if others.size() >= momos.slots_of(id):
			continue
		var b := buildings.get_building(id)
		var wait := 0.0
		if b["state"] == BuildingSystem.COOLDOWN:
			wait = maxf(float(int(b.get("ready_at", now)) - now), 0.0)
		elif not buildings.can_start(id)["ok"]:
			continue
		var d := here.distance_to(momos.work_spot(id))
		var eta := maxf(d / speed * 1000.0, wait)
		if eta < best_eta - 0.5 or (absf(eta - best_eta) <= 0.5 and d < best_d - 0.0001):
			best = id
			best_eta = eta
			best_d = d
	if best == 0:
		return 0
	if best == at:
		if momos.at_work(momo) and buildings.can_start(at)["ok"]:
			try_start(at)
		return at
	if momos.assign(momo, best, false, true)["ok"]:
		return best
	return 0


## Watched buildings of free Momo nearest first: one of them comes over.
func _call_watchers(building: int) -> void:
	if resting() or not _job_for_momo(building):
		return
	var momos: MomoSystem = sim.system(&"momo")
	var spot := momos.work_spot(building)
	var free: Array[int] = []
	for id: int in momos.watchers_of(building):
		if not is_working(id) and int(momos.get_momo(id)["assigned"]) != building:
			free.append(id)
	var dist := {}
	for id: int in free:
		dist[id] = momos.position_of(id).distance_to(spot)
	free.sort_custom(func(a: int, b: int) -> bool:
		var da: float = dist[a]
		var db: float = dist[b]
		return da < db - 0.0001 or (absf(da - db) <= 0.0001 and a < b))
	var owner := zone_owner(building)
	for id: int in free:
		# The zone route: only the building's own Momo comes. A Momo on the
		# player's order never turns aside for a building coming free.
		if (momos.route_of(id) == "zone" and owner != id) or momos.route_of(id) == "order":
			continue
		# Only a Momo with nothing to start where it stands walks over.
		var at := int(momos.get_momo(id)["assigned"])
		if at != 0 and momos.at_work(id) and _open_for(id, at):
			continue
		if _open_for(id, building) and momos.assign(id, building, false, true)["ok"]:
			return


## The buildings on the tiles `momo` watches (MomoMood reads it too).
func watched_buildings(momo: int) -> Array[int]:
	return _watched_buildings(momo)


## Whether `momo` would go to `building` now (MomoMood reads it too).
func open_for(momo: int, building: int) -> bool:
	return _open_for(momo, building)


func _watched_buildings(momo: int) -> Array[int]:
	var momos: MomoSystem = sim.system(&"momo")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var out: Array[int] = []
	for c: Vector2i in momos.watched(momo):
		var id := buildings.building_at(c)
		if id != 0 and not out.has(id):
			out.append(id)
	out.sort()
	return out


## A stage a Momo (not a drip line) would do now.
func _job_for_momo(building: int) -> bool:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var b := buildings.get_building(building)
	if b.is_empty():
		return false
	var research: ResearchSystem = sim.system(&"research")
	var action := String(buildings.current_stage(b).get("action", ""))
	return research == null or not research.is_auto(String(b["type"]), action)


## Whether `momo` should go to `building` now: a Momo job that could start,
## and a free place for it there.
func _open_for(momo: int, building: int) -> bool:
	var momos: MomoSystem = sim.system(&"momo")
	if not _job_for_momo(building) or not (sim.system(&"buildings") as BuildingSystem).can_start(building)["ok"]:
		return false
	var others := momos.workers_at(building)
	others.erase(momo)
	return others.size() < momos.slots_of(building)


func try_start(building: int) -> Dictionary:
	if building == 0:
		return SimResult.fail("err.no_building")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var b := buildings.get_building(building)
	if b.is_empty() or b["state"] != BuildingSystem.IDLE:
		return SimResult.fail("err.busy")
	# A stage researched to run by itself (a drip line watering) starts at
	# once, at its normal time, day or night, Momo or not.
	var research: ResearchSystem = sim.system(&"research")
	var action := String(buildings.current_stage(b).get("action", ""))
	if research != null and research.is_auto(String(b["type"]), action):
		return buildings.start_stage(building, AUTO_WORKER, 1.0)
	if resting():
		return SimResult.fail("err.resting")
	var worker := next_worker(building)
	if worker == 0:
		return SimResult.fail("err.no_worker")
	var mult := (sim.system(&"momo") as MomoSystem).work_multiplier(worker, String(b["type"]))
	return buildings.start_stage(building, worker, mult)


func save_state() -> Dictionary:
	var out := {}
	for id: int in last_worked:
		out[str(id)] = int(last_worked[id])
	return {"last_worked": out}


func load_state(state: Dictionary) -> void:
	last_worked.clear()
	var lw: Dictionary = state.get("last_worked", {})
	for k: String in lw:
		last_worked[int(k)] = int(lw[k])
