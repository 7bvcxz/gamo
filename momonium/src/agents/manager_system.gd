class_name ManagerSystem
extends SimSystem

## A Momo at an office manages the island's workforce.
##
## Every `review_seconds` (a scheduled event, not polling), if some office has
## its Momo at work, it looks once at the buildings and moves at most
## `moves_per_review` workers -- deterministically, in priority and id order:
##   from: a building set to "off", or idle and blocked (nothing to work
##         with, or nowhere to put what it makes) for `stuck_seconds`;
##   to:   the first building by priority (high, normal, low) with a free
##         spot and its next stage ready to start (not blocked, not cooling).
## Free Momo are left to play, except to fill a high-priority spot. A Momo the
## player placed (pinned) is never moved; neither is the manager. A move is an
## ordinary assignment: the Momo walks there -- nothing happens at once.
## Step 53: only a Momo the player has ever placed or let go to the manager
## (`opted_in`) is the manager's to move -- a new hire is never given its
## first work by anyone but the player.

const REVIEW := "manager.review"
const PRIORITIES: PackedStringArray = ["high", "normal", "low", "off"]

## building id -> ms since it has been idle and blocked (for "stuck").
var stuck_since: Dictionary = {}
var moves_made := 0


func _init() -> void:
	key = &"manager"


func handled_events() -> PackedStringArray:
	return PackedStringArray([REVIEW])


func on_new_game() -> void:
	stuck_since.clear()
	moves_made = 0
	_schedule()


func _schedule() -> void:
	sim.schedule_in(int(sim.data.get_float("balance", "manager.review_seconds", 20.0) * 1000.0), REVIEW)


func handle_event(type: String, _data: Dictionary) -> void:
	if type != REVIEW:
		return
	_schedule()
	if manager() != 0:
		review()


## The Momo managing now (at work in an office), or 0.
func manager() -> int:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	for id: int in buildings.ids():
		var b := buildings.get_building(id)
		if bool(buildings.type_def(b).get("manages", false)) and b["state"] != BuildingSystem.CONSTRUCTING:
			for m: int in momos.workers_at(id):
				if momos.at_work(m):
					return m
	return 0


static func rank(priority: String) -> int:
	var i := PRIORITIES.find(priority)
	return i if i >= 0 else 1


## One review: returns the moves made as [[momo, from, to], ...].
func review() -> Array:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var now := sim.now_ms()
	var stuck_ms := int(sim.data.get_float("balance", "manager.stuck_seconds", 40.0) * 1000.0)
	var boss := manager()
	# Track how long each building has been idle and blocked.
	for id: int in buildings.ids():
		var b := buildings.get_building(id)
		if b["state"] == BuildingSystem.IDLE and not buildings.blocked(b).is_empty():
			if not stuck_since.has(id):
				stuck_since[id] = now
		else:
			stuck_since.erase(id)
	# Who could be moved: unpinned workers at stuck or switched-off buildings.
	var movable: Array[int] = []
	for m: int in momos.ids():
		var rec := momos.get_momo(m)
		var at := int(rec["assigned"])
		if at == 0 or m == boss or bool(rec.get("pinned", false)) or not bool(rec.get("opted_in", false)):
			continue
		var b := buildings.get_building(at)
		var off := String(b.get("priority", "normal")) == "off"
		var stuck := stuck_since.has(at) and now - int(stuck_since[at]) >= stuck_ms
		if off or stuck:
			movable.append(m)
	# Free Momo only for high-priority spots.
	var free: Array[int] = []
	for m: int in momos.ids():
		var rec := momos.get_momo(m)
		if int(rec["assigned"]) == 0 and not momos.is_moving(m) and bool(rec.get("opted_in", false)):
			free.append(m)
	var moves: Array = []
	var limit := sim.data.get_int("balance", "manager.moves_per_review", 2)
	for opening: int in openings():
		if moves.size() >= limit:
			break
		var b := buildings.get_building(opening)
		var pick := 0
		for m: int in movable:
			if int(momos.get_momo(m)["assigned"]) != opening:
				pick = m
				break
		if pick == 0 and String(b.get("priority", "normal")) == "high" and not free.is_empty():
			pick = free[0]
		if pick == 0:
			continue
		var from := int(momos.get_momo(pick)["assigned"])
		if momos.assign(pick, opening, false)["ok"]:
			movable.erase(pick)
			free.erase(pick)
			moves.append([pick, from, opening])
			moves_made += 1
			sim.bus.emit(&"manager_moved", {"momo": pick, "from": from, "to": opening})
	return moves


## Buildings with a free worker spot and their next stage ready to start,
## highest priority first, then by id.
func openings() -> Array[int]:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var out: Array[int] = []
	for id: int in buildings.ids():
		var b := buildings.get_building(id)
		if b["state"] == BuildingSystem.CONSTRUCTING or String(b.get("priority", "normal")) == "off":
			continue
		if bool(buildings.type_def(b).get("manages", false)):
			continue
		if momos.workers_at(id).size() >= momos.slots_of(id):
			continue
		if buildings.stages(b).is_empty() or not buildings.blocked(b).is_empty() and b["state"] == BuildingSystem.IDLE:
			continue
		out.append(id)
	out.sort_custom(func(a: int, c: int) -> bool:
		var ra := rank(String(buildings.get_building(a).get("priority", "normal")))
		var rc := rank(String(buildings.get_building(c).get("priority", "normal")))
		return ra < rc or (ra == rc and a < c))
	return out


func save_state() -> Dictionary:
	var out := {}
	for id: int in stuck_since:
		out[str(id)] = int(stuck_since[id])
	return {"stuck_since": out, "moves_made": moves_made}


func load_state(state: Dictionary) -> void:
	stuck_since.clear()
	var s: Dictionary = state.get("stuck_since", {})
	for k: String in s:
		stuck_since[int(k)] = int(s[k])
	moves_made = int(state.get("moves_made", 0))
	if sim.scheduler.events_of(REVIEW).is_empty():
		_schedule()
