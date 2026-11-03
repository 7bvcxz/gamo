extends SceneTree

## The Popcorn Stand's pacing (Step 10): scripted players on the REAL stand
## rules for 20 minutes of active time, 10 ms at a time. It measures what the
## numbers do -- when each moment unlocks, when each machine is bought, how
## long a stretch goes without anything to buy, how the money splits between
## the hand and the helper, what each recipe is worth to whom, and whether a
## player who stops pressing still moves. It cannot measure fun.
##
##   godot --headless --path popcorn-glory --script res://tools/sim/stand.gd -- [--out res://tests/results/step10]
##
## Invariants at every step: money >= 0, money == earned - spent, a purchase
## only when affordable.

const HORIZON := 1200000
const STEP := 10
const MARKS := [180000, 300000, 600000, 900000, 1200000]

const PLAYERS := [
	{"name": "skilled (gold's middle, shakes, buys at once, caramel)", "aim": "skilled", "shake": 1.0, "buy": "cheapest", "recipe": "caramel"},
	{"name": "skilled, butter", "aim": "skilled", "shake": 1.0, "buy": "cheapest", "recipe": "butter"},
	{"name": "skilled, cheese", "aim": "skilled", "shake": 1.0, "buy": "cheapest", "recipe": "cheese"},
	{"name": "casual (mixed timing, shakes half the time, slow to buy, butter)", "aim": "casual", "shake": 0.5, "buy": "slow", "recipe": "butter"},
	{"name": "casual, caramel", "aim": "casual", "shake": 0.5, "buy": "slow", "recipe": "caramel"},
	{"name": "casual, cheese", "aim": "casual", "shake": 0.5, "buy": "slow", "recipe": "cheese"},
	{"name": "novice (wild timing, never shakes, slow, butter)", "aim": "novice", "shake": 0.0, "buy": "slow", "recipe": "butter"},
	{"name": "novice, caramel", "aim": "novice", "shake": 0.0, "buy": "slow", "recipe": "caramel"},
	{"name": "novice, cheese", "aim": "novice", "shake": 0.0, "buy": "slow", "recipe": "cheese"},
	{"name": "never shakes (casual, butter)", "aim": "casual", "shake": 0.0, "buy": "slow", "recipe": "butter"},
	{"name": "low interaction (casual until the helper, then only buys)", "aim": "casual", "shake": 0.5, "buy": "slow", "recipe": "butter", "stop_after_helper": true},
	{"name": "never automates (skilled, caramel)", "aim": "skilled", "shake": 1.0, "buy": "main_only", "recipe": "caramel"},
	{"name": "automation first (casual, buys the ladder before the machine)", "aim": "casual", "shake": 0.5, "buy": "auto_first", "recipe": "butter"},
]

var _args := {}


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var v: String = raw[i + 1] if i + 1 < raw.size() and not raw[i + 1].begins_with("--") else ""
		_args[raw[i].trim_prefix("--")] = v
		i += 2 if v != "" else 1
	var econ := PopEconomy.load_default()
	var rows: Array[Dictionary] = []
	for p: Dictionary in PLAYERS:
		rows.append(run(p, econ, 7))
	var md := markdown(rows, econ)
	print(md)
	if _args.has("out"):
		var out := String(_args["out"])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		_write(out + "/stand_sim.md", md)
		_write(out + "/stand_sim.json", JSON.stringify({"_doc": "AUTOMATED SIMULATION on the real stand rules (tools/sim/stand.gd), seed 7, 20 minutes. Not human play.", "runs": rows}, "  "))
	var bad := rows.filter(func(r: Dictionary) -> bool: return not (r["violations"] as Array).is_empty())
	quit(1 if bad.size() > 0 else 0)


func _hold_ms(aim: String, st: Dictionary, rng: RandomNumberGenerator) -> int:
	var w: Array = st["window"]
	var mid := (float(w[0]) + float(w[1])) / 2.0
	match aim:
		"skilled":
			return int(mid + rng.randfn(0.0, 70.0))
		"novice":
			# Aims at the middle but misses wide: a 300 ms spread, a quarter burnt or quick.
			var r2 := rng.randf()
			if r2 < 0.75:
				return int(mid + rng.randfn(0.0, 300.0))
			return int(float(w[2]) + 200.0) if r2 < 0.85 else int(float(w[0]) * rng.randf_range(0.3, 0.7))
		_:
			var roll := rng.randf()
			if roll < 0.45:
				return int(mid + rng.randfn(0.0, 160.0))
			if roll < 0.7:
				return int(float(w[0]) - rng.randf_range(100.0, 500.0))
			if roll < 0.9:
				return int(float(w[1]) + rng.randf_range(80.0, 400.0))
			return int(float(w[2]) + 200.0)   # held on: burns


