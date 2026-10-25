class_name AnalyticsSystem
extends SimSystem

## What the island did, day by day, written down from what happened -- never
## a counter of its own that could drift from the world.
##
## It listens: money in and out (by category), items made by work and used by
## furnaces, items sold, every stage a building finished and how long it
## took, every stage a Momo worked. And every `sample_seconds` (a scheduled
## event) it notes the power supply and draw, and which buildings stand idle
## and why (missing inputs, store full, no crew, no power). Each day's book
## closes at dawn; `keep_days` are kept.

const SAMPLE := "analytics.sample"

## The day being written: see _blank().
var today: Dictionary = {}
## Closed days, oldest first.
var days: Array = []


func _init() -> void:
	key = &"analytics"


func handled_events() -> PackedStringArray:
	return PackedStringArray([SAMPLE])


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


func on_new_game() -> void:
	days.clear()
	today = _blank(sim.clock.day_number())
	_schedule()


func _schedule() -> void:
	sim.schedule_in(int(sim.data.get_float("balance", "analytics.sample_seconds", 10.0) * 1000.0), SAMPLE)


static func _blank(day: int) -> Dictionary:
	return {"day": day, "income": {}, "expense": {}, "made": {}, "used": {}, "sold": {}, "buildings": {},
		"momo_ms": {}, "momo_stages": {}, "samples": 0, "supply": 0.0, "demand": 0.0, "short": 0, "blocked": {}, "blocked_by": {}}


static func _add(d: Dictionary, key: Variant, n: Variant) -> void:
	d[key] = d.get(key, 0) + n


func _on_event(type: StringName, p: Dictionary) -> void:
	if today.is_empty():
		return
	match type:
		&"money_changed":
			var cat := String(p.get("reason", "")).split(":")[0]
			var delta := int(p.get("delta", 0))
			if delta > 0:
				_add(today["income"], cat, delta)
			elif delta < 0:
				_add(today["expense"], cat, -delta)
		&"inventory_changed":
			var why := String(p.get("reason", ""))
			var delta := int(p.get("delta", 0))
			if delta > 0 and why.begins_with("yield:"):
				_add(today["made"], String(p["item"]), delta)
			elif delta < 0 and why.begins_with("consume:"):
				_add(today["used"], String(p["item"]), -delta)
		&"sold":
			for item: String in p.get("items", {}):
				_add(today["sold"], item, int(p["items"][item]))
		&"task_completed":
			var bs: BuildingSystem = sim.system(&"buildings")
			var b := bs.get_building(int(p["id"]))
			var row: Dictionary = today["buildings"].get(int(p["id"]), {"stages": 0, "busy_ms": 0, "made": {}})
			var took := maxi(int(b.get("task_end", 0)) - int(b.get("task_start", 0)), 0)
			row["stages"] = int(row["stages"]) + 1
			row["busy_ms"] = int(row["busy_ms"]) + took
			today["buildings"][int(p["id"])] = row
			var worker := int(p.get("worker", 0))
			if worker > 0:
				_add(today["momo_ms"], worker, took)
				_add(today["momo_stages"], worker, 1)
		&"produced":
			var row: Dictionary = today["buildings"].get(int(p["id"]), {"stages": 0, "busy_ms": 0, "made": {}})
			for item: String in p.get("items", {}):
				_add(row["made"], item, int(p["items"][item]))
			today["buildings"][int(p["id"])] = row


func handle_event(type: String, _data: Dictionary) -> void:
	if type != SAMPLE:
		return
	_schedule()
	sample()


## One look at the island now: power, and who stands idle and why.
func sample() -> void:
	today["samples"] = int(today["samples"]) + 1
	var power: PowerSystem = sim.system(&"power")
	if power != null:
		var s := power.supply()
		var d := power.demand()
		today["supply"] = float(today["supply"]) + s
		today["demand"] = float(today["demand"]) + d
		if d > s + 0.0001:
			today["short"] = int(today["short"]) + 1
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids():
		var b := bs.get_building(id)
		var block := bs.blocked(b)
		var why := ""
		if block.has("missing"):
			why = "missing"
		elif block.has("full"):
			why = "full"
		elif block.has("crew"):
			why = "crew"
		elif b["state"] == BuildingSystem.IDLE and not bs.stages(b).is_empty():
			var power_block := power.start_blocker(String(b["type"])) if power != null else ""
			if power_block != "":
				why = "power"
		if why != "":
			_add(today["blocked"], why, 1)
			_add(today["blocked_by"], id, 1)


func on_day_started(day: int) -> void:
	if not today.is_empty() and int(today["day"]) != day:
		days.append(today)
		var keep := sim.data.get_int("balance", "analytics.keep_days", 30)
		while days.size() > keep:
			days.pop_front()
	today = _blank(day)


# --- reading ------------------------------------------------------------------------

## The last `n` closed days (oldest first).
func last(n: int) -> Array:
	return days.slice(maxi(days.size() - n, 0))


## Sum of a per-key table across days: {key: total}.
static func total(day_list: Array, field: String) -> Dictionary:
	var out := {}
	for d: Dictionary in day_list:
		for k: Variant in d.get(field, {}):
			out[k] = out.get(k, 0) + d[field][k]
	return out


