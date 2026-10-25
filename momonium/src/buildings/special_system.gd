class_name SpecialSystem
extends SimSystem

## What the landmarks do, while they stand (a finished one, not one rising).
## Each special type names its effect in the data (buildings.json `effect`):
##
##   work_burst (Clock Tower): every `cycle_seconds` of game time, the first
##     `active_seconds` are a burst -- work stages started then take
##     `multiply` times as long. The cycle is the game clock's own, the same
##     for everyone and every load: building, pulling down, rebuilding, saving
##     or loading never moves it, and offline time runs it exactly.
##   skill_exp (School): Momo skill and building mastery experience gained
##     times `multiply` (fractions carried exactly by their systems).
##   legacy (Momo Monument): legacy points from selling the island plus
##     `share` of them, rounded to the nearest point (half up).
##
## The burst reaches the buildings through the same modifier pipeline as
## research (stage_multiplier): it multiplies with research and still stops at
## every stage's floor.

func _init() -> void:
	key = &"specials"


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	var buildings: BuildingSystem = p_sim.system(&"buildings")
	if buildings != null and not buildings.modifiers.has(self):
		buildings.modifiers.append(self)


## The effect of a special type that stands finished now, or {}.
func effect(kind: String) -> Dictionary:
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids():
		var b := bs.get_building(id)
		if b["state"] == BuildingSystem.CONSTRUCTING or not bs.is_special(String(b["type"])):
			continue
		var e: Dictionary = bs.type_def(b).get("effect", {})
		if String(e.get("kind", "")) == kind:
			return e
	return {}


# --- Clock Tower -----------------------------------------------------------------------

## {standing, active, remaining_ms (of this burst, or until the next one), cycle_ms}.
func burst(now_ms: int = -1) -> Dictionary:
	var e := effect("work_burst")
	if e.is_empty():
		return {"standing": false, "active": false, "remaining_ms": 0, "cycle_ms": 0}
	var now := sim.now_ms() if now_ms < 0 else now_ms
	var cycle := int(float(e.get("cycle_seconds", 180)) * 1000.0)
	var on := int(float(e.get("active_seconds", 30)) * 1000.0)
	var at := now % maxi(cycle, 1)
	if at < on:
		return {"standing": true, "active": true, "remaining_ms": on - at, "cycle_ms": cycle}
	return {"standing": true, "active": false, "remaining_ms": cycle - at, "cycle_ms": cycle}


## BuildingSystem modifier: work started during a burst is quicker -- only the
## work of production buildings (the four families and their facilities).
func stage_multiplier(kind: String, type: String, _action: String) -> float:
	if kind != "work" or (sim.system(&"buildings") as BuildingSystem).is_special(type):
		return 1.0
	var b := burst()
	if not b["active"]:
		return 1.0
	return float(effect("work_burst").get("multiply", 1.0))


# --- School -----------------------------------------------------------------------------

func skill_exp_multiplier() -> float:
	var e := effect("skill_exp")
	return float(e.get("multiply", 1.0)) if not e.is_empty() else 1.0


## `amount` of experience times the School, with the fraction carried in
## `carry[key]` (thousandths): whole points now, the rest later, nothing lost.
func scaled_exp(amount: int, carry: Dictionary, carry_key: String) -> int:
	var m := skill_exp_multiplier()
	if is_equal_approx(m, 1.0):
		return amount
	var milli := amount * int(round(m * 1000.0)) + int(carry.get(carry_key, 0))
	carry[carry_key] = milli % 1000
	return milli / 1000


# --- Momo Monument -------------------------------------------------------------------------

## Extra legacy points the Monument adds to `points` gained by a sale.
func legacy_bonus(points: int) -> int:
	var e := effect("legacy")
	if e.is_empty() or points <= 0:
		return 0
	return int(floor(points * float(e.get("share", 0.0)) + 0.5))