func run(p: Dictionary, econ: PopEconomy, seed: int) -> Dictionary:
	var rules: PopRules = load("res://variants/stand/stand_rules.gd").new(econ)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var aim := String(p["aim"])
	var t := 0
	var holding := false
	var press_at := 0
	var release_at := 0
	var shake_left := 0
	var next_shake := 0
	var next_input := 2500 if aim == "skilled" else 5000
	var spent := 0
	var violations: Array[String] = []
	var events := {}      # name -> first time
	var buys: Array = []   # [t, what]
	var level_at := {}
	var marks := {}
	var stop_pressing := false
	var buy_wait_until := -1
	while t < HORIZON:
		var st := rules.state()
		# The hand.
		if not stop_pressing:
			if holding:
				if shake_left > 0 and t >= next_shake and bool(st["heating"]):
					rules.execute({"type": "shake"})
					shake_left -= 1
					next_shake = t + 120
				if t >= release_at or not bool(st["heating"]):
					if bool(st["heating"]):
						rules.execute({"type": "release"})
					holding = false
					next_input = t + (300 if aim == "skilled" else rng.randi_range(500, 1500))
			elif t >= next_input and int(st["cooldown_left"]) == 0 and not bool(st["heating"]):
				if bool(rules.execute({"type": "press"})["ok"]):
					holding = true
					press_at = t
					release_at = t + _hold_ms(aim, rules.state(), rng)
					var wants_shake := bool(st["unlocked"]["shake"]) and not bool(st["motor"]) and rng.randf() < float(p["shake"])
					shake_left = int((econ.table("stand")["shake"] as Dictionary)["turns"]) if wants_shake else 0
					next_shake = t + 200
		# The recipe, once it unlocks.
		if bool(st["unlocked"]["recipes"]) and String(st["recipe"]) != String(p["recipe"]) and not bool(st["heating"]):
			if bool(rules.execute({"type": "recipe", "id": String(p["recipe"])})["ok"]):
				events["recipe"] = t
		# Buying.
		var mode := String(p["buy"])
		var main_cost: int = rules.cost()
		var auto_cost: int = rules.auto_cost() if bool(st["unlocked"]["auto"]) else -1
		var choice := ""
		match mode:
			"cheapest", "slow":
				if main_cost >= 0 and (auto_cost < 0 or main_cost <= auto_cost):
					choice = "main"
				elif auto_cost >= 0:
					choice = "auto"
			"main_only":
				choice = "main" if main_cost >= 0 else ""
			"auto_first":
				# Buys the ladder whenever it can, the machine otherwise (does not save).
				if auto_cost >= 0 and rules.money >= auto_cost:
					choice = "auto"
				elif main_cost >= 0:
					choice = "main"
		var price := main_cost if choice == "main" else auto_cost
		if choice != "" and price >= 0 and rules.money >= price:
			if mode == "slow" and buy_wait_until < 0:
				buy_wait_until = t + rng.randi_range(1500, 5000)
			if mode != "slow" or t >= buy_wait_until:
				var before: int = rules.money
				var r := rules.execute({"type": "buy" if choice == "main" else "buy_auto"})
				if bool(r["ok"]):
					spent += before - rules.money
					buys.append([t, choice if choice == "main" else "auto%d" % int(rules.state()["auto_level"])])
					buy_wait_until = -1
					if choice == "main":
						level_at[rules.level] = t
					else:
						var rung: int = rules.auto_level
						events["auto_%d" % rung] = t
						if rung >= 2 and bool(p.get("stop_after_helper", false)):
							stop_pressing = true
							events["stopped_pressing"] = t
				else:
					violations.append("%d: refused purchase %s" % [t, r])
		for k: String in ["shake", "auto", "recipes"]:
			if bool(st["unlocked"][k]) and not events.has("unlock_" + k):
				events["unlock_" + k] = t
		rules.advance(STEP)
		t += STEP
		rules.drain_events()
		if rules.money < 0:
			violations.append("%d: money %d" % [t, rules.money])
		if rules.money != rules.earned - spent:
			violations.append("%d: money %d != earned %d - spent %d" % [t, rules.money, rules.earned, spent])
			break
		for m: int in MARKS:
			if t == m:
				var s2 := rules.state()
				marks[str(m / 1000)] = {"level": rules.level, "auto": int(s2["auto_level"]), "money": rules.money, "earned": rules.earned,
					"manual": int(s2["manual_earned"]), "helper": int(s2["helper_earned"])}
	# Longest stretch with nothing bought, after the first three minutes.
	var longest := 0
	var prev := 180000
	for b: Array in buys:
		if int(b[0]) > 180000:
			longest = maxi(longest, int(b[0]) - prev)
			prev = int(b[0])
	var all_done := -1
	if rules.cost() < 0 and rules.auto_cost() < 0 and not buys.is_empty():
		all_done = int(buys[-1][0])
	else:
		longest = maxi(longest, HORIZON - prev)
	var fs := rules.state()
	return {"name": String(p["name"]), "events": events, "level_at": level_at, "marks": marks, "buys": buys.size(), "timeline": buys,
		"longest_no_buy_after_3min_s": longest / 1000.0, "all_bought_s": all_done / 1000.0 if all_done >= 0 else -1.0,
		"final": {"level": rules.level, "auto": int(fs["auto_level"]), "earned": rules.earned, "manual": int(fs["manual_earned"]),
			"helper": int(fs["helper_earned"]), "even_pops": int(fs["even_pops"]), "outcomes": fs["outcomes"]},
		"violations": violations}


