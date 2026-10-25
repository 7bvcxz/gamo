class_name ResearchSystem
extends SimSystem

## The technology tree as simulation state (data/research.json).
##
## A node is locked until its prerequisites are finished and its unlock
## conditions hold (player level, building mastery, an accepted Momo
## proposal). Starting one pays its cost and needs a finished research lab;
## it then completes on its own after its duration (a scheduled event, so it
## carries on offline and across saves). One research runs at a time.
##
## Finished research changes the world only through effects in the data, which
## this system applies as a modifier source of the building system (stage work
## and wait multipliers, yield bonuses) and to research durations. The UI reads
## the same effects to describe them -- nothing is worked out twice.

const DONE := "research.done"
const LAB := "research"

## id -> ms it finished.
var completed: Dictionary = {}
## The running research: {id, start, end, token}, or empty.
var active: Dictionary = {}
var token := 0


func _init() -> void:
	key = &"research"


func handled_events() -> PackedStringArray:
	return PackedStringArray([DONE])


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["research.start"])


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	var buildings: BuildingSystem = p_sim.system(&"buildings")
	if buildings != null and not buildings.modifiers.has(self):
		buildings.modifiers.append(self)


func on_new_game() -> void:
	completed.clear()
	active = {}
	token = 0


# --- the tree -----------------------------------------------------------------

