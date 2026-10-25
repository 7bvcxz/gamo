class_name PowerSystem
extends SimSystem

## Electricity as capacity: how many kW the island's generators give right
## now against what the buildings working right now draw.
##
## Generators (buildings with power.generate) differ in kind, not rank:
##   solar  follows the sun -- the sky's own phases, zero at night
##   wind   follows a smooth, deterministic gust curve, day and night
##   steam  steady while stoked with wood (its stoking is a work stage)
##   hydro  steady, but only on a tile beside the sea
## Consumers are buildings research has electrified (effect power_use): they
## draw while they work and, fully powered, work faster. A stage takes its
## power share when it starts -- satisfaction = supply / (what is already
## running + its own draw), capped at 1 -- and keeps that speed to its end.
## No flows, no storage, nothing continuous: a brownout is fewer kW than
## draw, and everything that starts during it runs proportionally slower.
## A consumer marked `required` cannot start at all without power.

## generator building id -> ms until which its boiler is fired (steam).
var fired_until: Dictionary = {}
## consumer building id -> the share of its draw it got when its current or
## last stage started (0..1), for the indicators.
var shares: Dictionary = {}


func _init() -> void:
	key = &"power"


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	var buildings: BuildingSystem = p_sim.system(&"buildings")
	if buildings != null and not buildings.modifiers.has(self):
		buildings.modifiers.append(self)
	p_sim.bus.emitted.connect(_on_event)


func on_new_game() -> void:
	fired_until.clear()
	shares.clear()


func _on_event(type: StringName, payload: Dictionary) -> void:
	if type == &"task_completed" and String(payload.get("stage", "")) == "stoke":
		var b := (sim.system(&"buildings") as BuildingSystem).get_building(int(payload["id"]))
		var gen := generator_def(String(b.get("type", "")))
		fired_until[int(payload["id"])] = sim.now_ms() + int(float(gen.get("burn_seconds", 30)) * 1000.0)
		sim.bus.emit(&"power_changed", {})
	elif type == &"task_started":
		# The building is already running: supply / demand is exactly the
		# share it was given (everything else running, plus itself).
		var b := (sim.system(&"buildings") as BuildingSystem).get_building(int(payload["id"]))
		if not use_of(String(b.get("type", ""))).is_empty():
			shares[int(payload["id"])] = ratio()
	elif type == &"building_removed" or type == &"building_refit":
		fired_until.erase(int(payload.get("id", 0)))
		shares.erase(int(payload.get("id", 0)))
		if type == &"building_refit":
			sim.bus.emit(&"power_changed", {})


# --- generation -------------------------------------------------------------------

func generator_def(type: String) -> Dictionary:
	return sim.data.building_type(type).get("power", {}).get("generate", {})


func is_generator(type: String) -> bool:
	return not generator_def(type).is_empty()


## Built generators, in id order.
func generators() -> Array[int]:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var out: Array[int] = []
	for id: int in buildings.ids():
		var b := buildings.get_building(id)
		if is_generator(String(b["type"])) and b["state"] != BuildingSystem.CONSTRUCTING:
			out.append(id)
	return out


## 0..1 sunlight at a point of the day: rises at dawn, peaks halfway to the
## start of night, gone at night -- the same phases the sky draws.
func sunlight(progress: float) -> float:
	var rise := _phase_start("dawn", 0.92)
	var set := _phase_start("night", 0.70)
	var span := fposmod(set - rise, 1.0)
	var x := fposmod(progress - rise, 1.0)
	if span <= 0.0 or x >= span:
		return 0.0
	return pow(sin(PI * x / span), 0.8)


func _phase_start(name: String, fallback: float) -> float:
	for p: Dictionary in sim.data.get_value("balance", "clock.phases", []):
		if String(p.get("name", "")) == name:
			return float(p["from"])
	return fallback


## 0..1 wind at a moment: two slow sines over days -- smooth, the same for
## everyone at the same time, never random.
func wind(t_ms: int) -> float:
	var day := float(t_ms) / float(sim.clock.day_ms)
	var base := sim.data.get_float("balance", "power.wind_base", 0.55)
	var slow := sim.data.get_float("balance", "power.wind_slow_amp", 0.3) * sin(TAU * day / sim.data.get_float("balance", "power.wind_slow_days", 3.0))
	var fast := sim.data.get_float("balance", "power.wind_fast_amp", 0.15) * sin(TAU * day / sim.data.get_float("balance", "power.wind_fast_days", 0.7) + 1.3)
	return clampf(base + slow + fast, sim.data.get_float("balance", "power.wind_min", 0.1), 1.0)


