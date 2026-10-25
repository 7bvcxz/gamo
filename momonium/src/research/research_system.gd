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
##
## Levels: a node can be researched again, up to max_level, each level costing
## and taking more and strengthening its effects (balance.research). A node's
## level is the levels researched this run (`bought`) plus the levels placed on
## it from research points (`allocated`). Once researched, a node stays
## `unlocked` for good. At Prestige the levels bought in that run become RP --
## a permanent ledger, `rp_earned` -- and every level goes back to 0, to be
## allocated again (allocate_all). Allocating moves points around; only
## research actually done adds to the ledger, so no loop mints RP.

const DONE := "research.done"
const LAB := "research"

## id -> ms it became active (level 1 or more) this run.
var completed: Dictionary = {}
## id -> levels researched this run (paid for with money and time).
var bought: Dictionary = {}
## id -> levels placed on it from research points.
var allocated: Dictionary = {}
## id -> true: researched at least once, in any run. Never reset.
var unlocked: Dictionary = {}
## Research points ever issued (one per level researched, at each Prestige).
var rp_earned := 0
## Saved allocation plans: PROFILES slots of {id: levels} (or empty), kept
## for good like the points themselves.
var profiles: Array = []
const PROFILES := 3
## The running research: {id, start, end, token}, or empty.
var active: Dictionary = {}
var token := 0


func _init() -> void:
	key = &"research"


func handled_events() -> PackedStringArray:
	return PackedStringArray([DONE])


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["research.start", "research.allocate", "research.profile_save"])


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	var buildings: BuildingSystem = p_sim.system(&"buildings")
	if buildings != null and not buildings.modifiers.has(self):
		buildings.modifiers.append(self)


func on_new_game() -> void:
	completed.clear()
	bought.clear()
	allocated.clear()
	unlocked.clear()
	rp_earned = 0
	profiles = []
	for i in PROFILES:
		profiles.append({})
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


# --- levels ---------------------------------------------------------------------

## The highest level a node can reach: 1 for switches, else balance.research.max_level.
func max_level(id: String) -> int:
	var n := node(id)
	if n.has("max_level"):
		return maxi(int(n["max_level"]), 1)
	# Nothing to grow (a node that opens a building) or a switch: one level.
	if (n.get("effects", []) as Array).is_empty():
		return 1
	for e: Dictionary in n.get("effects", []):
		if String(e.get("kind", "")) in ["auto", "recipe", "variety", "power_use", "route"]:
			return 1
	return sim.data.get_int("balance", "research.max_level", 5)


## A node's level now: researched this run plus allocated (a node marked done
## without either -- an old save, a test -- counts as level 1).
func level(id: String) -> int:
	var l := int(bought.get(id, 0)) + int(allocated.get(id, 0))
	if l == 0 and completed.has(id):
		l = 1
	return mini(l, max_level(id))


func is_unlocked_node(id: String) -> bool:
	return unlocked.has(id) or completed.has(id)


func rp_allocated() -> int:
	var n := 0
	for id: String in allocated:
		n += int(allocated[id])
	return n


func rp_unspent() -> int:
	return rp_earned - rp_allocated()


## Levels researched this run: what the next Prestige turns into RP.
func rp_pending() -> int:
	var n := 0
	for id: String in bought:
		n += int(bought[id])
	return n


## Whether a whole allocation {id: levels} is allowed: unlocked nodes, 0..what
## each can still take, every allocated node's prerequisites active, within the
## points earned. The first reason it is not, or ok.
func check_allocation(plan: Dictionary) -> Dictionary:
	var total := 0
	for id: String in plan:
		var n := int(plan[id])
		if n == 0:
			continue
		if node(id).is_empty():
			return SimResult.fail("err.no_research", {"id": id})
		if not is_unlocked_node(id):
			return SimResult.fail("err.research_locked", {"id": id})
		if n < 0 or n + int(bought.get(id, 0)) > max_level(id):
			return SimResult.fail("err.research_max", {"id": id, "max": max_level(id)})
		total += n
	if total > rp_earned:
		return SimResult.fail("err.rp_short", {"need": total, "have": rp_earned})
	for id: String in plan:
		if int(plan[id]) <= 0:
			continue
		for r: String in node(id).get("requires", []):
			if int(plan.get(r, 0)) + int(bought.get(r, 0)) <= 0 and not (completed.has(r) and not allocated.has(r)):
				return SimResult.fail("err.research_needs", {"id": id, "requires": r})
	# Nodes researched this run that rest on allocated ones must keep them.
	for id: String in bought:
		for r: String in node(id).get("requires", []):
			if int(plan.get(r, 0)) + int(bought.get(r, 0)) <= 0 and allocated.has(r):
				return SimResult.fail("err.research_needed_by", {"id": r, "by": id})
	return SimResult.ok({"total": total})