func nodes(industry: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Dictionary in sim.data.table("research").get("nodes", []):
		if industry == "" or String(n.get("industry", "")) == industry:
			out.append(n)
	return out


func node(id: String) -> Dictionary:
	for n: Dictionary in nodes():
		if String(n["id"]) == id:
			return n
	return {}


## Industries with research, in data order ("global" last).
func industries() -> Array[String]:
	var out: Array[String] = []
	for n: Dictionary in nodes():
		var ind := String(n.get("industry", ""))
		if ind != "global" and not out.has(ind):
			out.append(ind)
	if nodes("global").size() > 0:
		out.append("global")
	return out


func is_done(id: String) -> bool:
	return completed.has(id)


## What still stands between the player and this node, as data the UI can
## show: [{kind: requires, id} | {kind: level, need, have} |
## {kind: mastery, type, need, have} | {kind: proposal}].
func missing(id: String) -> Array[Dictionary]:
	var n := node(id)
	var out: Array[Dictionary] = []
	for r: String in n.get("requires", []):
		if not is_done(r):
			out.append({"kind": "requires", "id": r})
	var unlock: Dictionary = n.get("unlock", {})
	var prog: ProgressionSystem = sim.system(&"progression")
	if unlock.has("level") and prog.level < int(unlock["level"]):
		out.append({"kind": "level", "need": int(unlock["level"]), "have": prog.level})
	for t: String in unlock.get("mastery", {}):
		var have := int(prog.mastery_of(t)["level"])
		if have < int(unlock["mastery"][t]):
			out.append({"kind": "mastery", "type": t, "need": int(unlock["mastery"][t]), "have": have})
	if bool(unlock.get("proposal", false)):
		var mail: MailSystem = sim.system(&"mail")
		if mail == null or not mail.accepted_research().has(id):
			out.append({"kind": "proposal"})
	return out


## done | active | available | locked
func state_of(id: String) -> String:
	if is_done(id):
		return "done"
	if String(active.get("id", "")) == id:
		return "active"
	return "available" if missing(id).is_empty() else "locked"


func has_lab() -> bool:
	var buildings: BuildingSystem = sim.system(&"buildings")
	for bid: int in buildings.ids():
		var b := buildings.get_building(bid)
		if String(b["type"]) == LAB and b["state"] != BuildingSystem.CONSTRUCTING:
			return true
	return false


func duration_ms(id: String) -> int:
	var m := 1.0
	for e: Dictionary in _effects("research_time"):
		m *= float(e.get("multiply", 1.0))
	return int(round(float(node(id).get("seconds", 60)) * m * 1000.0))


func cost_of(id: String) -> Dictionary:
	var c: Dictionary = node(id).get("cost", {})
	return {"money": int(c.get("money", 0)), "items": c.get("items", {})}


## Whether `id` can start now, as a command result: the first reason it cannot.
func can_start(id: String) -> Dictionary:
	if node(id).is_empty():
		return SimResult.fail("err.no_research")
	match state_of(id):
		"done":
			return SimResult.fail("err.research_done")
		"active":
			return SimResult.fail("err.research_busy")
		"locked":
			return SimResult.fail("err.research_locked")
	if not active.is_empty():
		return SimResult.fail("err.research_busy")
	if not has_lab():
		return SimResult.fail("err.no_lab")
	var cost := cost_of(id)
	if not (sim.system(&"economy") as EconomySystem).can_afford(cost["money"]):
		return SimResult.fail("err.not_enough_money")
	if not (sim.system(&"inventory") as InventorySystem).has_all(cost["items"]):
		return SimResult.fail("err.not_enough_items")
	return SimResult.ok()


func execute(command: Dictionary) -> Dictionary:
	var id := String(command.get("id", ""))
	var check := can_start(id)
	if not check["ok"]:
		return check
	var cost := cost_of(id)
	if cost["money"] > 0:
		(sim.system(&"economy") as EconomySystem).spend(cost["money"], "research:" + id)
	(sim.system(&"inventory") as InventorySystem).take_all(cost["items"], "research:" + id)
	token += 1
	var start := sim.now_ms()
	active = {"id": id, "start": start, "end": start + duration_ms(id), "token": token}
	sim.scheduler.schedule(int(active["end"]), DONE, {"id": id, "token": token})
	sim.bus.emit(&"research_started", {"id": id, "ends_ms": active["end"]})
	return SimResult.ok({"ends_ms": active["end"]})


func handle_event(type: String, data: Dictionary) -> void:
	if type != DONE or active.is_empty() or int(data.get("token", -1)) != int(active["token"]):
		return
	var id := String(active["id"])
	completed[id] = sim.now_ms()
	active = {}
	sim.bus.emit(&"research_completed", {"id": id})


func progress() -> float:
	if active.is_empty():
		return 0.0
	var span := maxf(float(int(active["end"]) - int(active["start"])), 1.0)
	return clampf((sim.now_ms() - int(active["start"])) / span, 0.0, 1.0)


func remaining_ms() -> int:
	return 0 if active.is_empty() else maxi(int(active["end"]) - sim.now_ms(), 0)


## Something the player could start right now (the HUD's red dot).
func something_to_start() -> bool:
	if not active.is_empty():
		return false
	for n: Dictionary in nodes():
		if can_start(String(n["id"]))["ok"]:
			return true
	return false


# --- effects --------------------------------------------------------------------

func _effects(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in completed:
		for e: Dictionary in node(id).get("effects", []):
			if String(e.get("kind", "")) == kind:
				out.append(e)
	return out


## BuildingSystem modifier: multiplier on a stage's work time or the wait after it.
func stage_multiplier(kind: String, type: String, action: String) -> float:
	var m := 1.0
	for e: Dictionary in _effects(kind):
		if String(e.get("type", "")) == type and (not e.has("action") or String(e["action"]) == action):
			m *= float(e.get("multiply", 1.0))
	return m


## BuildingSystem modifier: whether research has opened this crop variety.
func unlocks_variety(type: String, variety: String) -> bool:
	for e: Dictionary in _effects("variety"):
		if String(e.get("type", "")) == type and String(e.get("variety", "")) == variety:
			return true
	return false


## Momo work time at a kind of building from research (training, tools):
## the product of every momo_work effect for that type or for all types.
func momo_multiplier(type: String) -> float:
	var m := 1.0
	for e: Dictionary in _effects("momo_work"):
		if not e.has("type") or String(e["type"]) == type:
			m *= float(e.get("multiply", 1.0))
	return m


## What the daily sale pays, times market research (>= 1).
func sale_multiplier() -> float:
	var m := 1.0
	for e: Dictionary in _effects("sale_price"):
		m *= float(e.get("multiply", 1.0))
	return m


## How many more tiles each Momo may watch, from research.
func watch_bonus() -> int:
	var n := 0
	for e: Dictionary in _effects("watch_tiles"):
		n += int(e.get("add", 0))
	return n


## How much faster Momo walk, from transport research (>= 1).
func walk_multiplier() -> float:
	var m := 1.0
	for e: Dictionary in _effects("walk_speed"):
		m *= float(e.get("multiply", 1.0))
	return m


## BuildingSystem modifier: whether research has opened this recipe.
func unlocks_recipe(type: String, recipe: String) -> bool:
	for e: Dictionary in _effects("recipe"):
		if String(e.get("type", "")) == type and String(e.get("recipe", "")) == recipe:
			return true
	return false


## BuildingSystem modifier: extra batches one charge holds.
func batch_bonus(type: String) -> int:
	var n := 0
	for e: Dictionary in _effects("batch"):
		if String(e.get("type", "")) == type:
			n += int(e.get("add", 0))
	return n


## Whether stages with this action run by themselves (a drip line waters).
func is_auto(type: String, action: String) -> bool:
	for e: Dictionary in _effects("auto"):
		if String(e.get("type", "")) == type and String(e.get("action", "")) == action:
			return true
	return false


## BuildingSystem modifier: extra items a stage yields (a rate; may be a fraction).
func yield_bonus(type: String, stage_id: String, item: String) -> float:
	var n := 0.0
	for e: Dictionary in _effects("yield"):
		if String(e.get("type", "")) == type and String(e.get("stage", "")) == stage_id and String(e.get("item", "")) == item:
			n += float(e.get("add", 0))
	return n


## BuildingSystem modifier: items research makes a stage yield at all.
func yield_items(type: String, stage_id: String) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in _effects("yield"):
		if String(e.get("type", "")) == type and String(e.get("stage", "")) == stage_id and not out.has(String(e.get("item", ""))):
			out.append(String(e.get("item", "")))
	return out


func save_state() -> Dictionary:
	return {"completed": completed.duplicate(), "active": active.duplicate(), "token": token}


func load_state(state: Dictionary) -> void:
	on_new_game()
	var done: Dictionary = state.get("completed", {})
	for k: String in done:
		completed[k] = int(done[k])
	var a: Dictionary = state.get("active", {})
	if not a.is_empty():
		active = {"id": String(a["id"]), "start": int(a["start"]), "end": int(a["end"]), "token": int(a["token"])}
	token = int(state.get("token", 0))
