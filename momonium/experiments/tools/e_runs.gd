extends SceneTree

## E and E+ (and E+'s grand alternative) run for thirty minutes of play time
## in the real frame, buying Improve Line 1.5 s after it can pay -- like
## tools/c_runs.gd for C -- summed up at 3, 15 and 30 minutes for the tracks
## page (web/tracks/e_runs.json, Step 98). Objective throughput and pacing:
## the first delivery, the level, deliveries and coins a minute, the waits
## between upgrades, how often something new appears (an upgrade that is not
## E's sparkle-only Golden Line), and at each mark what limits the line (the
## slowest of hopper, machine and belt per lane) and how many raw items queue
## nose to tail against the machine (backpressure). Says nothing about
## whether watching it is a delight.
##
##   godot --headless --path momonium/experiments --script res://tools/e_runs.gd -- [--out web/tracks/e_runs.json]

const STEP := 0.05
const REACTION := 1.5
const SECONDS := 1800.0
const MARKS: Array[float] = [180.0, 900.0, 1800.0]
## [id, alternative, what it stands for]
const RUNS: Array[Array] = [
	["tycoon", "", "E"],
	["tycoon-plus", "", "E+"],
	["tycoon-plus", "grand", "E+ grand (?alt=grand)"],
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "res://web/tracks/e_runs.json"
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_path = args[i + 1]
	root.size = Vector2i(720, 1280)
	var app: LabApp = (load("res://lab/main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	var rows: Array = []
	for run: Array in RUNS:
		app.route["alt"] = String(run[1])
		app.open(String(run[0]))
		await process_frame
		var host: LabHost = app.host
		host.set_process(false)
		var e := host.experiment
		var t := 0.0
		var ready_since := -1.0
		var first_delivery := -1.0
		var per_min: Array[int] = []
		var last_delivered := 0
		var coins_at: Dictionary = {}
		while t < SECONDS:
			host.step(STEP)
			t += STEP
			# The experiment's own numbers, read directly (state() every step
			# would cost more than the line).
			var d := (e.get("line") as TycoonLine).delivered
			if d > 0 and first_delivery < 0.0:
				first_delivery = t
			var minute := int(t / 60.0)
			while per_min.size() <= minute:
				per_min.append(0)
			per_min[mini(minute, per_min.size() - 1)] += d - last_delivered
			last_delivered = d
			for mark: float in MARKS:
				if not coins_at.has(mark) and t >= mark - 0.001:
					var st: Dictionary = e.state()
					coins_at[mark] = {"level": st["level"], "delivered": d, "earned": st["earned"], "name": st["name"]}
					coins_at[mark].merge(_limits(e.get("line")))
			if bool(e.action_info().get("affordable", false)):
				if ready_since < 0.0:
					ready_since = t
				elif t - ready_since >= REACTION:
					host.press_action()
					ready_since = -1.0
			else:
				ready_since = -1.0
		var s := host.session.summary()
		var ups: Array[float] = []
		var reveals: Array[float] = []
		for u: Dictionary in s["upgrades"]:
			ups.append(float(u["t_s"]))
			if String(u.get("show", "")) != "sparkle":
				reveals.append(float(u["t_s"]))
		var at := {}
		var prev := {"delivered": 0, "earned": 0}
		var prev_t := 0.0
		for mark: float in MARKS:
			var a: Dictionary = coins_at.get(mark, {})
			var span := (mark - prev_t) / 60.0
			at["%d" % int(mark / 60.0)] = {"level": a.get("level"), "name": a.get("name"), "upgrades": _count(ups, mark), "delivered": a.get("delivered"),
				"deliveries_a_min_in_span": snappedf(float(int(a.get("delivered", 0)) - int(prev["delivered"])) / span, 0.1),
				"coins_a_min_in_span": snappedf(float(int(a.get("earned", 0)) - int(prev["earned"])) / span, 0.1),
				"bottleneck": a.get("bottleneck"), "per_lane_a_min": a.get("per_lane_a_min"), "queued": a.get("queued")}
			prev = a
			prev_t = mark
		var st := e.state()
		rows.append({"id": run[0], "alt": run[1], "label": run[2], "at": at, "first_delivery_s": snappedf(first_delivery, 0.1),
			"first_upgrade_s": s["first_upgrade_s"],
			"longest_upgrade_wait_s": {"0-3": _longest(ups, 0.0, 180.0), "3-15": _longest(ups, 180.0, 900.0), "15-30": _longest(ups, 900.0, 1800.0)},
			"longest_reveal_wait_s": {"0-15": _longest(reveals, 0.0, 900.0), "15-30": _longest(reveals, 900.0, 1800.0)},
			"reveals": reveals.size(), "deliveries_by_minute": per_min.slice(0, 30), "unique_deliveries": bool(st.get("unique_deliveries", true)),
			"told": _told(s["milestones"]),
			"final": {"level": st["level"], "name": st["name"], "lanes": st["lanes"], "delivered": st["delivered"], "earned": st["earned"]}})
		print("%s: %s" % [run[2], JSON.stringify(at)])
		app.back()
		await process_frame
	app.route["alt"] = ""
	var doc := {"_doc": "tools/e_runs.gd: %d s of play per run, buying %.1f s after it can pay. Objective throughput and pacing, never a measure of delight." % [int(SECONDS), REACTION],
		"marks_s": MARKS, "runs": rows}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	app.queue_free()
	for i in 3:
		await process_frame
	quit()


## The slowest stage of a lane (items a minute) and the raw items waiting
## for the machine on all lanes now.
static func _limits(line: TycoonLine) -> Dictionary:
	var rates := {"hopper": 60.0 / line.spawn, "machine": 60.0 * float(line.arms) / line.process, "belt": 60.0 * line.speed / TycoonLine.SPACING}
	var slowest := "hopper"
	for k: String in rates:
		if float(rates[k]) < float(rates[slowest]):
			slowest = k
	# Held: raw items packed nose to tail against the machine's near side.
	var queued := 0
	for lane in line.lanes:
		var raw := line.items.filter(func(it: Dictionary) -> bool: return int(it["lane"]) == lane and not bool(it["done"]) and not bool(it["in"]))
		raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["x"]) > float(b["x"]))
		var front := TycoonLine.MACHINE_AT - TycoonLine.SPACING * 0.5
		for it: Dictionary in raw:
			if float(it["x"]) < front - 0.001:
				break
			queued += 1
			front = float(it["x"]) - TycoonLine.SPACING
	return {"bottleneck": slowest, "per_lane_a_min": snappedf(float(rates[slowest]), 0.1), "queued": queued}


## E+'s "before -> after" after upgrades that change how many the line
## makes: how many were told, and how many said less than before.
static func _told(milestones: Array) -> Dictionary:
	var told := 0
	var lower: Array = []
	for m: Dictionary in milestones:
		if String(m["name"]) != "output":
			continue
		told += 1
		if float(m["after_per_min"]) < float(m["before_per_min"]):
			lower.append("%s %s -> %s" % [m["upgrade"], m["before_per_min"], m["after_per_min"]])
	return {"told": told, "lower": lower}


static func _count(a: Array[float], until: float) -> int:
	return a.filter(func(x: float) -> bool: return x <= until).size()


static func _longest(a: Array[float], lo: float, hi: float) -> float:
	var best := 0.0
	var prev := 0.0
	for x: float in a:
		if x > hi:
			break
		if x > lo:
			best = maxf(best, x - prev)
		prev = x
	return snappedf(maxf(best, hi - prev), 0.1)
