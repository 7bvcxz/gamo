extends SceneTree

## C, C+, E and E+ played for fifteen minutes of play time by a scripted
## player in the real frame with the 15-minute test on (Step 99) -- the same
## checkpoints (0, 3, 7, 10, 15 minutes) a person's run keeps for
## play15.html, made by the same code (LabHost.t15_record). C and C+ are
## tapped in the rock's middle at a natural 2.5 taps a second; every variant
## buys REACTION seconds after it can pay. Written to web/play15/runs15.json
## for the test page.
##
## Objective technical and pacing evidence only: a robot's fifteen minutes
## say nothing about whether a person's were fun, tiring or boring.
##
##   godot --headless --path momonium/experiments --script res://tools/runs15.gd -- [--out web/play15/runs15.json]

const STEP := 0.05
const REACTION := 1.5
const SECONDS := 900.0
## [id, taps a second (0: none), what it stands for]
const RUNS: Array[Array] = [
	["rock", 2.5, "C (baseline)"],
	["rock-plus", 2.5, "C+ (improved)"],
	["tycoon", 0.0, "E (baseline)"],
	["tycoon-plus", 0.0, "E+ (improved)"],
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "res://web/play15/runs15.json"
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_path = args[i + 1]
	root.size = Vector2i(720, 1558)
	var app: LabApp = (load("res://lab/main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	app.route["t15"] = true
	var rows: Array = []
	for run: Array in RUNS:
		app.open(String(run[0]))
		await process_frame
		var host: LabHost = app.host
		host.set_process(false)
		var e := host.experiment
		var t := 0.0
		var tap_clock := 0.0
		var ready_since := -1.0
		var rate := float(run[1])
		while t < SECONDS:
			host.step(STEP)
			t += STEP
			if rate > 0.0:
				tap_clock += STEP
				if tap_clock >= 1.0 / rate:
					tap_clock -= 1.0 / rate
					var rr: Array = e.state()["rock_rect"]
					e.call("tap_at", e.get_global_transform().affine_inverse() * Vector2(float(rr[0]) + float(rr[2]) * 0.5, float(rr[1]) + float(rr[3]) * 0.5))
			if bool(e.action_info().get("affordable", false)):
				if ready_since < 0.0:
					ready_since = t
				elif t - ready_since >= REACTION:
					host.press_action()
					ready_since = -1.0
			else:
				ready_since = -1.0
		var record := host.t15_record()
		record["label"] = run[2]
		record["taps_per_second"] = rate
		record["reveals"] = _reveals(host.session.summary(false), e.state())
		rows.append(record)
		print("%s: %s" % [run[2], JSON.stringify(record["at"]["15"]["probe"])])
		app.back()
		await process_frame
	var doc := {"_doc": "tools/runs15.gd: a scripted player, %d s of play per variant (C/C+ tapped 2.5 a second; every variant buys %.1f s after it can pay), the 15-minute test's own checkpoints. Objective technical and pacing evidence, never a measure of fun, fatigue or boredom." % [int(SECONDS), REACTION],
		"runs": rows}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	app.queue_free()
	for i in 3:
		await process_frame
	quit()


## When something new came into view (tools/c_runs.gd and e_runs.gd count it
## the same way): C+ a new pickaxe tier or a great rock broken, C a rock it
## had not shown before; E and E+ an upgrade that is not the sparkle-only
## Golden Line. The count and the longest stretch without one.
static func _reveals(s: Dictionary, st: Dictionary) -> Dictionary:
	var times: Array[float] = []
	var plus := st.has("kind")
	for u: Dictionary in s["upgrades"]:
		if st.has("delivered"):
			if String(u.get("show", "")) != "sparkle":
				times.append(float(u["t_s"]))
		elif not plus or bool(u.get("milestone", false)):
			times.append(float(u["t_s"]))
	for m: Dictionary in s["milestones"]:
		if String(m["name"]) == "break" and ((plus and bool(m.get("big", false))) or (not plus and int(m["rock"]) < RockLevels.GOAL)):
			times.append(float(m["t_s"]))
	times.sort()
	var longest := 0.0
	var prev := 0.0
	for x: float in times:
		longest = maxf(longest, x - prev)
		prev = x
	longest = maxf(longest, SECONDS - prev)
	return {"count": times.size(), "longest_without_s": snappedf(longest, 0.1), "times_s": times}
