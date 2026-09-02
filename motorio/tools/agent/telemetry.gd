extends RefCounted

## The run's memory: milestones with factory snapshots, behaviour time buckets,
## the WAIT ledger with its missed-automation verdicts, confusion events, and
## the failure snapshot. Everything lands in one dictionary and one JSON file,
## because the batch summariser reads files and nothing else.

var main: Node2D
var sim
var seed_value := 0
var mode := "qa"

var milestones: Dictionary = {}          # name -> {t, factory}
var behavior: Dictionary = {}            # activity -> seconds
var waits: Array[Dictionary] = []        # {t, reason, seconds, missed, note}
var confusions: Array[Dictionary] = []   # {t, reason, note}
var stuck_events: Array[Dictionary] = [] # {t, level, note}
var improvements := 0
var rebuilds := 0
var log_lines: Array[String] = []
var clock_ref: Callable

func _init(main_ref: Node2D, seed_v: int, mode_v: String, clock_getter: Callable) -> void:
	main = main_ref
	sim = main.sim
	seed_value = seed_v
	mode = mode_v
	clock_ref = clock_getter

func now() -> float:
	return float(clock_ref.call())

func tick(activity: String, dt: float) -> void:
	behavior[activity] = float(behavior.get(activity, 0.0)) + dt

func note(line: String) -> void:
	log_lines.append("%s %s" % [_mmss(now()), line])

func milestone(id: String) -> void:
	if milestones.has(id):
		return
	milestones[id] = {"t": now(), "factory": factory_state()}
	note("MILESTONE " + id)

func wait(reason: String, seconds: float, missed := false, detail := "") -> void:
	# Coalesce a continuing wait for the same reason: one decision, one row.
	if not waits.is_empty():
		var last: Dictionary = waits[-1]
		if String(last["reason"]) == reason and now() - (float(last["t"]) + float(last["seconds"])) < 1.0:
			last["seconds"] = float(last["seconds"]) + seconds
			return
	waits.append({"t": now(), "reason": reason, "seconds": seconds,
		"missed": missed, "note": detail})

func mark_missed_automation(detail: String) -> void:
	if not waits.is_empty():
		waits[-1]["missed"] = true
		waits[-1]["note"] = detail
	note("MISSED_AUTOMATION " + detail)

func confusion(reason: String, detail: String) -> void:
	confusions.append({"t": now(), "reason": reason, "note": detail})
	note("CONFUSION %s %s" % [reason, detail])

func stuck(level: int, detail: String) -> void:
	stuck_events.append({"t": now(), "level": level, "note": detail})
	note("STUCK L%d %s" % [level, detail])

## Production and fleet, read from the meters the HUD itself reads.
func factory_state() -> Dictionary:
	var counts: Dictionary = {}
	for cell: Vector2i in sim.machines:
		var key: String = String(Defs.machine(sim.machines[cell].type).get("key", "?"))
		counts[key] = int(counts.get(key, 0)) + 1
	return {
		"heatstone_per_min": snappedf(float(sim.gain_rate.get(Defs.ITEM_HEATSTONE, 0.0)), 0.1),
		"copper_per_min": snappedf(float(sim.gain_rate.get(Defs.ITEM_COPPER, 0.0)), 0.1),
		"iron_per_min": snappedf(float(sim.gain_rate.get(Defs.ITEM_IRON, 0.0)), 0.1),
		"cats": sim.cats.size(),
		"miners": int(counts.get("miner", 0)),
		"miners_mk2": int(counts.get("miner_mk2", 0)),
		"generators": int(counts.get("generator", 0)),
		"belts": int(counts.get("belt", 0)),
		"splitters": int(counts.get("splitter", 0)),
		"manufacturers": int(counts.get("manufacturer", 0)),
		"assemblers": int(counts.get("assembler", 0)),
		"power_capacity": snappedf(sim.power_capacity, 0.1),
		"power_demand": snappedf(sim.power_draw, 0.1),
		"power_supply_ratio": 1.0 if sim.power_draw <= 0.0
			else snappedf(clampf(sim.power_capacity / sim.power_draw, 0.0, 1.0), 0.01),
		"base_level_shown": Defs.base_level_shown(sim.base_level),
		"stones_in": sim.stones_in,
	}

## Everything a person needs to see what the agent saw when it died.
func failure_snapshot(goal: String, action: String, reason: String) -> Dictionary:
	var nearby: Array[String] = []
	var at: Vector2i = main.player.cell()
	for cell: Vector2i in sim.machines:
		if Vector2(cell - at).length() <= 6.0:
			nearby.append("%s@%s" % [String(Defs.machine(sim.machines[cell].type).get("key", "?")), str(cell)])
	var stock: Dictionary = {}
	for item_id: int in sim.stock:
		if int(sim.stock[item_id]) > 0:
			stock[Defs.item_short(item_id)] = int(sim.stock[item_id])
	return {
		"position": str(at), "goal": goal, "action": action, "reason": reason,
		"inventory": stock, "base_level_shown": Defs.base_level_shown(sim.base_level),
		"warm_radius": sim.warm_radius, "power": [sim.power_capacity, sim.power_draw],
		"cats": sim.cats.size(), "nearby": nearby,
		"carried": {"cat": sim.carried_cat != null, "frozen": sim.carried_frozen,
			"kit": sim.carried_kit},
	}

func to_record(result: String, failure_kind: String, failure_reason: String,
		snapshot: Dictionary, extra: Dictionary) -> Dictionary:
	var mile_out: Dictionary = {}
	for id: String in milestones:
		mile_out[id] = {"t": snappedf(float(milestones[id]["t"]), 0.1),
			"factory": milestones[id]["factory"]}
	var record := {
		"seed": seed_value, "mode": mode, "result": result,
		"play_time": snappedf(now(), 0.1),
		"failure_kind": failure_kind, "failure_reason": failure_reason,
		"milestones": mile_out,
		"behavior": behavior.duplicate(),
		"waits": waits, "confusions": confusions, "stuck_events": stuck_events,
		"factory_improvements": improvements, "factory_rebuilds": rebuilds,
		"final_factory": factory_state(),
		"snapshot": snapshot,
	}
	record.merge(extra)
	return record

func write(directory: String, record: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var base := "%s/seed_%d" % [directory, seed_value]
	var json := FileAccess.open(base + ".json", FileAccess.WRITE)
	json.store_string(JSON.stringify(record, "  "))
	json.close()
	var log_file := FileAccess.open(base + ".log", FileAccess.WRITE)
	for line in log_lines:
		log_file.store_line(line)
	log_file.close()

func _mmss(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
