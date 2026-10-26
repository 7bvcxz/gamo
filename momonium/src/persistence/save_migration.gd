class_name SaveMigration
extends RefCounted

## Upgrades a saved simulation state from an older schema to the current one,
## one step at a time, so a save from any earlier version opens. Each step is
## a pure function of the state; add a step when Simulation.SAVE_SCHEMA goes up.
##
## Systems already read missing fields as their defaults (a save from before
## letters has no "mail", and gets an empty mailbox), so a step only needs to
## change what has a different meaning, not add what is new.

## schema -> the function taking that schema's state to the next.
static func steps() -> Dictionary:
	return {
		# 1 -> 2: Step 24 put the state in an envelope with the time it was
		# saved; the state itself is unchanged. A bare schema-1 state has no
		# time, so it gets no offline progress (we cannot know how long it was).
		1: func(state: Dictionary) -> Dictionary:
			var s := state.duplicate(true)
			s["schema"] = 2
			return s,
		# 2 -> 3: Step 50 made finished work money at once and the farm a
		# five-second cycle (sow, water, harvest; millet: sow, harvest).
		2: func(state: Dictionary) -> Dictionary:
			return _to_3(state),
	}


## What the store held for the next dawn's sale is sold once, at the prices
## the old rules promised (v0.49: crops $5, cars $420) -- never again at dawn,
## and never twice. A farm's place in its old cycle maps onto the new one: a
## stage under way stays under way (its scheduled end completes the mapped
## stage), a farm waiting goes on to the stage the old cycle had it at.
const OLD_DAWN_PRICES := {"crop": 5, "car": 420}
## Old base cycle sow, water1, water2, water3, harvest -> sow, water, harvest:
## [stage under way, next stage to do].
const OLD_FARM := [[0, 0], [1, 1], [1, 2], [1, 2], [2, 2]]
## Old millet sow, water1, water2, harvest -> sow, harvest.
const OLD_MILLET := [[0, 0], [0, 1], [0, 1], [1, 1]]


static func _to_3(state: Dictionary) -> Dictionary:
	var s := state.duplicate(true)
	s["schema"] = 3
	var systems: Dictionary = s.get("systems", {})
	var inv: Dictionary = systems.get("inventory", {})
	var items: Dictionary = inv.get("items", {})
	var eco: Dictionary = systems.get("economy", {})
	var paid := 0
	for item: String in OLD_DAWN_PRICES:
		var n := int(items.get(item, 0))
		if n > 0:
			paid += n * int(OLD_DAWN_PRICES[item])
			items.erase(item)
	if paid > 0 and not eco.is_empty():
		eco["money"] = int(eco.get("money", 0)) + paid
		for book: String in ["today", "lifetime"]:
			var d: Dictionary = eco.get(book, {})
			d["sale"] = int(d.get("sale", 0)) + paid
			eco[book] = d
	for b: Dictionary in (systems.get("buildings", {}) as Dictionary).get("buildings", []):
		if String(b.get("type", "")) != "farm":
			continue
		var table: Array = OLD_MILLET if String(b.get("variety", "base")) == "millet" else OLD_FARM
		var i := clampi(int(b.get("stage", 0)), 0, table.size() - 1)
		b["stage"] = int(table[i][0 if String(b.get("state", "")) == "working" else 1])
	return s


## The state at the current schema, or {} when it cannot be (too new, or a
## step is missing). `from` is the schema the state says it has.
static func migrate(state: Dictionary) -> Dictionary:
	var schema := int(state.get("schema", 1))
	if schema > Simulation.SAVE_SCHEMA:
		return {}
	var s := state
	var all := steps()
	while schema < Simulation.SAVE_SCHEMA:
		if not all.has(schema):
			return {}
		s = (all[schema] as Callable).call(s)
		schema += 1
	return s