## Replaces the whole allocation at once (the allocation screen's confirm).
func allocate_all(plan: Dictionary) -> Dictionary:
	var clean := {}
	for id: String in plan:
		if int(plan[id]) > 0:
			clean[id] = int(plan[id])
	var check := check_allocation(clean)
	if not check["ok"]:
		return check
	var was_active := {}
	for id: String in completed:
		was_active[id] = true
	var old := allocated
	allocated = clean
	# Active only through points that are no longer there: off again.
	for id: String in old:
		if int(bought.get(id, 0)) + int(allocated.get(id, 0)) <= 0:
			completed.erase(id)
	var now := sim.now_ms()
	for id: String in allocated:
		if not completed.has(id):
			completed[id] = now
	for id: String in completed:
		if not was_active.has(id):
			sim.bus.emit(&"research_completed", {"id": id, "level": level(id), "allocated": true})
	sim.bus.emit(&"research_allocated", {"allocated": allocated.duplicate(), "unspent": rp_unspent()})
	return SimResult.ok({"unspent": rp_unspent()})


## What still stands between the player and this node, as data the UI can
## show: [{kind: requires, id} | {kind: level, need, have} |
## {kind: mastery, type, need, have} | {kind: proposal}].
func missing(id: String) -> Array[Dictionary]:
	var n := node(id)
	var out: Array[Dictionary] = []
	for r: String in n.get("requires", []):
		if not is_done(r):
			out.append({"kind": "requires", "id": r})
	# Unlocked once, unlocked for good: the level, mastery or letter that
	# opened it is not asked for again (its prerequisites still are).
	if unlocked.has(id):
		return out
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


## done (top level) | levelup (researched, can go higher) | active |
## available | locked
func state_of(id: String) -> String:
	if String(active.get("id", "")) == id:
		return "active"
	if level(id) >= max_level(id):
		return "done"
	if level(id) >= 1:
		return "levelup"
	return "available" if missing(id).is_empty() else "locked"


func has_lab() -> bool:
	var buildings: BuildingSystem = sim.system(&"buildings")
	for bid: int in buildings.ids():
		var b := buildings.get_building(bid)
		if String(b["type"]) == LAB and b["state"] != BuildingSystem.CONSTRUCTING:
			return true
	return false


## How long the next level of `id` takes.
func duration_ms(id: String) -> int:
	var m := 1.0
	for e: Dictionary in _effects("research_time"):
		m *= float(e.get("multiply", 1.0))
	m *= pow(sim.data.get_float("balance", "research.level_time_growth", 1.5), level(id))
	return int(round(float(node(id).get("seconds", 60)) * m * 1000.0))


## What the next level of `id` costs: money grows faster than items, and no
## item is asked for in larger numbers than the store can hold.
func cost_of(id: String) -> Dictionary:
	var c: Dictionary = node(id).get("cost", {})
	var g := pow(sim.data.get_float("balance", "research.level_cost_growth", 1.8), level(id))
	var gi := pow(sim.data.get_float("balance", "research.level_item_growth", 1.3), level(id))
	var inv: InventorySystem = sim.system(&"inventory")
	var items := {}
	for item: String in c.get("items", {}):
		items[item] = mini(int(ceil(int(c["items"][item]) * gi)), inv.capacity(item) if inv != null else 999999)
	return {"money": int(ceil(int(c.get("money", 0)) * g)), "items": items}


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
	if String(command.get("type", "")) == "research.allocate":
		var plan: Variant = command.get("levels", {})
		return allocate_all(plan if typeof(plan) == TYPE_DICTIONARY else {})
	if String(command.get("type", "")) == "research.profile_save":
		var levels: Variant = command.get("levels", {})
		return save_profile(Cmd.integer(command, "slot"), levels if typeof(levels) == TYPE_DICTIONARY else {})
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
	if level(id) == 1 and int(bought.get(id, 0)) == 0 and not allocated.has(id):
		# An old "done" node researched again: that first level was bought too.
		bought[id] = 1
	bought[id] = int(bought.get(id, 0)) + 1
	unlocked[id] = true
	if not completed.has(id):
		completed[id] = sim.now_ms()
	active = {}
	sim.bus.emit(&"research_completed", {"id": id, "level": level(id)})


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