## A building's rate over the last `n` closed days: per day stages, items
## made, and the share of the day it was working.
func building_rate(id: int, n: int = 7) -> Dictionary:
	var ds := last(n)
	if ds.is_empty():
		return {"days": 0, "stages": 0.0, "made": 0.0, "utilization": 0.0}
	var stages := 0
	var made := 0
	var busy := 0
	for d: Dictionary in ds:
		var row: Dictionary = d["buildings"].get(id, {})
		stages += int(row.get("stages", 0))
		busy += int(row.get("busy_ms", 0))
		for item: Variant in row.get("made", {}):
			made += int(row["made"][item])
	var day_ms := float(sim.clock.day_ms)
	return {"days": ds.size(), "stages": float(stages) / ds.size(), "made": float(made) / ds.size(),
		"utilization": clampf(float(busy) / (day_ms * ds.size()), 0.0, 1.0)}


## Average share of the day each Momo spent working, over the last `n` days.
func momo_utilization(n: int = 7) -> float:
	var ds := last(n)
	var momos: MomoSystem = sim.system(&"momo")
	if ds.is_empty() or momos.ids().is_empty():
		return 0.0
	var busy := 0
	for d: Dictionary in ds:
		for m: Variant in d["momo_ms"]:
			busy += int(d["momo_ms"][m])
	return clampf(float(busy) / (float(sim.clock.day_ms) * ds.size() * momos.ids().size()), 0.0, 1.0)


## Output per day of all buildings of a type, before and after a research
## finished: the `n` full days on each side of the day it was done.
func before_after(type: String, research_id: String, n: int = 5) -> Dictionary:
	var research: ResearchSystem = sim.system(&"research")
	if research == null or not research.completed.has(research_id):
		return {}
	var done_day := 1 + int(research.completed[research_id]) / sim.clock.day_ms
	var bs: BuildingSystem = sim.system(&"buildings")
	var before: Array[float] = []
	var after: Array[float] = []
	for d: Dictionary in days:
		var made := 0
		for id: Variant in d["buildings"]:
			if String(bs.get_building(int(id)).get("type", "")) == type:
				for item: Variant in d["buildings"][id].get("made", {}):
					made += int(d["buildings"][id]["made"][item])
		if int(d["day"]) < done_day and int(d["day"]) >= done_day - n:
			before.append(made)
		elif int(d["day"]) > done_day and int(d["day"]) <= done_day + n:
			after.append(made)
	var avg := func(a: Array[float]) -> float:
		var s := 0.0
		for x: float in a:
			s += x
		return s / a.size() if not a.is_empty() else 0.0
	return {"before": avg.call(before), "after": avg.call(after), "days_before": before.size(), "days_after": after.size()}


## A Momo's stages a day on the closed days before and after `since_ms`
## (a routing change): {before, after, days_before, days_after}.
func momo_before_after(momo: int, since_ms: int, n: int = 5) -> Dictionary:
	var day := 1 + since_ms / sim.clock.day_ms
	var before: Array[int] = []
	var after: Array[int] = []
	for d: Dictionary in days:
		var stages := int(d.get("momo_stages", {}).get(momo, 0))
		if int(d["day"]) < day and int(d["day"]) >= day - n:
			before.append(stages)
		elif int(d["day"]) > day and int(d["day"]) <= day + n:
			after.append(stages)
	var avg := func(a: Array[int]) -> float:
		var s := 0
		for x: int in a:
			s += x
		return float(s) / a.size() if not a.is_empty() else 0.0
	return {"before": avg.call(before), "after": avg.call(after), "days_before": before.size(), "days_after": after.size()}


func save_state() -> Dictionary:
	return {"today": _out(today), "days": days.map(func(d: Dictionary) -> Dictionary: return _out(d))}


func load_state(state: Dictionary) -> void:
	days.clear()
	for d: Dictionary in state.get("days", []):
		days.append(_in(d))
	var t: Dictionary = state.get("today", {})
	today = _in(t) if not t.is_empty() else _blank(sim.clock.day_number())
	if sim.scheduler.events_of(SAMPLE).is_empty():
		_schedule()


## JSON keys are strings: building and Momo ids go out as strings and come
## back as ints; counts come back as ints.
static func _out(d: Dictionary) -> Dictionary:
	var c := d.duplicate(true)
	for field: String in ["buildings", "momo_ms", "momo_stages", "blocked_by"]:
		var m := {}
		for k: Variant in c.get(field, {}):
			m[str(k)] = c[field][k]
		c[field] = m
	return c


static func _in(d: Dictionary) -> Dictionary:
	var c := _blank(int(d.get("day", 1)))
	for field: String in ["income", "expense", "made", "used", "sold", "blocked"]:
		for k: String in d.get(field, {}):
			c[field][k] = int(d[field][k])
	for field: String in ["momo_ms", "momo_stages", "blocked_by"]:
		for k: String in d.get(field, {}):
			c[field][int(k)] = int(d[field][k])
	for k: String in d.get("buildings", {}):
		var r: Dictionary = d["buildings"][k]
		var made := {}
		for item: String in r.get("made", {}):
			made[item] = int(r["made"][item])
		c["buildings"][int(k)] = {"stages": int(r.get("stages", 0)), "busy_ms": int(r.get("busy_ms", 0)), "made": made}
	c["samples"] = int(d.get("samples", 0))
	c["supply"] = float(d.get("supply", 0.0))
	c["demand"] = float(d.get("demand", 0.0))
	c["short"] = int(d.get("short", 0))
	return c