func _s(ms: Variant) -> String:
	if ms == null:
		return "–"
	return "%d:%02d" % [int(ms) / 60000, (int(ms) / 1000) % 60]


func markdown(rows: Array[Dictionary], econ: PopEconomy) -> String:
	var out := "# Popcorn Stand pacing (AUTOMATED, real rules, seed 7, 20 minutes)\n\nScripted behaviours; what the numbers do, not whether it is fun.\n\n"
	out += "| player | Lv3 shake | Lv4 automation | Lv5 recipes | motor | helper | Lv @3 / 5 / 10 / 15 / 20 min | ladder @10 / 20 min | all bought | longest no-buy after 3:00 | helper share of 20 min | invariants |\n"
	out += "|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for r: Dictionary in rows:
		var e: Dictionary = r["events"]
		var m: Dictionary = r["marks"]
		var lv := []
		for k: String in ["180", "300", "600", "900", "1200"]:
			lv.append(str((m[k] as Dictionary)["level"]) if m.has(k) else "–")
		var lad := []
		for k: String in ["600", "1200"]:
			lad.append(str((m[k] as Dictionary)["auto"]) if m.has(k) else "–")
		var f: Dictionary = r["final"]
		var share := 100.0 * float(f["helper"]) / maxf(1.0, float(f["earned"]))
		out += "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %ds | %d%% | %s |\n" % [r["name"], _s(e.get("unlock_shake")), _s(e.get("unlock_auto")), _s(e.get("unlock_recipes")),
			_s(e.get("auto_1")), _s(e.get("auto_2")), " / ".join(lv), " / ".join(lad),
			("%s" % _s(int(float(r["all_bought_s"]) * 1000))) if float(r["all_bought_s"]) >= 0 else "no",
			int(r["longest_no_buy_after_3min_s"]), int(share), "ok" if (r["violations"] as Array).is_empty() else "%d" % (r["violations"] as Array).size()]
	out += "\n## Automation break-even (helper rungs, at the level the skilled player buys them)\n\n| rung | cost | cycle | share | pays per batch then | break-even |\n|---|---|---|---|---|---|\n"
	var ladder: Array = econ.table("stand")["auto"]
	var sk: Dictionary = rows[0]
	for i in ladder.size():
		var rg: Dictionary = ladder[i]
		if String(rg["kind"]) != "helper":
			out += "| %d motor | %d | – | – | every batch x%s | – |\n" % [i + 1, int(rg["cost"]), str((econ.table("stand")["shake"] as Dictionary)["mult"])]
			continue
		var at: Variant = (sk["events"] as Dictionary).get("auto_%d" % (i + 1))
		var lv := 0
		for l: Variant in (sk["level_at"] as Dictionary).keys():
			if at != null and int((sk["level_at"] as Dictionary)[l]) <= int(at):
				lv = maxi(lv, int(l))
		var pays := maxi(1, int(floor(econ.at("stand", "batch", lv) * float(rg["share"]))))
		var be := float(rg["cost"]) / (float(pays) / (float(rg["cycle_ms"]) / 1000.0))
		out += "| %d helper | %d | %.1fs | %.2f | %d (Lv%d) | %ds |\n" % [i + 1, int(rg["cost"]), float(rg["cycle_ms"]) / 1000.0, float(rg["share"]), pays, lv, int(be)]
	return out


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
