class_name GoalSystem
extends SimSystem

## Step 72: the one distant thing the player is slowly working toward.
##
## There is always exactly one goal. While this island is not yet a Nation it
## is the island's next tier -- City, then Nation, TierSystem's milestones and
## its promotion. After that come the civilization milestones of
## balance.goals.ladder, in order: a Golden Age, then a whole Civilization.
## Each is measured from the game itself -- the island's tier and Momo, the
## disciplines whose eighth research tier was ever researched, the islands
## sold -- never from a currency kept for the purpose.
##
## A milestone met is reached for good: recorded in `reached`, kept across
## Prestige (like the research discovered), announced once (goal_reached),
## and the next one takes its place. A tier reached is recorded too, the
## first time, for the ladder. Reaching changes no rule of the island: it
## takes nothing away and never stands in the way of work.

## id -> {"day": the day it was reached, "island": which island (1, 2, ...)}.
var reached: Dictionary = {}


func _init() -> void:
	key = &"goals"


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
		if type == &"tier_promoted":
			_reach(String(p.get("name", "")))
		if type in [&"tier_promoted", &"research_completed", &"momo_hired", &"game_loaded", &"settlement_sold"]:
			check())


func on_new_game() -> void:
	reached.clear()


func on_day_started(_day: int) -> void:
	check()


## The civilization milestones after the Nation, in order: [{id, needs}].
func ladder() -> Array:
	return sim.data.get_value("balance", "goals.ladder", [])


## The goal now: {id, kind, progress}. kind is "tier" (this island's next
## tier: progress and promotion are TierSystem's), "civ" (a milestone of the
## ladder) or "done" (every milestone reached; id is the last one).
func current() -> Dictionary:
	var tiers: TierSystem = sim.system(&"tiers")
	if not tiers.is_top():
		return {"id": tiers.tier_name(tiers.tier + 1), "kind": "tier", "progress": tiers.progress()}
	var last := ""
	for g: Dictionary in ladder():
		var id := String(g["id"])
		if not reached.has(id):
			return {"id": id, "kind": "civ", "progress": progress_of(g)}
		last = id
	return {"id": last, "kind": "done", "progress": [] as Array[Dictionary]}


## Where the island stands on each need of a milestone: [{key, have, need, met}].
func progress_of(g: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var needs: Dictionary = g.get("needs", {})
	for k: String in ["tier", "momos", "eighth_tiers", "islands_sold"]:
		if not needs.has(k):
			continue
		var have := measure(k)
		out.append({"key": k, "have": have, "need": int(needs[k]), "met": have >= int(needs[k])})
	return out


func measure(k: String) -> int:
	match k:
		"tier":
			return (sim.system(&"tiers") as TierSystem).tier
		"momos":
			return (sim.system(&"momo") as MomoSystem).ids().size()
		"eighth_tiers":
			return eighth_tiers()
		"islands_sold":
			return (sim.system(&"prestige") as PrestigeSystem).sales
	return 0


## Disciplines whose eighth research tier (or deeper) has ever been researched
## -- on any island: a researched node stays researched across Prestige.
func eighth_tiers() -> int:
	var rs: ResearchSystem = sim.system(&"research")
	var n := 0
	for ind: String in rs.industries():
		for node: Dictionary in rs.nodes(ind):
			if rs.tier_of(String(node["id"])) >= 8 and rs.is_unlocked_node(String(node["id"])):
				n += 1
				break
	return n


## Reaches every milestone of the ladder that is met now, in order -- one at a
## time, so the same moment never skips a goal unannounced.
func check() -> void:
	while true:
		var cur := current()
		if String(cur["kind"]) != "civ":
			return
		for p: Dictionary in cur["progress"]:
			if not bool(p["met"]):
				return
		_reach(String(cur["id"]))
		sim.bus.emit(&"goal_reached", {"id": String(cur["id"])})


func _reach(id: String) -> void:
	if id == "" or reached.has(id):
		return
	var prestige: PrestigeSystem = sim.system(&"prestige")
	reached[id] = {"day": sim.clock.day_number(), "island": (prestige.sales if prestige != null else 0) + 1}


## The ladder to draw, Village to Civilization: [{id, state}] with state
## "done", "current" or "ahead". The tiers are this island's; the
## civilization milestones are for good.
func steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tiers: TierSystem = sim.system(&"tiers")
	var cur := current()
	for t in TierSystem.NAMES.size():
		var name := tiers.tier_name(t)
		var state := "done" if tiers.tier >= t else ("current" if String(cur["id"]) == name else "ahead")
		out.append({"id": name, "state": state})
	for g: Dictionary in ladder():
		var id := String(g["id"])
		var state := "done" if reached.has(id) else ("current" if String(cur["id"]) == id and String(cur["kind"]) == "civ" else "ahead")
		out.append({"id": id, "state": state})
	return out


## Prestige: what was reached stays reached on the next island.
func carry_over() -> Dictionary:
	return reached.duplicate(true)


func adopt(carry: Dictionary) -> void:
	for id: String in carry:
		reached[id] = (carry[id] as Dictionary).duplicate()


func save_state() -> Dictionary:
	return {"reached": reached.duplicate(true)}


func load_state(state: Dictionary) -> void:
	reached.clear()
	var r: Dictionary = state.get("reached", {})
	for id: String in r:
		reached[id] = (r[id] as Dictionary).duplicate() if typeof(r[id]) == TYPE_DICTIONARY else {}
	# A save from before Step 72 knows only its tier: the tiers it reached count.
	var tiers: TierSystem = sim.system(&"tiers")
	if tiers != null:
		for t in range(1, tiers.tier + 1):
			if not reached.has(tiers.tier_name(t)):
				reached[tiers.tier_name(t)] = {"day": 0, "island": 0}
