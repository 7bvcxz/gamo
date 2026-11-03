extends SceneTree

## The pacing simulator (Step 06): scripted player behaviours on the REAL
## rules -- the same rules scripts (PopRegistry.make_rules), economy file and
## session log the game runs -- one millisecond at a time for three minutes.
## Automated simulation: it measures what the numbers do; it cannot measure
## tactile pleasure, how easy the first action is to find, or delight.
##
##   godot --headless --path popcorn-glory --script res://tools/sim/runner.gd -- \
##       [--out res://tests/results/step06] [--only click] [--no-sensitivity]
##   ... -- --replay /abs/play180_click_p720.json [--economy /abs/economy.json]
##   (a browser run's own inputs; --economy: the numbers that build was made with)
##
## Every run checks the economy's invariants at every event: money >= 0,
## money == earned - spent, a purchase only when affordable, money finite.

const HORIZON := 180000
const STRATEGIES := [
	# --- A Click & Pop
	{"name": "A active (4 taps/s, buys at once)", "exp": "click", "act": "taps", "rate": 4.0, "buy": "now"},
	{"name": "A steady (2.5 taps/s)", "exp": "click", "act": "taps", "rate": 2.5, "buy": "react"},
	{"name": "A newcomer (first tap 8 s, 1.2/s, pauses)", "exp": "click", "act": "taps", "rate": 1.2, "first_ms": 8000, "pauses": true, "buy": "slow"},
	{"name": "A late buyer (saves 2x the price)", "exp": "click", "act": "taps", "rate": 2.5, "buy": "save2x"},
	{"name": "A idle 30 s (60-90 s)", "exp": "click", "act": "taps", "rate": 2.5, "idle": [60000, 90000], "buy": "react"},
	{"name": "A ignores the upgrade", "exp": "click", "act": "taps", "rate": 2.5, "buy": "never"},
	# --- B Perfect Pop
	{"name": "B skilled (gold's middle)", "exp": "perfect", "act": "hold", "aim": "gold", "buy": "react"},
	{"name": "B novice (mixed)", "exp": "perfect", "act": "hold", "aim": "novice", "buy": "slow", "first_ms": 5000},
	{"name": "B early reactions (100-300 ms before gold)", "exp": "perfect", "act": "hold", "aim": "early_edge", "buy": "react"},
	{"name": "B late reactions (100-300 ms after gold)", "exp": "perfect", "act": "hold", "aim": "late_edge", "buy": "react"},
	{"name": "B tapper (never holds)", "exp": "perfect", "act": "hold", "aim": "tap", "buy": "react"},
	{"name": "B late buyer (saves 2x)", "exp": "perfect", "act": "hold", "aim": "gold", "buy": "save2x"},
	{"name": "B idle 30 s (60-90 s)", "exp": "perfect", "act": "hold", "aim": "gold", "idle": [60000, 90000], "buy": "react"},
	{"name": "B ignores the upgrade", "exp": "perfect", "act": "hold", "aim": "gold", "buy": "never"},
	# --- C Pop Explosion
	{"name": "C active (4 taps/s, buys at once)", "exp": "explosion", "act": "taps", "rate": 4.0, "buy": "now"},
	{"name": "C steady (2.5 taps/s)", "exp": "explosion", "act": "taps", "rate": 2.5, "buy": "react"},
	{"name": "C newcomer (first tap 8 s, 1.2/s, pauses)", "exp": "explosion", "act": "taps", "rate": 1.2, "first_ms": 8000, "pauses": true, "buy": "slow"},
	{"name": "C burst-heavy (6/s for 4 s, rest 2 s)", "exp": "explosion", "act": "bursts", "buy": "react"},
	{"name": "C late buyer (saves 2x)", "exp": "explosion", "act": "taps", "rate": 2.5, "buy": "save2x"},
	{"name": "C idle 30 s (60-90 s)", "exp": "explosion", "act": "taps", "rate": 2.5, "idle": [60000, 90000], "buy": "react"},
	{"name": "C ignores the upgrade", "exp": "explosion", "act": "taps", "rate": 2.5, "buy": "never"},
]
const LOOKS := [3, 6, 9, 12]      # the machine's new looks (PopPlayView.MILESTONES)
const C_TIERS := [3, 6]           # C's cluster and fountain (explosion_view.tier_of)

