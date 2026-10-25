class_name ProgressionSystem
extends SimSystem

## Player level and per-building-type mastery.
##
## EXP comes only from things that were finished: a stage's completion (a
## harvest), a building completed, land bought -- the amounts are in
## balance.progression.rewards. Tapping, starting, waiting earn nothing, so the
## numbers measure what the island did, not how often the screen was touched.
##
## Thresholds grow (exp_to_next); a level-up carries the remainder over and can
## jump more than one level. Mastery is the same per building type, shown in
## Status, and is what letters (Step 21) and research (Step 22) look at.

var level: int = 1
var experience: int = 0
## type -> {level, exp}
var mastery: Dictionary = {}


func _init() -> void:
	key = &"progression"


func on_new_game() -> void:
	level = sim.data.get_int("balance", "start.level", 1)
	experience = sim.data.get_int("balance", "start.exp")
	mastery = {}


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


## EXP needed to leave the current level.
func next_level_exp() -> int:
	return exp_needed_for(level)


func exp_needed_for(at_level: int) -> int:
	return _step("progression.exp_to_next", "progression.growth", at_level)


func mastery_needed_for(at_level: int) -> int:
	return _step("progression.mastery_exp_to_next", "progression.mastery_growth", at_level)


func _step(list_path: String, growth_path: String, at_level: int) -> int:
	var steps: Array = sim.data.get_value("balance", list_path, [100])
	if at_level - 1 < steps.size():
		return int(steps[maxi(at_level - 1, 0)])
	var growth := sim.data.get_float("balance", growth_path, 1.3)
	return int(float(steps[-1]) * pow(growth, at_level - steps.size()))


func mastery_of(type: String) -> Dictionary:
	var m: Dictionary = mastery.get(type, {"level": 1, "exp": 0})
	return {"level": int(m["level"]), "exp": int(m["exp"]), "next": mastery_needed_for(int(m["level"]))}


## The building types Status shows a mastery card for, in order.
func mastery_types() -> Array[String]:
	var out: Array[String] = []
	for t: String in sim.data.get_value("balance", "progression.mastery_types", []):
		out.append(t)
	return out


func add_exp(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	experience += amount
	sim.bus.emit(&"exp_gained", {"amount": amount, "reason": reason, "exp": experience})
	while experience >= next_level_exp():
		experience -= next_level_exp()
		level += 1
		sim.bus.emit(&"level_up", {"level": level})


func add_mastery(type: String, amount: int) -> void:
	if amount <= 0 or type == "":
		return
	var m: Dictionary = mastery.get(type, {"level": 1, "exp": 0})
	# Stored before announcing: a listener asking mastery_of() during
	# mastery_up must see the new level, also for a type's first gain.
	mastery[type] = m
	m["exp"] = int(m["exp"]) + amount
	while int(m["exp"]) >= mastery_needed_for(int(m["level"])):
		m["exp"] = int(m["exp"]) - mastery_needed_for(int(m["level"]))
		m["level"] = int(m["level"]) + 1
		sim.bus.emit(&"mastery_up", {"type": type, "level": m["level"]})
	sim.bus.emit(&"mastery_gained", {"type": type, "amount": amount, "level": m["level"], "exp": m["exp"]})


## Whether the player meets an unlock requirement: {level, mastery: {type: lvl}}.
func meets(requirement: Dictionary) -> bool:
	if level < int(requirement.get("level", 1)):
		return false
	var needs: Dictionary = requirement.get("mastery", {})
	for type: String in needs:
		if int(mastery_of(type)["level"]) < int(needs[type]):
			return false
	return true


func is_unlocked(feature: String) -> bool:
	return meets(sim.data.get_value("balance", "unlocks." + feature, {}))


## Rewards are paid from the bus: the systems that finish things announce it,
## and this decides what it is worth. In-sim, so it runs in event order.
func _on_event(type: StringName, payload: Dictionary) -> void:
	var rewards: Dictionary = sim.data.get_value("balance", "progression.rewards", {})
	match type:
		&"task_completed":
			var k := "%s.%s" % [payload.get("type", ""), _action(payload)]
			var r: Dictionary = rewards.get("stage", {}).get(k, {})
			add_exp(int(r.get("player", 0)), k)
			add_mastery(String(payload.get("type", "")), int(r.get("mastery", 0)))
		&"building_built", &"land_bought":
			var r: Dictionary = rewards.get("event", {}).get(String(type), {})
			add_exp(int(r.get("player", 0)), String(type))


func _action(payload: Dictionary) -> String:
	var stage_id := String(payload.get("stage", ""))
	var def := sim.data.building_type(String(payload.get("type", "")))
	for st: Dictionary in def.get("cycle", {}).get("stages", []):
		if st.get("id", "") == stage_id:
			return String(st.get("action", stage_id))
	return stage_id


func save_state() -> Dictionary:
	var m := {}
	for t: String in mastery:
		m[t] = {"level": int(mastery[t]["level"]), "exp": int(mastery[t]["exp"])}
	return {"level": level, "exp": experience, "mastery": m}


func load_state(state: Dictionary) -> void:
	level = int(state.get("level", 1))
	experience = int(state.get("exp", 0))
	mastery = {}
	var m: Dictionary = state.get("mastery", {})
	for t: String in m:
		mastery[t] = {"level": int(m[t]["level"]), "exp": int(m[t]["exp"])}
