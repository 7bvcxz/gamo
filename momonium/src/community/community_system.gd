class_name CommunitySystem
extends SimSystem

## Momo life: homes, rest and happiness, and what they do to work.
##
## Homes: each Momo is housed in id order, filling homes in the order they
## were built, up to each one's capacity. A housed Momo sleeps well and works
## its home's `rest` times as long; one without a home rests outdoors (1.0).
##
## Happiness (0..max): the island's open amenities, each type counting its
## first copy fully and further copies at the `stack` fractions (a second
## park is pleasant, a fifth adds nothing). Amenities are opened at each new
## day: one with `daily` needs (a pub's crops) takes them from the store or
## stays shut that day; one that needs `power` opens only if that much is on
## supply at that moment. Work time is multiplied by
## rest * (1 - happiness/max * effect), never below `floor` -- a contented,
## rested Momo is somewhat quicker, never magically so.

## amenity building id -> the day it is open (-1 shut).
var open_on: Dictionary = {}


func _init() -> void:
	key = &"community"


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


func on_new_game() -> void:
	open_on.clear()


func _on_event(type: StringName, payload: Dictionary) -> void:
	# A new amenity opens the day it is finished (if it can).
	if type == &"building_built":
		_open(int(payload.get("id", 0)))
	elif type == &"building_removed" or type == &"building_refit":
		open_on.erase(int(payload.get("id", 0)))


func on_day_started(_day: int) -> void:
	for id: int in amenities():
		_open(id)


func _open(id: int) -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var b := bs.get_building(id)
	var am: Dictionary = bs.type_def(b).get("amenity", {}) if not b.is_empty() else {}
	if am.is_empty() or b["state"] == BuildingSystem.CONSTRUCTING:
		return
	var day := sim.clock.day_number()
	if int(open_on.get(id, -1)) == day:
		return
	var ok := true
	var needs: Dictionary = am.get("daily", {})
	var inv: InventorySystem = sim.system(&"inventory")
	if not needs.is_empty():
		ok = inv.has_all(needs)
	var kw := float(am.get("power", 0))
	if ok and kw > 0.0:
		var power: PowerSystem = sim.system(&"power")
		ok = power != null and power.supply() >= kw
	if ok and not needs.is_empty():
		inv.take_all(needs, "consume:" + String(b["type"]))
	open_on[id] = day if ok else -1
	sim.bus.emit(&"amenity_opened" if ok else &"amenity_shut", {"id": id, "day": day})


func is_open(id: int) -> bool:
	return int(open_on.get(id, -1)) == sim.clock.day_number()


# --- homes ------------------------------------------------------------------------

func homes() -> Array[int]:
	var bs: BuildingSystem = sim.system(&"buildings")
	var out: Array[int] = []
	for id: int in bs.ids():
		var b := bs.get_building(id)
		if not (bs.type_def(b).get("housing", {}) as Dictionary).is_empty() and b["state"] != BuildingSystem.CONSTRUCTING:
			out.append(id)
	return out


func capacity() -> int:
	var bs: BuildingSystem = sim.system(&"buildings")
	var n := 0
	for id: int in homes():
		n += int(bs.type_def(bs.get_building(id))["housing"].get("capacity", 0))
	return n


## Momo id -> home building id (only housed Momo), in id order.
func housing() -> Dictionary:
	var bs: BuildingSystem = sim.system(&"buildings")
	var out := {}
	var hs := homes()
	var h := 0
	var used := 0
	for m: int in (sim.system(&"momo") as MomoSystem).ids():
		while h < hs.size() and used >= int(bs.type_def(bs.get_building(hs[h]))["housing"].get("capacity", 0)):
			h += 1
			used = 0
		if h >= hs.size():
			break
		out[m] = hs[h]
		used += 1
	return out


func home_of(momo: int) -> int:
	return int(housing().get(momo, 0))


func rest_of(momo: int) -> float:
	var home := home_of(momo)
	if home == 0:
		return 1.0
	var bs: BuildingSystem = sim.system(&"buildings")
	return float(bs.type_def(bs.get_building(home))["housing"].get("rest", 1.0))


# --- happiness --------------------------------------------------------------------

func amenities() -> Array[int]:
	var bs: BuildingSystem = sim.system(&"buildings")
	var out: Array[int] = []
	for id: int in bs.ids():
		if not (bs.type_def(bs.get_building(id)).get("amenity", {}) as Dictionary).is_empty():
			out.append(id)
	return out


## Each amenity's part in today's happiness: [{id, type, open, adds}].
func breakdown() -> Array[Dictionary]:
	var bs: BuildingSystem = sim.system(&"buildings")
	var stack: Array = sim.data.get_value("balance", "community.stack", [1.0])
	var seen := {}
	var out: Array[Dictionary] = []
	for id: int in amenities():
		var b := bs.get_building(id)
		var type := String(b["type"])
		var open: bool = is_open(id) and b["state"] != BuildingSystem.CONSTRUCTING
		var adds := 0.0
		if open:
			var n := int(seen.get(type, 0))
			seen[type] = n + 1
			if n < stack.size():
				adds = float(bs.type_def(b)["amenity"].get("happiness", 0)) * float(stack[n])
		out.append({"id": id, "type": type, "open": open, "adds": adds})
	return out


func happiness() -> float:
	var total := 0.0
	for part: Dictionary in breakdown():
		total += float(part["adds"])
	return minf(total, sim.data.get_float("balance", "community.max_happiness", 100.0))


## What a Momo's life does to its work time (multiplier, floored).
func work_factor(momo: int) -> float:
	var max_h := sim.data.get_float("balance", "community.max_happiness", 100.0)
	var effect := sim.data.get_float("balance", "community.happiness_effect", 0.15)
	var f := rest_of(momo) * (1.0 - happiness() / max_h * effect)
	return maxf(f, sim.data.get_float("balance", "community.floor", 0.75))


func save_state() -> Dictionary:
	var out := {}
	for id: int in open_on:
		out[str(id)] = int(open_on[id])
	return {"open_on": out}


func load_state(state: Dictionary) -> void:
	open_on.clear()
	var o: Dictionary = state.get("open_on", {})
	for k: String in o:
		open_on[int(k)] = int(o[k])