## What one generator gives at a moment, in kW.
func output_of(id: int, t_ms: int) -> float:
	var b := (sim.system(&"buildings") as BuildingSystem).get_building(id)
	if b.is_empty() or b["state"] == BuildingSystem.CONSTRUCTING:
		return 0.0
	var gen := generator_def(String(b["type"]))
	var kw := float(gen.get("kw", 0))
	match String(gen.get("kind", "")):
		"solar":
			return kw * sunlight(float(posmod(t_ms, sim.clock.day_ms)) / float(sim.clock.day_ms))
		"wind":
			return kw * wind(t_ms)
		"steam":
			return kw if t_ms < int(fired_until.get(id, -1)) else 0.0
		"hydro":
			return kw
	return 0.0


func supply(t_ms: int = -1) -> float:
	var t := sim.now_ms() if t_ms < 0 else t_ms
	var total := 0.0
	for id: int in generators():
		total += output_of(id, t)
	return total


func capacity() -> float:
	var total := 0.0
	for id: int in generators():
		var b := (sim.system(&"buildings") as BuildingSystem).get_building(id)
		total += float(generator_def(String(b["type"])).get("kw", 0))
	return total


# --- use --------------------------------------------------------------------------

## The power use research has given this building type: {draw, multiply, required}, or {}.
func use_of(type: String) -> Dictionary:
	var out := {}
	# A building that always runs on power says so in its data.
	var own: Dictionary = sim.data.building_type(type).get("power", {}).get("use", {})
	if not own.is_empty():
		out = {"draw": float(own.get("draw", 0)), "multiply": float(own.get("multiply", 1.0)), "required": bool(own.get("required", false))}
	var research: ResearchSystem = sim.system(&"research")
	if research == null:
		return out
	for id: String in research.completed:
		for e: Dictionary in research.node(id).get("effects", []):
			if String(e.get("kind", "")) == "power_use" and String(e.get("type", "")) == type:
				out = {"draw": float(e.get("draw", 0)), "multiply": float(e.get("multiply", 1.0)), "required": bool(e.get("required", false))}
	return out


## kW drawn by the buildings working now.
func demand() -> float:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var total := 0.0
	for id: int in buildings.ids():
		var b := buildings.get_building(id)
		if b["state"] == BuildingSystem.WORKING:
			total += float(use_of(String(b["type"])).get("draw", 0.0))
	return total


## The share a building of this type gets if it starts now: 1 when it uses
## no power or there is enough for everything running plus it.
func satisfaction(type: String) -> float:
	var draw := float(use_of(type).get("draw", 0.0))
	if draw <= 0.0:
		return 1.0
	return clampf(supply() / (demand() + draw), 0.0, 1.0)


## Whole-island share right now (for indicators): supply / demand.
func ratio() -> float:
	var d := demand()
	return 1.0 if d <= 0.0 else clampf(supply() / d, 0.0, 1.0)


## BuildingSystem modifier: a powered building works faster in proportion to
## the power it gets.
func stage_multiplier(kind: String, type: String, _action: String) -> float:
	if kind != "work":
		return 1.0
	var use := use_of(type)
	if use.is_empty():
		return 1.0
	return lerpf(1.0, float(use["multiply"]), satisfaction(type))


## BuildingSystem modifier: a building that cannot run without power.
func start_blocker(type: String) -> String:
	var use := use_of(type)
	if bool(use.get("required", false)) and satisfaction(type) <= 0.0:
		return "err.no_power"
	return ""


func save_state() -> Dictionary:
	var out := {}
	for id: int in fired_until:
		out[str(id)] = int(fired_until[id])
	var sh := {}
	for id: int in shares:
		sh[str(id)] = float(shares[id])
	return {"fired_until": out, "shares": sh}


func load_state(state: Dictionary) -> void:
	fired_until.clear()
	var f: Dictionary = state.get("fired_until", {})
	for k: String in f:
		fired_until[int(k)] = int(f[k])
	shares.clear()
	var sh: Dictionary = state.get("shares", {})
	for k: String in sh:
		shares[int(k)] = float(sh[k])


## Whether power is part of this island yet (a generator, or research using it).
func in_use() -> bool:
	if capacity() > 0.0:
		return true
	var buildings: BuildingSystem = sim.system(&"buildings")
	for id: int in buildings.ids():
		if not use_of(String(buildings.get_building(id)["type"])).is_empty():
			return true
	return false
