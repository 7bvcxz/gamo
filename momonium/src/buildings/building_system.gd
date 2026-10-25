class_name BuildingSystem
extends SimSystem

## Buildings on the island and the work they do.
##
## Every building type has a work cycle in data (buildings.json): stages done
## in order, each taking `seconds` of active work, each optionally followed by
## a `cooldown` that must pass before the next stage can start. A building is
## idle (ready for its next stage), working (a stage is in progress) or cooling
## down. Tapping a ready building starts its stage at once; the stage finishes
## by itself at its end time, whatever the player does next -- selecting
## another building, panning away or closing the game (Step 24 replays it).
##
## Ends of work are scheduled events carrying a token. Anything that changes a
## building's plans bumps its token, so a stale event finds a mismatch and does
## nothing: cancellation without searching the queue.

const TASK_DONE := "building.task_done"
const COOLDOWN_DONE := "building.cooldown_done"
const BUILT := "building.built"

const CONSTRUCTING := "constructing"
const IDLE := "idle"
const WORKING := "working"
const COOLDOWN := "cooldown"

## id -> record (plain data, saved as-is):
##   id, type, anchor [x, y], state, stage (index of the stage being done or next),
##   task_start, task_end, ready_at (ms), token, completed (stages finished),
##   build_start, build_end (ms), paid {money, items} (what construction cost)
var buildings: Dictionary = {}
var next_id := 1
## Objects that change how long stages take (research, later): each has
## stage_multiplier(kind: String, type: String, action: String) -> float,
## kind being "work" or "cooldown". They can shorten a stage, never remove one:
## every stage still runs, in order, for at least its floor.
var modifiers: Array[Object] = []
## "type/variety" -> stages (data is fixed for a game, so built once).
var _stage_cache: Dictionary = {}
const BASE_VARIETY := "base"

## No stage is ever instant, whatever multiplies it.
const MIN_WORK_SECONDS := 0.5


func _init() -> void:
	key = &"buildings"


func handled_events() -> PackedStringArray:
	return PackedStringArray([TASK_DONE, COOLDOWN_DONE, BUILT])


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["building.tap", "building.place", "building.cancel", "building.variety", "building.recipe"])


func on_new_game() -> void:
	buildings.clear()
	next_id = 1


# --- queries ----------------------------------------------------------------------

func get_building(id: int) -> Dictionary:
	return buildings.get(id, {})


func type_def(b: Dictionary) -> Dictionary:
	return sim.data.building_type(b.get("type", ""))


## The work cycle of this building: its type's cycle, or the process of the
## variety it grows (a variety may bring its own stages, or only different
## yields). Built once per type and variety.
func stages(b: Dictionary) -> Array:
	var v := variety_of(b)
	var def := type_def(b)
	if def.has("recipes"):
		return _recipe_stages(b, def)
	var key := "%s/%s" % [b.get("type", ""), v]
	if _stage_cache.has(key):
		return _stage_cache[key]
	var vdef: Dictionary = def.get("varieties", {}).get(v, {}) if v != BASE_VARIETY else {}
	var list: Array = vdef.get("stages", def.get("cycle", {}).get("stages", []))
	var yields: Dictionary = vdef.get("yield", {})
	if not yields.is_empty():
		list = list.duplicate(true)
		for st: Dictionary in list:
			if yields.has(String(st.get("id", ""))):
				st["yield"] = (yields[String(st["id"])] as Dictionary).duplicate()
	_stage_cache[key] = list
	return list


