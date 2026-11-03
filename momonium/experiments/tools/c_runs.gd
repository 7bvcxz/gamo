extends SceneTree

## C and C+ played for thirty minutes of play time by a scripted player at
## several tapping rates -- the real experiments in the real frame, like
## tools/selftest.gd -- summed up at 3, 15 and 30 minutes for the tracks page
## (web/tracks/c_runs.json, Step 96). Objective pacing only: when upgrades,
## breaks and new sights come, how long the waits are, how many taps it
## takes. A robot tapping for thirty minutes says nothing about a person's
## hand or fun.
##
##   godot --headless --path momonium/experiments --script res://tools/c_runs.gd -- [--out web/tracks/c_runs.json]
##
## The player taps the rock's middle at the run's rate and buys Pickaxe Power
## REACTION seconds after it can pay.

const STEP := 0.05
const REACTION := 1.5
const SECONDS := 1800.0
const MARKS: Array[float] = [180.0, 900.0, 1800.0]
## [id, alternative, taps a second, what it stands for]
const RUNS: Array[Array] = [
	["rock", "", 2.5, "C, natural tapping"],
	["rock", "", 1.5, "C, a tired hand"],
	["rock-plus", "", 2.5, "C+, natural tapping"],
	["rock-plus", "", 1.5, "C+, a tired hand"],
	["rock-plus", "", 4.0, "C+, eager tapping"],
	["rock-plus", "light", 1.5, "C+ light (?alt=light), a tired hand"],
	["rock-plus", "light", 2.5, "C+ light (?alt=light), natural tapping"],
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "res://web/tracks/c_runs.json"
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
		var tap_clock := 0.0
		var ready_since := -1.0
		var rate := float(run[2])
		while t < SECONDS:
			host.step(STEP)
			t += STEP
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
		var row := _sum_up(host.session.summary(), e.state())
		row["id"] = run[0]
		row["alt"] = run[1]
		row["taps_per_second"] = rate
		row["label"] = run[3]
		rows.append(row)
		print("%s %s %.1f/s: %s" % [run[0], run[1], rate, JSON.stringify(row["at"])])
		app.back()
		await process_frame
	var doc := {"_doc": "tools/c_runs.gd: a scripted player, %d s of play per run (buys %.1f s after it can pay). Objective pacing, never a measure of fun or of a person's hand." % [int(SECONDS), REACTION],
		"marks_s": MARKS, "runs": rows}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	app.queue_free()
	for i in 3:
		await process_frame
	quit()


## The run at each mark, and the waits between what changes.
static func _sum_up(s: Dictionary, st: Dictionary) -> Dictionary:
	# What there is to see that was not there before. C+: a new pickaxe (a
	# tier) and a new kind of rock (when a great one breaks). C: every level
	# tints the pickaxe anew, and each of its ten rocks is a new one until the
	# Giant Crystal comes back again and again.
	var plus := st.has("kind")
	var ups: Array[float] = []
	var reveals: Array[float] = []
	for u: Dictionary in s["upgrades"]:
		ups.append(float(u["t_s"]))
		if not plus or bool(u.get("milestone", false)):
			reveals.append(float(u["t_s"]))
	var breaks: Array[float] = []
	for m: Dictionary in s["milestones"]:
		if String(m["name"]) != "break":
			continue
		breaks.append(float(m["t_s"]))
		if (plus and bool(m.get("big", false))) or (not plus and int(m["rock"]) < RockLevels.GOAL):
			reveals.append(float(m["t_s"]))
	reveals.sort()
	var at := {}
	for mark: float in MARKS:
		var snap: Variant = s.get("at_%dmin" % int(mark / 60.0))
		var metrics: Dictionary = (snap as Dictionary)["metrics"] if snap is Dictionary else s["metrics"]
		at["%d" % int(mark / 60.0)] = {"upgrades": _count(ups, mark), "rocks": _count(breaks, mark), "pickaxe": metrics.get("pickaxe"),
			"taps": metrics.get("taps"), "earned": metrics.get("earned"),
			"rock": (RockPlusLevels.rock(int(metrics.get("rock", 0))) if plus else RockLevels.rock(int(metrics.get("rock", 0))))["name"]}
	var per: Array = s["actions_per_minute"]
	return {
		"at": at,
		"first_break_s": s["metrics"].get("first_break_s"),
		"first_upgrade_s": s["first_upgrade_s"],
		"longest_upgrade_wait_s": {"0-3": _longest(ups, 0.0, 180.0), "3-15": _longest(ups, 180.0, 900.0), "15-30": _longest(ups, 900.0, 1800.0)},
		"longest_break_wait_s": _longest(breaks, 0.0, 1800.0),
		"longest_reveal_wait_s": {"0-15": _longest(reveals, 0.0, 900.0), "15-30": _longest(reveals, 900.0, 1800.0)},
		"reveals": reveals.size(),
		"taps_a_minute_at_the_end": per[per.size() - 1] if not per.is_empty() else 0,
		"taps": s["metrics"].get("taps"),
		"waits": int((s["actions_by_kind"] as Dictionary).get("tap_wait", 0)),
		"final": {"rock": st.get("rock_name"), "pickaxe": st.get("pick"), "damage": st.get("damage"), "hp": st.get("max_hp")},
	}


static func _count(a: Array[float], until: float) -> int:
	return a.filter(func(x: float) -> bool: return x <= until).size()


## The longest wait for the next one between `lo` and `hi`, the one still
## open at `hi` included.
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