## Every active effect of a kind, at the strength of its node's level.
func _effects(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in completed:
		var l := level(id)
		for e: Dictionary in node(id).get("effects", []):
			if String(e.get("kind", "")) == kind:
				out.append(effect_at(e, l))
	return out


## An effect as it works at `level`: its `per_level` value when the data
## lists one, otherwise grown by balance.research.level_strength per level past
## the first (multiply m -> m^k, add -> add x k, k = 1 + strength x (L-1)).
func effect_at(e: Dictionary, lv: int) -> Dictionary:
	if lv <= 1 and not e.has("per_level"):
		return e
	var x := e.duplicate()
	var steps: Array = e.get("per_level", [])
	if not steps.is_empty():
		var v: Variant = steps[clampi(lv, 1, steps.size()) - 1]
		if x.has("multiply"):
			x["multiply"] = float(v)
		elif x.has("add"):
			x["add"] = v
		return x
	var k := 1.0 + sim.data.get_float("balance", "research.level_strength", 0.25) * (lv - 1)
	if x.has("multiply"):
		x["multiply"] = pow(float(x["multiply"]), k)
	if x.has("add"):
		var add := float(x["add"]) * k
		x["add"] = int(floor(add)) if typeof(e["add"]) == TYPE_INT else add
	return x


## A node's effects at a given level (the points screen previews with this).
func effects_at(id: String, lv: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if lv <= 0:
		return out
	for e: Dictionary in node(id).get("effects", []):
		out.append(effect_at(e, mini(lv, max_level(id))))
	return out


## Saves a plan in a slot (validated as far as nodes and levels go; the
## points may be short, it is only a plan).
func save_profile(slot: int, levels: Dictionary) -> Dictionary:
	if slot < 0 or slot >= PROFILES:
		return SimResult.fail("err.bad_command")
	var clean := {}
	for id: String in levels:
		if not node(id).is_empty() and is_unlocked_node(id) and int(levels[id]) > 0:
			clean[id] = mini(int(levels[id]), max_level(id))
	profiles[slot] = clean
	sim.bus.emit(&"research_profile_saved", {"slot": slot})
	return SimResult.ok({"levels": clean})


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


## Whether research has opened a routing strategy (auto).
func opens_route(strategy: String) -> bool:
	for e: Dictionary in _effects("route"):
		if String(e.get("strategy", "")) == strategy:
			return true
	return false


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


## Prestige: this run's researched levels become research points for good,
## every level goes back to 0 (to be allocated again), unlocks stay. Returns
## the RP issued.
func carry_over() -> Dictionary:
	return {"unlocked": unlocked.duplicate(), "rp_earned": rp_earned + rp_pending(), "issued": rp_pending(), "profiles": profiles.duplicate(true)}


func adopt(carry: Dictionary) -> void:
	for id: String in carry.get("unlocked", {}):
		if not node(id).is_empty():
			unlocked[id] = true
	rp_earned = maxi(int(carry.get("rp_earned", 0)), 0)
	_read_profiles(carry.get("profiles", []))


func _read_profiles(raw: Variant) -> void:
	profiles = []
	for i in PROFILES:
		var p := {}
		if typeof(raw) == TYPE_ARRAY and i < (raw as Array).size() and typeof(raw[i]) == TYPE_DICTIONARY:
			for id: String in raw[i]:
				if not node(id).is_empty() and int(raw[i][id]) > 0:
					p[id] = mini(int(raw[i][id]), max_level(id))
		profiles.append(p)


func save_state() -> Dictionary:
	return {"completed": completed.duplicate(), "active": active.duplicate(), "token": token,
		"bought": bought.duplicate(), "allocated": allocated.duplicate(), "unlocked": unlocked.keys(), "rp_earned": rp_earned,
		"profiles": profiles.duplicate(true)}


func load_state(state: Dictionary) -> void:
	on_new_game()
	var done: Dictionary = state.get("completed", {})
	for k: String in done:
		completed[k] = int(done[k])
	var a: Dictionary = state.get("active", {})
	if not a.is_empty():
		active = {"id": String(a["id"]), "start": int(a["start"]), "end": int(a["end"]), "token": int(a["token"])}
	token = int(state.get("token", 0))
	rp_earned = maxi(int(state.get("rp_earned", 0)), 0)
	_read_profiles(state.get("profiles", []))
	for id: Variant in state.get("unlocked", []):
		if not node(String(id)).is_empty():
			unlocked[String(id)] = true
	var raw_bought: Dictionary = state.get("bought", {})
	if not state.has("bought"):
		# Before levels: everything finished was researched once.
		for id: String in completed:
			raw_bought[id] = 1
	for id: String in raw_bought:
		if not node(id).is_empty() and int(raw_bought[id]) > 0:
			bought[id] = mini(int(raw_bought[id]), max_level(id))
			unlocked[id] = true
	for id: String in completed:
		unlocked[id] = true
	# Allocations are trusted only as far as they add up: a damaged save that
	# places more points than were earned, on locked or unknown nodes or past
	# a node's top, loses those allocations (the points come back unspent).
	var raw_alloc: Dictionary = state.get("allocated", {})
	var plan := {}
	var ids := raw_alloc.keys()
	ids.sort()
	for id: Variant in ids:
		plan[String(id)] = int(raw_alloc[id])
	if not plan.is_empty():
		if check_allocation(plan)["ok"]:
			allocated = plan
		else:
			allocated = {}
			for id: String in completed.keys():
				if int(bought.get(id, 0)) <= 0 and plan.has(id):
					completed.erase(id)