## A processing building's cycle: its one stage, filled in from the chosen
## recipe -- what it takes (`consumes`), gives, and how long it works and
## cools -- times the batches one charge holds.
func _recipe_stages(b: Dictionary, def: Dictionary) -> Array:
	var r := recipe_def(recipe_of(b))
	var batch := batch_of(b)
	var key := "%s/%s/%d" % [b.get("type", ""), recipe_of(b), batch]
	if _stage_cache.has(key):
		return _stage_cache[key]
	var st: Dictionary = (def.get("cycle", {}).get("stages", [{}]) as Array)[0].duplicate(true)
	var consumes := {}
	for item: String in r.get("inputs", {}):
		consumes[item] = int(r["inputs"][item]) * batch
	var gives := {}
	for item: String in r.get("outputs", {}):
		gives[item] = int(r["outputs"][item]) * batch
	st["consumes"] = consumes
	st["yield"] = gives
	st["seconds"] = float(r.get("seconds", st.get("seconds", 1))) * batch
	st["cooldown"] = float(r.get("cooldown", st.get("cooldown", 0)))
	st["icon"] = String(r.get("icon", st.get("icon", "")))
	st["recipe"] = recipe_of(b)
	var list := [st]
	_stage_cache[key] = list
	return list


func recipe_def(id: String) -> Dictionary:
	for r: Dictionary in sim.data.table("recipes").get("recipes", []):
		if String(r["id"]) == id:
			return r
	return {}


