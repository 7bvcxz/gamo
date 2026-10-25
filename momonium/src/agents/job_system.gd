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
			if worker != 0:
				last_worked[worker] = sim.now_ms()
		&"sold":
			_try_all()


func on_day_started(_day: int) -> void:
	_try_all()


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
	if building == 0 or resting():
		return SimResult.fail("err.resting")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var b := buildings.get_building(building)
	if b.is_empty() or b["state"] != BuildingSystem.IDLE:
		return SimResult.fail("err.busy")
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
