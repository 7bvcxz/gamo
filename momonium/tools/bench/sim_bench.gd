extends SceneTree

## Simulation benchmark (headless): a big island run for simulated hours.
##
##   godot --headless --path momonium --script res://tools/bench/sim_bench.gd [-- --hours 2 --size 30]
##
## Builds StressIsland (a size x size island, a building on one tile in three
## of the four kinds the player places, many Momo on zones of 0-16 tiles with
## mixed routes), runs it, and prints wall time per simulated hour, events
## handled, memory, and a hash of the result -- the hash must not change when
## the code is only made faster. --check compares with tools/bench/budgets.json.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var hours := 2.0
	var side := 30
	var momos := -1
	var offline := 0.0
	var check := false
	for i in args.size():
		match args[i]:
			"--hours": hours = float(args[i + 1])
			"--size": side = int(args[i + 1])
			"--momos": momos = int(args[i + 1])
			"--offline": offline = float(args[i + 1])
			"--check": check = true
	var r := run(side, hours, momos)
	print("bench: %dx%d island, %d buildings, %d Momo, %.1f simulated h" % [side, side, r["buildings"], r["momos"], hours])
	print("bench: %.1f ms wall per simulated hour, %d events, %.1f MB static" % [r["ms_per_hour"], r["events"], r["mb"]])
	print("bench: result hash %s" % r["hash"])
	var o := {}
	if offline > 0.0:
		o = catch_up(side, offline, momos)
		print("bench: offline %.1f h caught up in %.1f s wall, %d events, capped %s" % [offline, o["seconds"], o["events"], o["capped"]])
	var failed := 0
	if check:
		failed = _check(side, hours, r, o)
	quit(failed)


## Coming back after `hours` away: the catch-up's wall time.
static func catch_up(side: int, hours: float, momos: int = -1) -> Dictionary:
	var sim := build(side, momos)
	var events := [0]
	sim.bus.emitted.connect(func(_t: StringName, _p: Dictionary) -> void: events[0] = int(events[0]) + 1)
	var t0 := Time.get_ticks_usec()
	var rep := OfflineProgress.catch_up(sim, int(hours * 3600000.0))
	return {"seconds": (Time.get_ticks_usec() - t0) / 1000000.0, "events": events[0], "capped": bool(rep["capped_events"]) or bool(rep["capped_time"])}


## Compares with tools/bench/budgets.json (the entry for this size): the
## result hash must match exactly, the times stay within budget.
static func _check(side: int, hours: float, r: Dictionary, o: Dictionary) -> int:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bench/budgets.json"))
	var b: Dictionary = all.get("sim", {}).get(str(side), {})
	if b.is_empty():
		print("bench: no budget for a %dx%d island" % [side, side])
		return 1
	var bad := 0
	if is_equal_approx(hours, float(b.get("hours", 1.0))) and str(r["hash"]) != str(b["hash"]):
		print("bench: FAIL result changed: %s, budget file says %s" % [r["hash"], b["hash"]])
		bad += 1
	if float(r["ms_per_hour"]) > float(b["ms_per_hour"]):
		print("bench: FAIL %.0f ms per simulated hour, budget %.0f" % [r["ms_per_hour"], b["ms_per_hour"]])
		bad += 1
	if not o.is_empty() and b.has("offline_seconds") and float(o["seconds"]) > float(b["offline_seconds"]):
		print("bench: FAIL offline catch-up %.1f s, budget %.1f" % [o["seconds"], b["offline_seconds"]])
		bad += 1
	print("bench: budget %s" % ("OK" if bad == 0 else "FAILED"))
	return bad


static func build(side: int, momos: int = -1) -> Simulation:
	return StressIsland.build(side, momos)


static func run(side: int, hours: float, momos: int = -1) -> Dictionary:
	var sim := build(side, momos)
	var events := [0]
	sim.bus.emitted.connect(func(_t: StringName, _p: Dictionary) -> void: events[0] = int(events[0]) + 1)
	var t0 := Time.get_ticks_usec()
	sim.advance_ms(int(hours * 3600000.0))
	var wall := (Time.get_ticks_usec() - t0) / 1000.0
	var snap := sim.snapshot()
	snap.erase("analytics")
	return {"buildings": (sim.system(&"buildings") as BuildingSystem).ids().size(), "momos": (sim.system(&"momo") as MomoSystem).ids().size(),
		"ms_per_hour": wall / hours, "events": events[0], "mb": OS.get_static_memory_usage() / 1048576.0,
		"hash": str(JSON.stringify(snap).hash())}
