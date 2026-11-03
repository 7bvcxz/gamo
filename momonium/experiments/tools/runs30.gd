extends SceneTree

## Step 100: C, C+, E and E+ for thirty minutes of play time at several
## realistic interaction profiles, in the real frame (the same experiments,
## session and checkpoints a person's run has), written to
## web/play30/runs30.json for the 30-minute report (report30.html).
##
## Profiles: C and C+ tapped in the rock's middle at 0 (passive), 1.0 (slow),
## 1.5 (tired), 2.5 (natural) and 4.0 (eager) taps a second, buying 1.5 s
## after they can pay; E and E+ bought 1.5 s after they can pay (prompt), at
## a look every 30 s (an occasional checker), or never (passive).
##
## At 3, 10, 15, 20 and 30 minutes: the level or pickaxe, the last major
## visual reveal and when, actions and idle time, the spacing of meaningful
## rewards, coins and income. And checks for what would make the comparison
## dishonest: a stall (no reward for five minutes while playing), a cost wall
## (the next price more than ten minutes of income away), the books not
## balancing (coins = earned - spent, whole numbers -- no duplicate currency,
## no drift), crowding (most rock pieces or belt items on screen at once).
## Objective technical and pacing evidence only: never a measure of fun,
## fatigue or boredom.
##
##   godot --headless --path momonium/experiments --script res://tools/runs30.gd -- [--out web/play30/runs30.json] [--only tycoon-plus]

