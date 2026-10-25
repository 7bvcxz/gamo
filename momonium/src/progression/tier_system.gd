class_name TierSystem
extends SimSystem

## What the settlement is: a Village, then a City, then a Nation.
##
## Each step up has milestones in the data (balance.tiers.levels): land owned,
## Momo living here, research levels active, and the value the island has
## produced (all its sales and releases) -- each shown with what it has and
## needs. When every one is met the player promotes (tier.promote); nothing
## is lost by it, and a tier never goes down on this island. A tier sets how
## many special structures may stand at once (1, 2, 3 -- in total, not per
## kind). Selling the island starts the next one as a Village.

const NAMES: PackedStringArray = ["village", "city", "nation"]

var tier := 0


func _init() -> void:
	key = &"tiers"


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["tier.promote"])


func on_new_game() -> void:
	tier = 0


func tier_name(t: int = -1) -> String:
	return NAMES[clampi(tier if t < 0 else t, 0, NAMES.size() - 1)]


func levels() -> Array:
	return sim.data.get_value("balance", "tiers.levels", [])


## Specials that may stand at once at this tier.
func special_slots() -> int:
	var l: Array = levels()
	if l.is_empty():
		return sim.data.get_int("balance", "specials.slots", 1)
	return int((l[clampi(tier, 0, l.size() - 1)] as Dictionary).get("special_slots", 1))


func is_top() -> bool:
	return tier >= levels().size() - 1


## Where the island stands on each milestone of the next tier:
## [{key, have, need, met}] (empty at the top).
func progress() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if is_top():
		return out
	var need: Dictionary = (levels()[tier + 1] as Dictionary).get("needs", {})
	for k: String in ["tiles", "momos", "research_levels", "produced"]:
		if not need.has(k):
			continue
		var have := measure(k)
		out.append({"key": k, "have": have, "need": int(need[k]), "met": have >= int(need[k])})
	return out


func measure(k: String) -> int:
	match k:
		"tiles":
			return (sim.system(&"world") as WorldSystem).owned_count()
		"momos":
			return (sim.system(&"momo") as MomoSystem).ids().size()
		"research_levels":
			var rs: ResearchSystem = sim.system(&"research")
			var n := 0
			for id: String in rs.completed:
				n += rs.level(id)
			return n
		"produced":
			var eco: EconomySystem = sim.system(&"economy")
			return int(eco.lifetime.get("sale", 0)) + int(eco.lifetime.get("release", 0))
	return 0


func can_promote() -> bool:
	if is_top():
		return false
	for p: Dictionary in progress():
		if not p["met"]:
			return false
	return true


func execute(command: Dictionary) -> Dictionary:
	if String(command.get("type", "")) != "tier.promote":
		return SimResult.fail("err.unknown_command")
	if is_top():
		return SimResult.fail("err.tier_top")
	if not can_promote():
		return SimResult.fail("err.tier_not_yet", {"progress": progress()})
	tier += 1
	sim.bus.emit(&"tier_promoted", {"tier": tier, "name": tier_name(), "special_slots": special_slots()})
	return SimResult.ok({"tier": tier, "name": tier_name(), "special_slots": special_slots()})


func save_state() -> Dictionary:
	return {"tier": tier}


func load_state(state: Dictionary) -> void:
	tier = clampi(int(state.get("tier", 0)), 0, maxi(levels().size() - 1, 0))
