class_name JobSystem
extends SimSystem

## Assigned Momo work their building by themselves.
##
## Event-driven, never polled: a building becoming idle (a stage done, a
## cooldown over, construction finished), a Momo arriving at its building, a
## new morning, or room appearing in the store (a sale) each make this look at
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
## The calculation lives here; the views only look at who is working where.

## momo id -> ms it last finished a stage (fair rotation; not needing saving
## beyond a session, but saved so a load does not reshuffle turns).
var last_worked: Dictionary = {}

## The `worker` recorded for a stage that ran by itself (irrigation).
const AUTO_WORKER := -1


func _init() -> void:
	key = &"jobs"


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


func on_new_game() -> void:
	last_worked.clear()


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
			if not try_start(int(payload.get("building", 0)))["ok"]:
				dispatch(int(payload.get("id", 0)), int(payload.get("building", 0)))
		&"momo_assigned":
			try_start(int(payload.get("building", 0)))
		&"momo_watch_changed":
			dispatch(int(payload.get("id", 0)))
		&"task_completed":
			var worker := int(payload.get("worker", 0))
			if worker > 0:
				last_worked[worker] = sim.now_ms()
				# A wait follows: meanwhile it may work elsewhere on its rounds.
				# (No wait: building_idle comes next and starts it again here.)
				var b := (sim.system(&"buildings") as BuildingSystem).get_building(int(payload.get("id", 0)))
				if not b.is_empty() and b["state"] == BuildingSystem.COOLDOWN:
					dispatch(worker, int(payload.get("id", 0)))
		&"sold", &"research_completed", &"recipe_changed":
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
	for id: int in buildings.ids():
		var b := buildings.get_building(id)
		if b["state"] == BuildingSystem.IDLE and not (buildings.current_stage(b).get("consumes", {}) as Dictionary).is_empty():
			try_start(id)


func _try_all() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	for id: int in buildings.ids():
		try_start(id)


func resting() -> bool:
	if sim.data.get_value("balance", "momo.works_at_night", false):
		return false
	return DayCycle.new(sim.data).is_night(sim.clock)


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


## A free Momo picks its next job among the buildings it watches: the
## nearest that could start now and has room for it (ties: lower id). Its own
## building, when it qualifies, is simply started; `skip` (just tried) is not
## walked back to. Returns the building it went to, or 0.
func dispatch(momo: int, skip: int = 0) -> int:
	var momos: MomoSystem = sim.system(&"momo")
	var m := momos.get_momo(momo)
	if m.is_empty() or (m.get("watch", []) as Array).is_empty() or resting() or is_working(momo):
		return 0
	var buildings: BuildingSystem = sim.system(&"buildings")
	var here := momos.position_of(momo)
	var at := int(m["assigned"])
	var best := 0
	var best_d := INF
	for id: int in _watched_buildings(momo):
		if id == skip or not _open_for(momo, id):
			continue
		if id == at:
			# Its own building (or the one it is walking to) is ready.
			if momos.at_work(momo):
				try_start(id)
			return id
		var d := here.distance_to(momos.work_spot(id))
		if d < best_d - 0.0001:
			best = id
			best_d = d
	if best != 0 and momos.assign(momo, best, false, true)["ok"]:
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
	free.sort_custom(func(a: int, b: int) -> bool:
		var da := momos.position_of(a).distance_to(spot)
		var db := momos.position_of(b).distance_to(spot)
		return da < db - 0.0001 or (absf(da - db) <= 0.0001 and a < b))
	for id: int in free:
		# Only a Momo with nothing to start where it stands walks over.
		var at := int(momos.get_momo(id)["assigned"])
		if at != 0 and momos.at_work(id) and _open_for(id, at):
			continue
		if _open_for(id, building) and momos.assign(id, building, false, true)["ok"]:
			return


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
