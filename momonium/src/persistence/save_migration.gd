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
	}


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
