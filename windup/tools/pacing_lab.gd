extends SceneTree

## The pacing lab (Step 08): the REAL rules (src/game/atelier.gd with
## data/balance.json and data/variants.json) driven by seeded player profiles,
## several runs each, measured at 10 s, 30 s, 60 s, 3 min, 10 min and 30 min.
## Nothing here approximates the game: each profile presses, holds and lets go
## through the same Atelier the game uses, at fixed 1/30 s steps.
##
##   godot --headless --path windup --script res://tools/pacing_lab.gd -- \
##     [--variant base] [--seeds 5] [--minutes 30] [--json /abs/out.json] [--md /abs/out.md]
##
## "Levels" are the atelier's visible awakening milestones, not a new system.

const DT := 1.0 / 30.0
const MARKS := [10.0, 30.0, 60.0, 180.0, 600.0, 1800.0]

## Profiles. interval = mean seconds between presses (jitter = +-uniform);
## rest = a pause of rest_len every rest_every seconds; miss = share of presses
## that land off the key (no effect); hold_p = share of presses held for
## hold_len (repeating at the hold rate, then let go); stop_after_first =
## hands off once the first doll is up.
const PROFILES := {
	"confused_slow": {"start": 8.0, "interval": 1.2, "jitter": 0.6, "rest_every": 20.0, "rest_len": 6.0, "miss": 0.2, "hold_p": 0.0, "hold_len": 0.0},
	"casual": {"start": 4.0, "interval": 0.65, "jitter": 0.3, "rest_every": 30.0, "rest_len": 4.0, "miss": 0.05, "hold_p": 0.2, "hold_len": 2.0},
	"engaged": {"start": 2.0, "interval": 0.25, "jitter": 0.05, "rest_every": 0.0, "rest_len": 0.0, "miss": 0.0, "hold_p": 0.1, "hold_len": 4.0},
	"clicker": {"start": 1.5, "interval": 0.12, "jitter": 0.03, "rest_every": 0.0, "rest_len": 0.0, "miss": 0.0, "hold_p": 0.0, "hold_len": 0.0},
	"hands_off": {"start": 2.0, "interval": 0.25, "jitter": 0.05, "rest_every": 0.0, "rest_len": 0.0, "miss": 0.0, "hold_p": 0.0, "hold_len": 0.0, "stop_after_first": true},
	"minimal": {"start": 4.0, "interval": 3.0, "jitter": 0.5, "rest_every": 0.0, "rest_len": 0.0, "miss": 0.0, "hold_p": 0.0, "hold_len": 0.0},
	# HYPOTHESES, not measurements: the same slow players, if the wordless hold
	# hint (WindInput.wants_hold_hint) works -- after it shows they hold the key
	# for 3 s on 60% of presses. Blind play (Step 09) is what checks this.
	"confused_slow+hint?": {"start": 8.0, "interval": 1.2, "jitter": 0.6, "rest_every": 20.0, "rest_len": 6.0, "miss": 0.2, "hold_p": 0.0, "hold_len": 3.0, "adopt_p": 0.6},
	"minimal+hint?": {"start": 4.0, "interval": 3.0, "jitter": 0.5, "rest_every": 0.0, "rest_len": 0.0, "miss": 0.0, "hold_p": 0.0, "hold_len": 3.0, "adopt_p": 0.6},
}


