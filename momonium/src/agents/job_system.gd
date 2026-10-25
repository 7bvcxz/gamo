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
			try_start(int(payload["id"]))
		&"momo_arrived", &"momo_assigned":
			try_start(int(payload.get("building", 0)))
		&"task_completed":
			var worker := int(payload.get("worker", 0))
			if worker > 0:
				last_worked[worker] = sim.now_ms()
		&"sold", &"research_completed", &"recipe_changed":
			_try_all()
		&"inventory_changed":
			# Inputs arriving can unblock a waiting furnace.
			if int(payload.get("delta", 0)) > 0:
				_try_waiting()


func on_day_started(_day: int) -> void:
	_try_all()


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
	var mult := sim.data.get_float("balance", "momo.work_time_multiplier", 4.0)
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