var _args := {}


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var v: String = raw[i + 1] if i + 1 < raw.size() and not raw[i + 1].begins_with("--") else ""
		_args[raw[i].trim_prefix("--")] = v
		i += 2 if v != "" else 1
	if _args.has("replay"):
		_replay(String(_args["replay"]))
		quit(0)
		return
	var econ := PopEconomy.load_default()
	var rows: Array[Dictionary] = []
	for s: Dictionary in STRATEGIES:
		if _args.has("only") and String(s["exp"]) != String(_args["only"]):
			continue
		rows.append(run(s, econ, 7))
	var sens: Array[Dictionary] = []
	if not _args.has("no-sensitivity"):
		sens = sensitivity()
	var out := String(_args.get("out", "res://tests/results/step06"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_write(out + "/sim.json", JSON.stringify({"_doc": "AUTOMATED SIMULATION on the real rules (tools/sim/runner.gd), seed 7. Not human play.", "runs": rows, "sensitivity": sens}, "  "))
	_write(out + "/sim.md", markdown(rows, sens))
	_write(out + "/chart.svg", chart(rows))
	var bad := rows.filter(func(r: Dictionary) -> bool: return not (r["violations"] as Array).is_empty())
	print(markdown(rows, sens))
	print("runner: %d runs, %d with invariant violations -> %s" % [rows.size(), bad.size(), out])
	quit(1 if bad.size() > 0 else 0)


## One behaviour for three minutes. Deterministic for a seed.
func run(s: Dictionary, econ: PopEconomy, seed: int) -> Dictionary:
	var rules := PopRegistry.make_rules(String(s["exp"]), econ)
	var session := PopSession.new(String(s["exp"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var t := 0
	var next_input := int(s.get("first_ms", 2000))
	var buy_at := -1
	var holding := false
	var release_at := 0
	var spent := 0
	var violations: Array[String] = []
	var earn_log: Array = []
	var level_times := {}
	var pause_until := -1
	var interval := int(round(1000.0 / float(s.get("rate", 2.5))))
	while t < HORIZON:
		var idle_win: Array = s.get("idle", [])
		var idling := not idle_win.is_empty() and t >= int(idle_win[0]) and t < int(idle_win[1])
		if bool(s.get("pauses", false)) and t >= next_input and pause_until < t and rng.randf() < 0.0002:
			pause_until = t + rng.randi_range(3000, 6000)   # a newcomer stops to look, now and then
		var acting := not idling and t >= pause_until
		match String(s["act"]):
			"taps":
				if acting and t >= next_input:
					session.record_input(t, "press")
					rules.execute({"type": "press"})
					next_input = t + interval + rng.randi_range(-40, 40)
				elif not acting and t >= next_input:
					next_input = t + interval
			"bursts":
				# 6 taps a second for four seconds, then two seconds of rest.
				var phase := (t - 2000) % 6000
				if acting and t >= next_input and phase >= 0 and phase < 4000:
					session.record_input(t, "press")
					rules.execute({"type": "press"})
					next_input = t + 167
			"hold":
				var st := rules.state()
				if holding and t >= release_at:
					session.record(t, "release", {})
					rules.execute({"type": "release"})
					holding = false
					next_input = t + 300
				elif holding and not bool(rules.state()["heating"]):
					holding = false
					next_input = t + 300
				elif acting and not holding and t >= next_input and int(st["cooldown_left"]) == 0:
					var w: Array = st["window"]
					var hold := _hold_for(String(s["aim"]), w, rng)
					session.record_input(t, "press")
					rules.execute({"type": "press"})
					holding = true
					release_at = t + hold
		# Buying.
		var cost := rules.cost()
		var mode := String(s["buy"])
		if mode != "never" and cost >= 0 and buy_at < 0:
			var want := rules.money >= cost if mode != "save2x" else rules.money >= cost * 2
			if want:
				buy_at = t + {"now": 300, "react": 1500, "slow": 3000, "save2x": 1500}[mode]
		if buy_at >= 0 and t >= buy_at:
			var before := rules.money
			var c := rules.cost()
			var r := rules.execute({"type": "buy"})
			if bool(r["ok"]):
				spent += c
				if before < c:
					violations.append("bought at %d ms with %d < %d" % [t, before, c])
				level_times[rules.level] = t
			buy_at = -1
		var events := rules.drain_events()
		for e: Dictionary in events:
			if String(e["type"]) == "earn":
				earn_log.append([int(e["t"]), int(e["data"]["amount"])])
		session.record_events(events)
		session.observe(t, rules)
		if rules.money < 0:
			violations.append("money %d at %d ms" % [rules.money, t])
		if rules.money != rules.earned - spent:
			violations.append("money %d != earned %d - spent %d at %d ms" % [rules.money, rules.earned, spent, t])
			spent = rules.earned - rules.money   # report once, then follow
		if rules.money > 9007199254740991:
			violations.append("money past 2^53 at %d ms" % t)
		rules.advance(1)
		t += 1
	session.observe(t, rules)
	return _measure(s, rules, session, earn_log, level_times, violations)


func _hold_for(aim: String, w: Array, rng: RandomNumberGenerator) -> int:
	var a := int(w[0])
	var b := int(w[1])
	var burn := int(w[2])
	match aim:
		"gold": return (a + b) / 2 + rng.randi_range(-40, 40)
		"early_edge": return a - rng.randi_range(100, 300)
		"late_edge": return b + rng.randi_range(100, 300)
		"tap": return 150
		"novice":
			var x := rng.randf()
			if x < 0.2: return int(a * 0.7)
			if x < 0.55: return (a + b) / 2
			if x < 0.9: return (b + burn) / 2
			return burn + 400
	return (a + b) / 2


func _measure(s: Dictionary, rules: PopRules, session: PopSession, earn_log: Array, level_times: Dictionary, violations: Array[String]) -> Dictionary:
	var ms: Dictionary = session.milestones
	var ups: Array[int] = session.upgrades
	var gaps: Array[int] = []
	var prev := 0
	for u: int in ups:
		gaps.append(u - prev)
		prev = u
	# The longest stretch with no new upgrade, including the open one at the end.
	var stall := HORIZON - prev
	for g: int in gaps:
		stall = maxi(stall, g)
	var recent := 0
	var waits := 0
	var longest_wait := 0
	var last := -1
	for e: Array in earn_log:
		if int(e[0]) >= HORIZON - 30000:
			recent += int(e[1])
		if last >= 0:
			var g := int(e[0]) - last
			longest_wait = maxi(longest_wait, g)
			if g >= 5000:
				waits += g
		last = int(e[0])
	var rate := recent / 30.0
	# -1: nothing left to buy; 0: affordable right now (not bought); else seconds of income.
	var cost_now := rules.cost()
	var need := -1 if cost_now < 0 else maxi(0, cost_now - rules.money)
	var looks := {}
	for l: int in LOOKS:
		if level_times.has(l):
			looks[str(l)] = level_times[l]
	var tiers := {}
	if String(s["exp"]) == "explosion":
		for l: int in C_TIERS:
			if level_times.has(l):
				tiers[str(l)] = level_times[l]
	return {"name": s["name"], "exp": s["exp"], "level": rules.level, "max_level": rules.max_level(),
		"earned": rules.earned, "money": rules.money, "inputs": session.inputs, "decisions": ups.size(),
		"first_earn_ms": int(ms.get("first_earn", -1)), "first_affordable_ms": int(ms.get("first_affordable", -1)),
		"first_upgrade_ms": int(ms.get("first_upgrade", -1)), "upgrades_ms": ups, "new_looks_ms": looks, "c_tiers_ms": tiers,
		"longest_stall_ms": stall, "earning_waits_over_5s_ms": waits, "longest_wait_between_earnings_ms": longest_wait,
		"rate_last_30s": rate, "next_upgrade_s_at_180": (float(need) / rate) if rate > 0 and need >= 0 else (-1.0 if need < 0 else INF),
		"outcomes": rules.state().get("outcomes", {}), "violations": violations}


## Cost and reward scaled up and down for each experiment's steady player.
func sensitivity() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PopEconomy.PATH))
	var steady := {"click": STRATEGIES[1], "perfect": STRATEGIES[6], "explosion": STRATEGIES[15]}
	for v: String in ["click", "perfect", "explosion"]:
		for case: Array in [["cost x0.8", "base", 0.8], ["cost x1.25", "base", 1.25], ["growth -0.1", "growth", -0.1], ["growth +0.1", "growth", 0.1]]:
			var d: Dictionary = base.duplicate(true)
			var c: Dictionary = d[v]["cost"]
			if String(case[1]) == "base":
				c["base"] = float(c["base"]) * float(case[2])
			else:
				c["growth"] = float(c["growth"]) + float(case[2])
			var e := PopEconomy.new()
			e.load_dict(d)
			var r := run(steady[v], e, 7)
			out.append({"exp": v, "case": case[0], "level": r["level"], "first_upgrade_ms": r["first_upgrade_ms"],
				"next_upgrade_s_at_180": r["next_upgrade_s_at_180"], "longest_stall_ms": r["longest_stall_ms"]})
	return out


## A browser run's own inputs (play180's saved log) through fresh rules: the
## simulator and the game must agree on what those inputs earn.
func _replay(path: String) -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var log: Dictionary = doc.get("log", {})
	if log.is_empty():
		print("replay: %s has no log (a build before 0.5.0)" % path)
		return
	var exp := String(log["variant"])
	var econ := PopEconomy.load_default()
	if _args.has("economy"):
		econ = PopEconomy.new()
		econ.load_file(String(_args["economy"]))
	var rules := PopRegistry.make_rules(exp, econ)
	var lines: Array = log["lines"]
	var t := 0
	var acts: Array = []
	for l: Dictionary in lines:
		var ty := String(l["type"])
		if ty == "input" or ty == "release" or ty == "buy":
			acts.append(l)
	for l: Dictionary in acts:
		var at := int(l["t"])
		if at > t:
			rules.advance(at - t)
			t = at
		match String(l["type"]):
			"input":
				rules.execute({"type": "press"})
			"release":
				rules.execute({"type": "release"})
			"buy":
				rules.execute({"type": "buy"})
		rules.drain_events()
	var end_ms := int(log["active_ms"])
	if end_ms > t:
		rules.advance(end_ms - t)
	rules.drain_events()
	var sum: Dictionary = log["summary"]
	print(JSON.stringify({"replay": path.get_file(), "variant": exp, "browser": {"level": sum["level"], "money": sum["money"], "earned": sum["earned"], "active_ms": end_ms},
		"simulator": {"level": rules.level, "money": rules.money, "earned": rules.earned},
		"agree": int(sum["level"]) == rules.level and int(sum["earned"]) == rules.earned and int(sum["money"]) == rules.money}))


func markdown(rows: Array[Dictionary], sens: Array[Dictionary]) -> String:
	var f := func(ms: int) -> String: return "–" if ms < 0 else "%.1f" % (ms / 1000.0)
	var s := "# Pacing simulation (AUTOMATED, real rules, seed 7)\n\n"
	s += "Scripted behaviours on the game's own rules for 180 s of active time. Measures what the numbers do -- not tactile pleasure, discoverability or delight.\n\n"
	s += "| behaviour | Lv @3:00 | first $ | 1st affordable | 1st bought | new looks (Lv3/6/9) | C cluster/fountain | buys | longest no-upgrade stretch | waits >=5 s | next upgrade @3:00 | inputs | invariants |\n"
	s += "|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for r: Dictionary in rows:
		var looks: Dictionary = r["new_looks_ms"]
		var lk := "/".join(["3", "6", "9"].map(func(k: String) -> String: return f.call(int(looks.get(k, -1)))))
		var tiers: Dictionary = r["c_tiers_ms"]
		var tr := "–" if String(r["exp"]) != "explosion" else "/".join(["3", "6"].map(func(k: String) -> String: return f.call(int(tiers.get(k, -1)))))
		var nx: float = r["next_upgrade_s_at_180"]
		var nxs := "max level" if nx < 0 else ("never (no income)" if is_inf(nx) else ("affordable now" if nx == 0.0 else "%.1f s" % nx))
		s += "| %s | %d | %s | %s | %s | %s | %s | %d | %.0f s | %.1f s | %s | %d | %s |\n" % [r["name"], r["level"], f.call(r["first_earn_ms"]),
			f.call(r["first_affordable_ms"]), f.call(r["first_upgrade_ms"]), lk, tr, r["decisions"], r["longest_stall_ms"] / 1000.0,
			r["earning_waits_over_5s_ms"] / 1000.0, nxs, r["inputs"], "ok" if (r["violations"] as Array).is_empty() else "VIOLATED"]
	if not sens.is_empty():
		s += "\n## Sensitivity (each experiment's steady player)\n\n| experiment | change | Lv @3:00 | 1st bought | next upgrade @3:00 | longest no-upgrade stretch |\n|---|---|---|---|---|---|\n"
		for r: Dictionary in sens:
			var nx2: float = r["next_upgrade_s_at_180"]
			s += "| %s | %s | %d | %s | %s | %.0f s |\n" % [r["exp"], r["case"], r["level"], f.call(r["first_upgrade_ms"]),
				"max" if nx2 < 0 else "%.1f s" % nx2, r["longest_stall_ms"] / 1000.0]
	return s


## Money (line) and upgrades (dots) over 0-180 s for each experiment's steady,
## active and newcomer behaviours -- an SVG, so the report is one text file.
func chart(rows: Array[Dictionary]) -> String:
	var w := 900
	var h := 300
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 %d %d' font-family='sans-serif' font-size='12'>\n" % [w, h * 3 + 40, w, h * 3 + 40]
	svg += "<rect width='100%' height='100%' fill='#fffaf0'/>\n<text x='10' y='20' font-size='14'>Upgrades over 0-180 s (AUTOMATED simulation, real rules)</text>\n"
	var colors := ["#e8443a", "#2a7de1", "#8a8a8a", "#d99a00", "#6a3fb0", "#2f9e44", "#000000", "#c2185b"]
	var row := 0
	for exp: String in ["click", "perfect", "explosion"]:
		var y0 := 40 + row * h
		svg += "<text x='10' y='%d' font-size='13'>%s</text>\n" % [y0 + 14, {"click": "A Click & Pop", "perfect": "B Perfect Pop", "explosion": "C Pop Explosion"}[exp]]
		svg += "<line x1='60' y1='%d' x2='%d' y2='%d' stroke='#444'/>\n" % [y0 + h - 30, w - 20, y0 + h - 30]
		for sec: int in [0, 30, 60, 90, 120, 150, 180]:
			var x := 60 + (w - 80) * sec / 180
			svg += "<line x1='%d' y1='%d' x2='%d' y2='%d' stroke='#ddd'/><text x='%d' y='%d'>%ds</text>\n" % [x, y0 + 20, x, y0 + h - 30, x - 8, y0 + h - 14, sec]
		var k := 0
		var legend_y := y0 + 30
		for r: Dictionary in rows:
			if String(r["exp"]) != exp:
				continue
			var col: String = colors[k % colors.size()]
			var pts := PackedStringArray()
			var lvl := 0
			pts.append("60,%d" % (y0 + h - 30))
			for u: int in r["upgrades_ms"]:
				var x := 60 + (w - 80) * u / HORIZON
				pts.append("%d,%d" % [x, y0 + h - 30 - lvl * 16])
				lvl += 1
				pts.append("%d,%d" % [x, y0 + h - 30 - lvl * 16])
			pts.append("%d,%d" % [w - 20, y0 + h - 30 - lvl * 16])
			svg += "<polyline fill='none' stroke='%s' stroke-width='2' points='%s'/>\n" % [col, " ".join(pts)]
			svg += "<text x='%d' y='%d' fill='%s'>%s (Lv%d)</text>\n" % [w - 330, legend_y, col, String(r["name"]).substr(0, 40), r["level"]]
			legend_y += 14
			k += 1
		row += 1
	return svg + "</svg>\n"


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