const STEP := 0.05
const REACTION := 1.5
const SECONDS := 1800.0
const MARKS: Array[float] = [180.0, 600.0, 900.0, 1200.0, 1800.0]
const STALL_S := 300.0
const WALL_S := 600.0
## [id, profile, taps a second, buy: "prompt" | "every30" | "never"]
const RUNS: Array[Array] = [
	["rock", "passive", 0.0, "prompt"], ["rock", "slow", 1.0, "prompt"], ["rock", "tired", 1.5, "prompt"], ["rock", "natural", 2.5, "prompt"], ["rock", "eager", 4.0, "prompt"],
	["rock-plus", "passive", 0.0, "prompt"], ["rock-plus", "slow", 1.0, "prompt"], ["rock-plus", "tired", 1.5, "prompt"], ["rock-plus", "natural", 2.5, "prompt"], ["rock-plus", "eager", 4.0, "prompt"],
	["tycoon", "prompt", 0.0, "prompt"], ["tycoon", "every30", 0.0, "every30"], ["tycoon", "passive", 0.0, "never"],
	["tycoon-plus", "prompt", 0.0, "prompt"], ["tycoon-plus", "every30", 0.0, "every30"], ["tycoon-plus", "passive", 0.0, "never"],
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "res://web/play30/runs30.json"
	var only := ""
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_path = args[i + 1]
		if args[i] == "--only" and i + 1 < args.size():
			only = args[i + 1]
	root.size = Vector2i(720, 1558)
	var app: LabApp = (load("res://lab/main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	var rows: Array = []
	for run: Array in RUNS:
		if only != "" and String(run[0]) != only:
			continue
		var started := Time.get_ticks_msec()
		print("%s %s ..." % [run[0], run[1]])
		app.open(String(run[0]))
		await process_frame
		var host: LabHost = app.host
		host.set_process(false)
		var e := host.experiment
		var t := 0.0
		var tap_clock := 0.0
		var ready_since := -1.0
		var rate := float(run[2])
		var buy := String(run[3])
		var crowd := 0
		var walls: Array = []
		var books_ok := true
		var at := {}
		while t < SECONDS:
			host.step(STEP)
			t += STEP
			if rate > 0.0:
				tap_clock += STEP
				if tap_clock >= 1.0 / rate:
					tap_clock -= 1.0 / rate
					var rr: Array = e.state()["rock_rect"]
					e.call("tap_at", e.get_global_transform().affine_inverse() * Vector2(float(rr[0]) + float(rr[2]) * 0.5, float(rr[1]) + float(rr[3]) * 0.5))
			var can := bool(e.action_info().get("affordable", false))
			match buy:
				"prompt":
					if can:
						if ready_since < 0.0:
							ready_since = t
						elif t - ready_since >= REACTION:
							host.press_action()
							ready_since = -1.0
					else:
						ready_since = -1.0
				"every30":
					if fmod(t, 30.0) < STEP and can:
						host.press_action()
			# Once a second: crowding, the next price against income, the books.
			if fmod(t, 1.0) < STEP:
				var st: Dictionary = e.state()
				crowd = maxi(crowd, int(st.get("bits", st.get("on_belt", 0))))
				var info := e.action_info()
				var rate_s := float(e.hud().get("rate", 0.0))
				if info.has("cost") and int(info["cost"]) > int(st["coins"]) and rate_s > 0.0:
					var need := (float(info["cost"]) - float(st["coins"])) / rate_s
					if need > WALL_S:
						walls.append(snappedf(t, 1.0))
				if not _balanced(st, host.session):
					books_ok = false
			for mark: float in MARKS:
				var key := "%d" % int(mark / 60.0)
				if not at.has(key) and t >= mark - 0.001:
					at[key] = _at(host.session, e, mark)
		var s := host.session.summary(false)
		var st: Dictionary = e.state()
		# Playing: C only while tapped (an untouched rock gives nothing to wait
		# for), E while someone buys.
		var gaps := _reward_gaps(s, rate > 0.0 if String(run[0]).begins_with("rock") else buy != "never")
		rows.append({"id": run[0], "profile": run[1], "taps_per_second": rate, "buys": buy, "at": at,
			"stall": {"limit_s": STALL_S, "longest_reward_gap_s": gaps["longest"], "stalled": gaps["longest"] > STALL_S, "where_s": gaps["where"]},
			"cost_wall": {"limit_s": WALL_S, "seconds_over": walls.size(), "first_s": walls[0] if not walls.is_empty() else null},
			"books_balance": books_ok, "coins_whole": typeof(st["coins"]) == TYPE_INT and typeof(st["earned"]) == TYPE_INT,
			"most_on_screen": crowd, "unique_deliveries": bool(st.get("unique_deliveries", true)),
			"final": {"coins": st["coins"], "earned": st["earned"], "upgrades": (s["upgrades"] as Array).size(), "actions": s["actions"]}})
		print("%s %s: %.1f s, 30 min %s" % [run[0], run[1], (Time.get_ticks_msec() - started) / 1000.0, JSON.stringify(at["30"])])
		app.back()
		await process_frame
	var doc := {"_doc": "tools/runs30.gd: %d s of play per run in the real frame at several interaction profiles. Objective technical and pacing evidence, never a measure of fun, fatigue or boredom." % int(SECONDS),
		"marks_s": MARKS, "stall_s": STALL_S, "wall_s": WALL_S, "runs": rows}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	app.queue_free()
	for i in 3:
		await process_frame
	quit()


## coins = earned - everything spent, in whole numbers.
static func _balanced(st: Dictionary, session: LabSession) -> bool:
	var spent := 0
	for u: Dictionary in session.upgrades:
		spent += int(u["cost"])
	return int(st["coins"]) == int(st["earned"]) - spent


## The run at a mark: how far, the last thing newly seen, the hands, the
## rewards, the money.
static func _at(session: LabSession, e: LabExperiment, mark: float) -> Dictionary:
	var s := session.summary(false)
	var st := e.state()
	var reveal: Variant = _last_reveal(s, st)
	var per: Array = s["actions_per_minute"]
	return {"active_s": s["active_seconds"], "level": st.get("level", st.get("pick")), "name": st.get("name", st.get("tier", st.get("rock_name"))),
		"last_reveal": reveal, "actions": s["actions"], "actions_last_minute": per[per.size() - 1] if not per.is_empty() else 0,
		"idle_s": s["idle_seconds"], "engaged_s": s["engaged_seconds"], "rewards": s["rewards"], "upgrades": (s["upgrades"] as Array).size(),
		"visible_upgrades": s["visible_upgrades"], "coins": st["coins"], "earned": st["earned"], "income_per_s": snappedf(float(e.hud().get("rate", 0.0)), 0.1),
		"breaks": st.get("breaks"), "delivered": st.get("delivered"), "deliveries_per_min": st.get("deliveries_per_min"), "taps": st.get("taps")}


## The last major visual reveal: C+ a new pickaxe tier or a great rock, C a
## rock not seen before, E and E+ an upgrade that is not the sparkle-only
## Golden Line, or an era.
static func _last_reveal(s: Dictionary, st: Dictionary) -> Variant:
	var plus := st.has("kind")
	var e := st.has("delivered")
	var found: Array[Dictionary] = []
	for u: Dictionary in s["upgrades"]:
		if e and String(u.get("show", "")) != "sparkle":
			found.append({"t_s": u["t_s"], "what": String(u.get("name", ""))})
		elif not e and (not plus or bool(u.get("milestone", false))):
			found.append({"t_s": u["t_s"], "what": String(u.get("tier", "pickaxe %d" % int(u["level"])))})
	for m: Dictionary in s["milestones"]:
		match String(m["name"]):
			"break":
				# The rock's name is not in the milestone (its own "name" wins
				# the merge): from the levels table by index.
				var i := int(m["rock"])
				if (plus and bool(m.get("big", false))) or (not plus and i < RockLevels.GOAL):
					found.append({"t_s": m["t_s"], "what": "broke " + String((RockPlusLevels.rock(i) if plus else RockLevels.rock(i))["name"])})
			"era":
				found.append({"t_s": m["t_s"], "what": String(m.get("era", "era"))})
	if found.is_empty():
		return null
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t_s"]) < float(b["t_s"]))
	return found.back()


## The longest stretch without a meaningful reward while the player plays,
## and where it began (a passive run has no rewards to wait for: none).
static func _reward_gaps(s: Dictionary, playing: bool) -> Dictionary:
	var times: Array[float] = []
	for u: Dictionary in s["upgrades"]:
		times.append(float(u["t_s"]))
	for m: Dictionary in s["milestones"]:
		if String(m["name"]) in LabSession.REWARD_MILESTONES:
			times.append(float(m["t_s"]))
	times.sort()
	var longest := 0.0
	var where := 0.0
	var prev := 0.0
	for x: float in times + [SECONDS]:
		if x - prev > longest:
			longest = x - prev
			where = prev
		prev = x
	return {"longest": snappedf(longest, 0.1) if playing else 0.0, "where": snappedf(where, 0.1)}