## Recipes this building type can run, in data order.
func recipes(type: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in sim.data.building_type(type).get("recipes", []):
		out.append(id)
	return out


func recipe_of(b: Dictionary) -> String:
	if b.has("recipe") and String(b["recipe"]) != "":
		return String(b["recipe"])
	for id: String in recipes(String(b.get("type", ""))):
		if bool(recipe_def(id).get("default", false)):
			return id
	return ""


func recipe_unlocked(type: String, recipe: String) -> bool:
	if bool(recipe_def(recipe).get("default", false)):
		return true
	for source: Object in modifiers:
		if source.has_method("unlocks_recipe") and bool(source.call("unlocks_recipe", type, recipe)):
			return true
	return false


## How many batches one charge holds (the recipe's, plus research).
func batch_of(b: Dictionary) -> int:
	var n := int(recipe_def(recipe_of(b)).get("batch", 1))
	for source: Object in modifiers:
		if source.has_method("batch_bonus"):
			n += int(source.call("batch_bonus", String(b.get("type", ""))))
	return maxi(n, 1)


## Changes what a processing building makes -- only while nothing is in it.
func set_recipe(id: int, recipe: String) -> Dictionary:
	var b := get_building(id)
	if b.is_empty():
		return SimResult.fail("err.no_building")
	if not recipes(String(b["type"])).has(recipe):
		return SimResult.fail("err.no_recipe")
	if not recipe_unlocked(String(b["type"]), recipe):
		return SimResult.fail("err.recipe_locked")
	if recipe_of(b) == recipe:
		return SimResult.ok()
	if b["state"] != IDLE:
		return SimResult.fail("err.recipe_busy")
	b["recipe"] = recipe
	sim.bus.emit(&"recipe_changed", {"id": id, "recipe": recipe})
	return SimResult.ok()


## What keeps an idle building from its next stage right now, as data the
## views can draw: {missing: {item: short by}} for inputs not in the store,
## {full: {item: n}} when the output has nowhere to go; {} when nothing does.
func blocked(b: Dictionary) -> Dictionary:
	if b.is_empty() or b["state"] != IDLE:
		return {}
	var stage := current_stage(b)
	var inv: InventorySystem = sim.system(&"inventory")
	var consumes: Dictionary = stage.get("consumes", {})
	if not consumes.is_empty() and not inv.has_all(consumes):
		return {"missing": inv.shortfall(consumes)}
	var produces := whole_yield(b, stage)
	if not produces.is_empty() and not inv.fits(produces):
		return {"full": produces}
	return {}


func variety_of(b: Dictionary) -> String:
	return String(b.get("variety", BASE_VARIETY))


## Varieties this building type can grow, in data order ("base" first), or
## empty for buildings that grow nothing.
func varieties(type: String) -> Array[String]:
	var out: Array[String] = []
	for v: String in sim.data.building_type(type).get("varieties", {}):
		if not v.begins_with("_"):
			out.append(v)
	return out


func variety_def(type: String, variety: String) -> Dictionary:
	return sim.data.building_type(type).get("varieties", {}).get(variety, {})


## Base is always open; others when a modifier source (research) opens them.
func variety_unlocked(type: String, variety: String) -> bool:
	if variety == BASE_VARIETY:
		return true
	for source: Object in modifiers:
		if source.has_method("unlocks_variety") and bool(source.call("unlocks_variety", type, variety)):
			return true
	return false


## Changes what a farm grows. Only between cycles -- before sowing, with
## nothing running -- so a crop in the ground is never swapped for another.
func set_variety(id: int, variety: String) -> Dictionary:
	var b := get_building(id)
	if b.is_empty():
		return SimResult.fail("err.no_building")
	if not varieties(String(b["type"])).has(variety):
		return SimResult.fail("err.no_variety")
	if not variety_unlocked(String(b["type"]), variety):
		return SimResult.fail("err.variety_locked")
	if variety_of(b) == variety:
		return SimResult.ok()
	if b["state"] != IDLE or int(b["stage"]) != 0:
		return SimResult.fail("err.variety_busy")
	b["variety"] = variety
	sim.bus.emit(&"variety_changed", {"id": id, "variety": variety})
	return SimResult.ok()


func current_stage(b: Dictionary) -> Dictionary:
	var list := stages(b)
	return list[int(b["stage"]) % list.size()] if not list.is_empty() else {}


func building_at(cell: Vector2i) -> int:
	var world: WorldSystem = sim.system(&"world")
	var id := world.occupant(cell)
	return id if buildings.has(id) else 0


func cells_of(b: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var anchor := Vector2i(int(b["anchor"][0]), int(b["anchor"][1]))
	var size := _size(b["type"])
	for y in size.y:
		for x in size.x:
			out.append(anchor + Vector2i(x, y))
	return out


func is_ready(b: Dictionary) -> bool:
	return b["state"] == IDLE


## Fraction of the current stage (or of construction) done, 0..1.
func progress(b: Dictionary) -> float:
	match String(b["state"]):
		WORKING:
			var span := maxi(int(b["task_end"]) - int(b["task_start"]), 1)
			return clampf(float(sim.now_ms() - int(b["task_start"])) / span, 0.0, 1.0)
		CONSTRUCTING:
			var span := maxi(int(b["build_end"]) - int(b["build_start"]), 1)
			return clampf(float(sim.now_ms() - int(b["build_start"])) / span, 0.0, 1.0)
	return 0.0


## Milliseconds until the building can be tapped again (0 when ready).
func remaining_ms(b: Dictionary) -> int:
	match b["state"]:
		CONSTRUCTING:
			return maxi(int(b["build_end"]) - sim.now_ms(), 0)
		WORKING:
			return maxi(int(b["task_end"]) - sim.now_ms(), 0)
		COOLDOWN:
			return maxi(int(b["ready_at"]) - sim.now_ms(), 0)
	return 0


func ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in buildings:
		out.append(id)
	out.sort()
	return out


# --- changes ----------------------------------------------------------------------

## Puts a finished building on the map with no cost or construction time.
## Construction (Step 13) builds on this; tests and the browser bridge use it
## directly. Returns the new id, or 0 if the cells are not free.
func place_instant(type: String, anchor: Vector2i) -> int:
	if sim.data.building_type(type).is_empty():
		return 0
	var world: WorldSystem = sim.system(&"world")
	var b := _record(type, anchor)
	if not world.occupy(cells_of(b), next_id):
		return 0
	buildings[next_id] = b
	next_id += 1
	sim.bus.emit(&"building_added", {"id": b["id"], "type": type})
	return b["id"]


func _record(type: String, anchor: Vector2i) -> Dictionary:
	return {"id": next_id, "type": type, "anchor": [anchor.x, anchor.y], "state": IDLE, "stage": 0,
		"task_start": 0, "task_end": 0, "ready_at": 0, "token": 0, "completed": 0,
		"build_start": 0, "build_end": 0, "paid": {"money": 0, "items": {}}, "worker": 0, "carry": {}}


# --- catalog and construction ---------------------------------------------------------

## Types offered right now, in catalog order, with whether the player may build them.
func catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var types: Dictionary = sim.data.get_value("buildings", "types", {})
	for type: String in types:
		var t: Dictionary = types[type]
		if not bool(t.get("enabled", true)):
			continue
		out.append({"type": type, "unlocked": is_unlocked(type), "level": int(t.get("unlock", {}).get("level", 1)),
			"cost": t.get("cost", {}), "build_seconds": float(t.get("build_seconds", 1))})
	return out


func is_unlocked(type: String) -> bool:
	var t := sim.data.building_type(type)
	var prog: ProgressionSystem = sim.system(&"progression")
	return not t.is_empty() and bool(t.get("enabled", true)) and prog.meets(t.get("unlock", {}))


## Whether `type` could be placed at `anchor` now, and if not, why -- without
## changing anything. The placement preview colours itself by this.
func can_place(type: String, anchor: Vector2i) -> Dictionary:
	var t := sim.data.building_type(type)
	if t.is_empty() or not bool(t.get("enabled", true)):
		return SimResult.fail("err.unknown_building")
	if not is_unlocked(type):
		return SimResult.fail("err.locked", {"level": int(t.get("unlock", {}).get("level", 1))})
	var world: WorldSystem = sim.system(&"world")
	for c: Vector2i in cells_of(_record(type, anchor)):
		if not world.is_owned(c):
			return SimResult.fail("err.not_owned", {"cell": [c.x, c.y]})
		if world.is_occupied(c):
			return SimResult.fail("err.occupied", {"cell": [c.x, c.y]})
	var cost: Dictionary = t.get("cost", {})
	var money := int(cost.get("money", 0))
	if not (sim.system(&"economy") as EconomySystem).can_afford(money):
		return SimResult.fail("err.not_enough_money", {"cost": money})
	var inv: InventorySystem = sim.system(&"inventory")
	var items: Dictionary = cost.get("items", {})
	if not inv.has_all(items):
		return SimResult.fail("err.not_enough_items", {"missing": inv.shortfall(items)})
	return SimResult.ok()


## Pays and starts construction. The building occupies its cells at once
## (nothing else can be put there) and becomes usable when the timer ends.
func place(type: String, anchor: Vector2i) -> Dictionary:
	var check := can_place(type, anchor)
	if not check["ok"]:
		return check
	var t := sim.data.building_type(type)
	var cost: Dictionary = t.get("cost", {})
	var money := int(cost.get("money", 0))
	var items: Dictionary = (cost.get("items", {}) as Dictionary).duplicate()
	var b := _record(type, anchor)
	(sim.system(&"world") as WorldSystem).occupy(cells_of(b), b["id"])
	(sim.system(&"economy") as EconomySystem).spend(money, "build:" + type)
	(sim.system(&"inventory") as InventorySystem).take_all(items, "build:" + type)
	var duration := int(round(float(t.get("build_seconds", 1.0)) * 1000.0))
	b["state"] = CONSTRUCTING
	b["build_start"] = sim.now_ms()
	b["build_end"] = sim.now_ms() + duration
	b["paid"] = {"money": money, "items": items}
	b["token"] = 1
	buildings[b["id"]] = b
	next_id += 1
	sim.scheduler.schedule(int(b["build_end"]), BUILT, {"id": b["id"], "token": b["token"]})
	sim.bus.emit(&"building_added", {"id": b["id"], "type": type})
	sim.bus.emit(&"construction_started", {"id": b["id"], "type": type, "ends_ms": b["build_end"], "money": money})
	return SimResult.ok({"id": b["id"], "ends_ms": b["build_end"]})


## Stops a construction and gives back what it cost (the `refund` share of
## it, all of it by default: nothing was built, nothing was used).
func cancel(id: int) -> Dictionary:
	if not buildings.has(id):
		return SimResult.fail("err.no_building")
	var b: Dictionary = buildings[id]
	if b["state"] != CONSTRUCTING:
		return SimResult.fail("err.not_constructing")
	var share := float(type_def(b).get("refund", 1.0))
	var paid: Dictionary = b.get("paid", {})
	var money := int(floor(int(paid.get("money", 0)) * share))
	(sim.system(&"economy") as EconomySystem).earn(money, "refund")
	var inv: InventorySystem = sim.system(&"inventory")
	var items: Dictionary = paid.get("items", {})
	for item: String in items:
		inv.add(item, int(floor(int(items[item]) * share)), "refund")
	b["token"] = int(b["token"]) + 1
	(sim.system(&"world") as WorldSystem).vacate(id)
	buildings.erase(id)
	sim.bus.emit(&"building_removed", {"id": id, "type": b["type"], "refund": money})
	return SimResult.ok({"refund": money})


func execute(command: Dictionary) -> Dictionary:
	match String(command.get("type", "")):
		"building.tap":
			return tap(Cmd.integer(command, "id"))
		"building.place":
			return place(Cmd.text(command, "building"), Cmd.vec2i(command, "anchor"))
		"building.cancel":
			return cancel(Cmd.integer(command, "id"))
		"building.variety":
			return set_variety(Cmd.integer(command, "id"), Cmd.text(command, "variety"))
		"building.recipe":
			return set_recipe(Cmd.integer(command, "id"), Cmd.text(command, "recipe"))
	return SimResult.fail("err.unknown_command")


## Starts the building's current stage if it is ready (the player's hands).
func tap(id: int) -> Dictionary:
	return start_stage(id, 0, 1.0)


## Starts the current stage done by `worker` (a Momo id, 0 for the player),
## taking `time_multiplier` times the stage's work time. Cooldowns that follow
## are world rules and do not scale with who did the work.
func start_stage(id: int, worker: int, time_multiplier: float) -> Dictionary:
	if not buildings.has(id):
		return SimResult.fail("err.no_building")
	var b: Dictionary = buildings[id]
	if b["state"] == CONSTRUCTING:
		return SimResult.fail("err.constructing", {"remaining_ms": remaining_ms(b)})
	if b["state"] == WORKING:
		return SimResult.fail("err.busy", {"remaining_ms": remaining_ms(b)})
	if b["state"] == COOLDOWN:
		return SimResult.fail("err.cooldown", {"remaining_ms": remaining_ms(b)})
	var stage := current_stage(b)
	var inv: InventorySystem = sim.system(&"inventory")
	# A stage that takes inputs starts only with all of them in the store, and
	# takes them as it starts: nothing is made from nothing, nothing half-charged.
	var consumes: Dictionary = stage.get("consumes", {})
	if not consumes.is_empty() and not inv.has_all(consumes):
		return SimResult.fail("err.missing_inputs", {"missing": inv.shortfall(consumes)})
	# A stage that produces does not start unless its output has somewhere to
	# go: a full store stops the harvest, it does not throw the crop away.
	var produces := whole_yield(b, stage)
	if not produces.is_empty() and not inv.fits(produces):
		return SimResult.fail("err.storage_full", {"items": produces.duplicate()})
	if not consumes.is_empty():
		inv.take_all(consumes, "consume:" + String(b["type"]))
		sim.bus.emit(&"consumed", {"id": id, "type": b["type"], "items": consumes.duplicate()})
	var duration := int(round(stage_seconds(b, stage) * maxf(time_multiplier, 0.01) * 1000.0))
	b["state"] = WORKING
	b["worker"] = worker
	b["task_start"] = sim.now_ms()
	b["task_end"] = sim.now_ms() + duration
	b["token"] = int(b["token"]) + 1
	sim.scheduler.schedule(int(b["task_end"]), TASK_DONE, {"id": id, "token": b["token"]})
	sim.bus.emit(&"task_started", {"id": id, "stage": stage.get("id", ""), "ends_ms": b["task_end"], "worker": worker})
	return SimResult.ok({"stage": stage.get("id", ""), "ends_ms": b["task_end"]})


func handle_event(type: String, data: Dictionary) -> void:
	var id := int(data.get("id", 0))
	if not buildings.has(id):
		return
	var b: Dictionary = buildings[id]
	if int(data.get("token", -1)) != int(b["token"]):
		return
	match type:
		TASK_DONE:
			_complete_stage(b)
		COOLDOWN_DONE:
			b["state"] = IDLE
			sim.bus.emit(&"building_ready", {"id": id})
			sim.bus.emit(&"building_idle", {"id": id})
		BUILT:
			b["state"] = IDLE
			sim.bus.emit(&"building_built", {"id": id, "type": b["type"]})
			sim.bus.emit(&"building_idle", {"id": id})


## Active work time of a stage after modifiers, never under its floor.
func stage_seconds(b: Dictionary, stage: Dictionary) -> float:
	var base := float(stage.get("seconds", 1.0))
	var m := _multiplier("work", String(b["type"]), String(stage.get("action", "")))
	return maxf(base * m, maxf(float(stage.get("seconds_floor", MIN_WORK_SECONDS)), MIN_WORK_SECONDS))


## Wait after a stage after modifiers, never under its floor (a world rule:
## plants need time to drink, however good the watering can).
func stage_cooldown(b: Dictionary, stage: Dictionary) -> float:
	var base := float(stage.get("cooldown", 0.0))
	if base <= 0.0:
		return 0.0
	var m := _multiplier("cooldown", String(b["type"]), String(stage.get("action", "")))
	return maxf(base * m, float(stage.get("cooldown_floor", 0.0)))


## What a stage gives per completion after modifiers, as rates (research can
## add, and add fractions: 0.25 copper per dig). Items research adds that the
## stage did not yield before are included.
func stage_yield(b: Dictionary, stage: Dictionary) -> Dictionary:
	var out := {}
	var base: Dictionary = stage.get("yield", {})
	for item: String in base:
		out[item] = float(base[item])
	for source: Object in modifiers:
		if source.has_method("yield_items"):
			for item: String in source.call("yield_items", String(b["type"]), String(stage.get("id", ""))):
				if not out.has(item):
					out[item] = 0.0
	for item: String in out.keys():
		var n := float(out[item])
		for source: Object in modifiers:
			if source.has_method("yield_bonus"):
				n += float(source.call("yield_bonus", String(b["type"]), String(stage.get("id", "")), item))
		if n > 0.0:
			out[item] = n
		else:
			out.erase(item)
	return out


## Whole items this stage hands over if it completes now: the rate plus what
## this building carries over, in thousandths, so fractional rates come out
## exactly (0.25 is one every fourth time, never by chance).
func whole_yield(b: Dictionary, stage: Dictionary) -> Dictionary:
	var out := {}
	var carry: Dictionary = b.get("carry", {})
	var rates := stage_yield(b, stage)
	for item: String in rates:
		var milli := int(round(float(rates[item]) * 1000.0)) + int(carry.get(item, 0))
		if milli >= 1000:
			out[item] = milli / 1000
	return out


func _take_yield(b: Dictionary, stage: Dictionary) -> Dictionary:
	var out := {}
	var carry: Dictionary = b.get("carry", {})
	var rates := stage_yield(b, stage)
	for item: String in rates:
		var milli := int(round(float(rates[item]) * 1000.0)) + int(carry.get(item, 0))
		var whole := milli / 1000
		if whole > 0:
			out[item] = whole
		if milli - whole * 1000 > 0:
			carry[item] = milli - whole * 1000
		else:
			carry.erase(item)
	b["carry"] = carry
	return out


func _multiplier(kind: String, type: String, action: String) -> float:
	var m := 1.0
	for source: Object in modifiers:
		m *= float(source.call("stage_multiplier", kind, type, action))
	return maxf(m, 0.0)


## What one full work cycle of this building takes and gives, for whoever is
## doing it (`time_multiplier` 1 for the player, the Momo multiplier for a
## Momo): {cycle_seconds, work_seconds, wait_seconds, yield {item: n}, per_day {item: n}}.
## Computed from the same stage rules the simulation runs -- the panels show
## this instead of working anything out themselves.
func cycle_estimate(b: Dictionary, time_multiplier: float = 1.0) -> Dictionary:
	var work := 0.0
	var wait := 0.0
	var produced := {}
	for st: Dictionary in stages(b):
		work += stage_seconds(b, st) * time_multiplier
		wait += stage_cooldown(b, st)
		var gives := stage_yield(b, st)
		for item: String in gives:
			produced[item] = float(produced.get(item, 0.0)) + float(gives[item])
	var cycle := work + wait
	var day_seconds := sim.clock.day_ms / 1000.0
	var per_day := {}
	for item: String in produced:
		per_day[item] = float(produced[item]) * day_seconds / maxf(cycle, 0.001)
	return {"cycle_seconds": cycle, "work_seconds": work, "wait_seconds": wait, "yield": produced, "per_day": per_day}


## The crop overlay (or other look) for the building's present state: the
## look of the stage it is waiting to do next. "" for none.
func look(b: Dictionary) -> String:
	var v := variety_def(String(b.get("type", "")), variety_of(b)) if variety_of(b) != BASE_VARIETY else {}
	var looks: Array = v.get("looks", type_def(b).get("cycle", {}).get("looks", []))
	if looks.is_empty():
		return ""
	return String(looks[int(b["stage"]) % looks.size()])


## Stages grouped by action (sow / water x3 / harvest): what the panel shows
## as cards. Each group: {action, label, icon, seconds, first, count}.
func action_groups(b: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list := stages(b)
	for i in list.size():
		var st: Dictionary = list[i]
		var action: String = st.get("action", st.get("id", ""))
		if not out.is_empty() and out[-1]["action"] == action:
			out[-1]["count"] = int(out[-1]["count"]) + 1
			continue
		out.append({"action": action, "label": st.get("label", ""), "icon": st.get("icon", ""), "seconds": float(st.get("seconds", 0)), "first": i, "count": 1})
	return out


func _complete_stage(b: Dictionary) -> void:
	var stage := current_stage(b)
	b["completed"] = int(b["completed"]) + 1
	var produced := _take_yield(b, stage)
	if not produced.is_empty():
		var inv: InventorySystem = sim.system(&"inventory")
		for item: String in produced:
			inv.add(item, int(produced[item]), "yield:" + String(b["type"]))
		sim.bus.emit(&"produced", {"id": b["id"], "type": b["type"], "items": produced.duplicate()})
	b["stage"] = (int(b["stage"]) + 1) % maxi(stages(b).size(), 1)
	var cooldown := int(round(stage_cooldown(b, stage) * 1000.0))
	if cooldown > 0:
		b["state"] = COOLDOWN
		b["ready_at"] = sim.now_ms() + cooldown
		b["token"] = int(b["token"]) + 1
		sim.scheduler.schedule(int(b["ready_at"]), COOLDOWN_DONE, {"id": b["id"], "token": b["token"]})
	else:
		b["state"] = IDLE
	var worker := int(b.get("worker", 0))
	b["worker"] = 0
	sim.bus.emit(&"task_completed", {"id": b["id"], "stage": stage.get("id", ""), "type": b["type"], "worker": worker})
	if b["state"] == IDLE:
		sim.bus.emit(&"building_idle", {"id": b["id"]})


func _size(type: String) -> Vector2i:
	var s: Array = sim.data.building_type(type).get("size", [1, 1])
	return Vector2i(int(s[0]), int(s[1]))


# --- persistence --------------------------------------------------------------------

func save_state() -> Dictionary:
	var list: Array = []
	for id: int in ids():
		list.append(buildings[id].duplicate(true))
	return {"next_id": next_id, "buildings": list}


func load_state(state: Dictionary) -> void:
	buildings.clear()
	next_id = int(state.get("next_id", 1))
	for raw: Dictionary in state.get("buildings", []):
		var b := raw.duplicate(true)
		for k: String in ["id", "stage", "task_start", "task_end", "ready_at", "token", "completed", "build_start", "build_end", "worker"]:
			b[k] = int(b.get(k, 0))
		var carry := {}
		var raw_carry: Dictionary = b.get("carry", {})
		for item: String in raw_carry:
			carry[item] = int(raw_carry[item])
		b["carry"] = carry
		var paid: Dictionary = b.get("paid", {})
		var items := {}
		for item: String in paid.get("items", {}):
			items[item] = int(paid["items"][item])
		b["paid"] = {"money": int(paid.get("money", 0)), "items": items}
		buildings[b["id"]] = b