func _init() -> void:
	var args := RunConfig.parse_args(OS.get_cmdline_user_args())
	var variant := String(args.get("variant", "base"))
	var seeds := int(args.get("seeds", "5"))
	var minutes := float(args.get("minutes", "30"))
	var b := Balance.load_variant(variant)
	# --set '{"costs":[...], "rates":[...]}': a tuning candidate, tried without touching data/.
	var candidate := String(args.get("set", ""))
	if candidate != "":
		b = with_overrides(b, JSON.parse_string(candidate))
	var report := {"variant": variant, "candidate": candidate, "seeds": seeds, "minutes": minutes, "costs": Array(b.costs), "rates": Array(b.rates),
		"energy_per_turn": b.energy_per_turn, "gear_bonus": b.gear_bonus_per_doll, "profiles": {}}
	for name: String in PROFILES:
		var runs: Array = []
		for s in seeds:
			runs.append(simulate(b, PROFILES[name], 1000 + s, minutes * 60.0))
		report["profiles"][name] = summarize(runs)
	report["flags"] = failure_shapes(report["profiles"])
	var md := to_markdown(report)
	print(md)
	if args.has("json"):
		var f := FileAccess.open(String(args["json"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
	if args.has("md"):
		var g := FileAccess.open(String(args["md"]), FileAccess.WRITE)
		g.store_string(md)
	quit()


## A copy of `b` with per-doll costs/rates (lists, null keeps a value) and
## simple fields replaced.
static func with_overrides(b: Balance, o: Dictionary) -> Balance:
	var c := Balance.new()
	for prop in ["energy_per_turn", "gear_bonus_per_doll", "max_turns_per_second", "hold_turns_per_second", "hold_delay",
			"awaken_seconds", "hint_idle_seconds", "idle_report_seconds", "autosave_seconds", "variant", "spring_enabled",
			"spring_capacity_of_next_cost", "reveal", "kick_seconds"]:
		c.set(prop, o.get(prop, b.get(prop)))
	c.costs = b.costs.duplicate()
	c.rates = b.rates.duplicate()
	c.positions = b.positions.duplicate()
	c.stages = b.stages.duplicate()
	for i in c.costs.size():
		if o.has("costs") and i < (o["costs"] as Array).size() and o["costs"][i] != null:
			c.costs[i] = float(o["costs"][i])
		if o.has("rates") and i < (o["rates"] as Array).size() and o["rates"][i] != null:
			c.rates[i] = float(o["rates"][i])
	return c


## One run of one profile. Answers the events and the checkpoint measurements.
static func simulate(b: Balance, p: Dictionary, seed: int, seconds: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := Atelier.new(b)
	var t := 0.0
	var next_press := float(p["start"])
	var hold_until := -1.0
	var hold_next := 0.0
	var presses := 0
	var press_times: Array[float] = []
	var wakes: Array[float] = []
	var seen := -1
	var rate_jumps: Array[float] = []
	var marks := {}
	var manual_window: Array = []   # [t, manual_energy] samples for the recent manual rate
	var stopped := false
	var ever_held := false
	var hinted := false
	while t < seconds:
		if not hinted and p.has("adopt_p") and WindInput.wants_hold_hint(press_times, t, ever_held, a.awake > 0 or a.waking >= 0):
			hinted = true
		if bool(p.get("stop_after_first", false)) and (a.awake > 0 or a.waking >= 0):
			stopped = true
		var resting := float(p["rest_every"]) > 0.0 and t > float(p["start"]) and fmod(t - float(p["start"]), float(p["rest_every"])) > float(p["rest_every"]) - float(p["rest_len"])
		if not stopped and t >= hold_until and hold_until >= 0.0:
			a.release()
			hold_until = -1.0
		if not stopped and hold_until >= 0.0 and t >= hold_next:
			a.wind()
			hold_next = t + 1.0 / b.hold_turns_per_second
		elif not stopped and not resting and hold_until < 0.0 and t >= next_press:
			presses += 1
			press_times.append(t)
			if rng.randf() >= float(p["miss"]):
				a.wind()
				var hold_chance := float(p["adopt_p"]) if hinted else float(p["hold_p"])
				if rng.randf() < hold_chance:
					ever_held = true
					hold_until = t + float(p["hold_len"])
					hold_next = t + b.hold_delay
				else:
					a.release()
			next_press = t + maxf(0.05, float(p["interval"]) + rng.randf_range(-float(p["jitter"]), float(p["jitter"])))
		var before_rate := a.auto_rate()
		a.tick(DT)
		t += DT
		if a.waking >= 0 and a.waking != seen:
			seen = a.waking
			wakes.append(t)
		if a.auto_rate() > before_rate and before_rate > 0.0:
			rate_jumps.append(a.auto_rate() / before_rate)
		manual_window.append([t, a.manual_energy])
		while manual_window.size() > 0 and t - float(manual_window[0][0]) > 30.0:
			manual_window.pop_front()
		for m: float in MARKS:
			if not marks.has(str(m)) and t >= m:
				marks[str(m)] = measure(a, t, wakes, press_times, manual_window, m)
	return {"wakes": wakes, "marks": marks, "rate_jumps": rate_jumps, "presses": presses}


## What a player sees at a checkpoint.
static func measure(a: Atelier, t: float, wakes: Array[float], presses: Array[float], window: Array, mark: float) -> Dictionary:
	var since := t - (wakes[wakes.size() - 1] if wakes.size() > 0 else 0.0)
	var recent := 0
	for pt in presses:
		if pt > t - 60.0:
			recent += 1
	var manual_rate := 0.0
	if window.size() > 1:
		var dt := float(window[window.size() - 1][0]) - float(window[0][0])
		manual_rate = (float(window[window.size() - 1][1]) - float(window[0][1])) / maxf(dt, 1e-6)
	var remaining := maxf(0.0, a.target_cost() - a.energy) if a.target() < a.doll_count() else 0.0
	var with_clicks := remaining / maxf(manual_rate + a.auto_rate(), 1e-6) if remaining > 0.0 else 0.0
	var without := remaining / a.auto_rate() if a.auto_rate() > 0.0 else INF
	var total := a.manual_energy + a.auto_energy
	return {
		"dolls": a.awake + (1 if a.waking >= 0 else 0),
		"stage": a.stage,
		"apm": float(recent) * 60.0 / minf(60.0, mark),
		"manual_share": a.manual_energy / total if total > 0.0 else 1.0,
		"since_last_event": since,
		"wait_next": with_clicks,
		"clicking_speedup": (without / with_clicks) if with_clicks > 0.0 and without < INF else (INF if remaining > 0.0 else 1.0),
	}


static func pct(values: Array, q: float) -> float:
	if values.is_empty():
		return NAN
	var v := values.duplicate()
	v.sort()
	return float(v[clampi(int(round(q * (v.size() - 1))), 0, v.size() - 1)])


static func summarize(runs: Array) -> Dictionary:
	var out := {"first_doll": [], "second_doll": [], "max_gap_10m": [], "bursts": [], "max_rate_jump": [], "marks": {}}
	for r: Dictionary in runs:
		var w: Array = r["wakes"]
		out["first_doll"].append(w[0] if w.size() > 0 else INF)
		out["second_doll"].append(w[1] if w.size() > 1 else INF)
		var gap := 0.0
		var prev := 0.0
		var bursts := 0
		for x: float in w:
			if x <= 600.0:
				gap = maxf(gap, x - prev)
			if x - prev < 3.0 and prev > 0.0:
				bursts += 1
			prev = x
		if prev < 600.0 and w.size() < 12:
			gap = maxf(gap, 600.0 - prev)
		out["max_gap_10m"].append(gap)
		out["bursts"].append(bursts)
		var jumps: Array = r["rate_jumps"]
		out["max_rate_jump"].append(jumps.max() if jumps.size() > 0 else 1.0)
	for m: float in MARKS:
		var key := str(m)
		var per := {}
		for field: String in ["dolls", "apm", "manual_share", "since_last_event", "wait_next", "clicking_speedup"]:
			var vals: Array = []
			for r: Dictionary in runs:
				if (r["marks"] as Dictionary).has(key):
					vals.append(float(r["marks"][key][field]))
			per[field] = [pct(vals, 0.1), pct(vals, 0.5), pct(vals, 0.9)]
		out["marks"][key] = per
	for k: String in ["first_doll", "second_doll", "max_gap_10m", "bursts", "max_rate_jump"]:
		var vals: Array = out[k]
		out[k] = [pct(vals, 0.1), pct(vals, 0.5), pct(vals, 0.9)]
	return out


## The V2 failure shapes, from the medians.
static func failure_shapes(p: Dictionary) -> Array:
	var flags: Array = []
	for name: String in p:
		var s: Dictionary = p[name]
		if float(s["first_doll"][1]) > 90.0:
			flags.append("%s: first reward after 90 s (median %s)" % [name, _s(s["first_doll"][1])])
		if float(s["max_gap_10m"][1]) > 120.0 and name != "hands_off":
			flags.append("%s: a wait over 2 minutes within the first 10 (median %s)" % [name, _s(s["max_gap_10m"][1])])
		if float(s["bursts"][2]) >= 3.0:
			flags.append("%s: dolls waking in bursts (3 within 3 s, p90 %d)" % [name, int(s["bursts"][2])])
	var off: float = p["hands_off"]["marks"]["600.0"]["dolls"][1]
	var eng: float = p["engaged"]["marks"]["600.0"]["dolls"][1]
	if off <= 1.0:
		flags.append("only clicking wins: hands-off has %d doll(s) at 10 min" % int(off))
	if off >= eng:
		flags.append("doing nothing wins equally: hands-off %d >= engaged %d at 10 min" % [int(off), int(eng)])
	var sp: float = p["engaged"]["marks"]["600.0"]["clicking_speedup"][1]
	if eng >= 12.0:
		flags.append("the MVP ends before 10 minutes for an engaged player (all 12 dolls awake)")
	elif sp < 1.2:
		flags.append("clicking no longer matters at 10 min (engaged: next doll x%.2f faster with clicks)" % sp)
	return flags


static func _s(x: float) -> String:
	return "never" if is_inf(x) else ("%.0f s" % x)


static func to_markdown(r: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("variant %s · %d seeds · %d min · first costs %s" % [r["variant"], r["seeds"], int(r["minutes"]), str(Array(r["costs"]).slice(0, 4))])
	lines.append("")
	lines.append("| profile | first doll p10/p50/p90 | second | dolls @10s/30s/60s/3m/10m/30m (p50) | APM @3m | manual share @3m / 10m | since last event @3m | wait for next @3m | clicks speed next @10m | longest wait ≤10m |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for name: String in r["profiles"]:
		var s: Dictionary = r["profiles"][name]
		var m: Dictionary = s["marks"]
		var dolls := PackedStringArray()
		for k: float in MARKS:
			dolls.append(str(int(m[str(k)]["dolls"][1])))
		lines.append("| %s | %s / %s / %s | %s | %s | %.0f | %.0f%% / %.0f%% | %s | %s | ×%s | %s |" % [name,
			_s(s["first_doll"][0]), _s(s["first_doll"][1]), _s(s["first_doll"][2]), _s(s["second_doll"][1]), " / ".join(dolls),
			m["180.0"]["apm"][1], 100.0 * float(m["180.0"]["manual_share"][1]), 100.0 * float(m["600.0"]["manual_share"][1]),
			_s(m["180.0"]["since_last_event"][1]), _s(m["180.0"]["wait_next"][1]),
			("inf" if is_inf(float(m["600.0"]["clicking_speedup"][1])) else "%.1f" % float(m["600.0"]["clicking_speedup"][1])), _s(s["max_gap_10m"][1])])
	lines.append("")
	lines.append("failure shapes: " + ("none" if (r["flags"] as Array).is_empty() else ""))
	for f: String in r["flags"]:
		lines.append("- " + f)
	return "\n".join(lines)
