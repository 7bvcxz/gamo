extends SceneTree

## Scripted players on the real rules for three minutes -- the same rules
## script and the same session log the game uses, no pictures. An objective
## measurement of what the numbers do, NOT a judgement of fun.
##
##   godot --headless --path popcorn-glory --script res://tools/selftest.gd -- [--json /abs/out.json] [--md /abs/out.md]
##
## Every player makes its first input at 2 s and buys 1.5 s after an upgrade
## becomes affordable (design/model/pace_model.py's assumptions, so the two can
## be compared). Fixed seeds: the same build gives the same table.

const HORIZON := 180000
const FIRST_INPUT := 2000
const REACT := 1500

const MODELS := [
	{"name": "A steady 2.5 taps/s", "exp": "click", "kind": "taps", "rate": 2.5},
	{"name": "A slow 1.2 taps/s", "exp": "click", "kind": "taps", "rate": 1.2},
	{"name": "B skilled (aims at the gold's middle)", "exp": "perfect", "kind": "hold", "mix": {"perfect": 0.8, "late": 0.15, "early": 0.05}},
	{"name": "B novice (35% gold, 10% burnt)", "exp": "perfect", "kind": "hold", "mix": {"early": 0.2, "perfect": 0.35, "late": 0.35, "burnt": 0.1}},
	{"name": "C steady 2.5 taps/s", "exp": "explosion", "kind": "taps", "rate": 2.5},
	{"name": "C slow 1.2 taps/s", "exp": "explosion", "kind": "taps", "rate": 1.2},
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rows: Array[Dictionary] = []
	for m: Dictionary in MODELS:
		rows.append(_play(m))
	var md := _markdown(rows)
	print(md)
	var i := 0
	while i < args.size():
		if args[i] == "--json" and i + 1 < args.size():
			var f := FileAccess.open(args[i + 1], FileAccess.WRITE)
			f.store_string(JSON.stringify({"_doc": "Scripted players on the real rules (tools/selftest.gd). Objective measurements, not human fun.", "rows": rows}, "  "))
		if args[i] == "--md" and i + 1 < args.size():
			var f2 := FileAccess.open(args[i + 1], FileAccess.WRITE)
			f2.store_string(md)
		i += 1
	quit(0)


func _play(m: Dictionary) -> Dictionary:
	var rules := PopRegistry.make_rules(String(m["exp"]))
	var session := PopSession.new(String(m["exp"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var t := 0
	var next_input := FIRST_INPUT
	var buy_at := -1
	var holding := false
	var release_at := 0
	var max_gap := 0
	var last_earn := -1
	var earn_log: Array = []   # [t, amount]
	while t < HORIZON:
		# Inputs due at this millisecond.
		if String(m["kind"]) == "taps":
			if t >= next_input:
				session.record_input(t, "press")
				rules.execute({"type": "press"})
				next_input += int(round(1000.0 / float(m["rate"])))
		else:
			var st := rules.state()
			if holding and t >= release_at:
				session.record(t, "release", {})
				rules.execute({"type": "release"})
				holding = false
				next_input = t + 300 + int(st["window"][0]) * 0   # the thumb comes back after 0.3 s
			elif holding and not bool(rules.state()["heating"]):
				holding = false       # it burnt by itself while held
				next_input = t + 300
			elif not holding and t >= next_input and int(rules.state()["cooldown_left"]) == 0:
				var w: Array = rules.state()["window"]
				var kind := _pick(m["mix"], rng)
				var hold := 0
				match kind:
					"early": hold = int(int(w[0]) * 0.7)
					"perfect": hold = (int(w[0]) + int(w[1])) / 2 + rng.randi_range(-40, 40)
					"late": hold = (int(w[1]) + int(w[2])) / 2
					"burnt": hold = int(w[2]) + 400
				session.record_input(t, "press")
				rules.execute({"type": "press"})
				holding = true
				release_at = t + hold
		var events := rules.drain_events()
		for e: Dictionary in events:
			if String(e["type"]) == "earn":
				if last_earn >= 0:
					max_gap = maxi(max_gap, int(e["t"]) - last_earn)
				last_earn = int(e["t"])
				earn_log.append([int(e["t"]), int(e["data"]["amount"])])
		session.record_events(events)
		session.observe(t, rules)
		if buy_at < 0 and rules.can_buy():
			buy_at = t + REACT
		if buy_at >= 0 and t >= buy_at:
			rules.execute({"type": "buy"})
			session.record_events(rules.drain_events())
			buy_at = -1
		rules.advance(1)
		t += 1
	session.observe(t, rules)
	var ups: Array[int] = session.upgrades
	var by := func(ms: int) -> int: return ups.filter(func(x: int) -> bool: return x <= ms).size()
	# Income over the last 30 s, for 'how far is the next upgrade at 3:00'.
	var recent := 0
	for e: Array in earn_log:
		if int(e[0]) >= HORIZON - 30000:
			recent += int(e[1])
	var rate := recent / 30.0
	var need := rules.cost() - rules.money if rules.cost() >= 0 else 0
	var ms_d: Dictionary = session.milestones
	return {
		"model": m["name"], "exp": m["exp"], "level": rules.level, "money": rules.money, "earned": rules.earned,
		"inputs": session.inputs, "first_earn_ms": int(ms_d.get("first_earn", -1)),
		"first_affordable_ms": int(ms_d.get("first_affordable", -1)), "first_upgrade_ms": int(ms_d.get("first_upgrade", -1)),
		"upgrades_by_60": by.call(60000), "upgrades_by_180": by.call(180000), "upgrade_times_ms": ups,
		"next_upgrade_s_at_180": (need / rate) if rate > 0 else -1.0, "longest_gap_between_earnings_ms": max_gap,
		"outcomes": rules.state().get("outcomes", {}),
	}


func _pick(mix: Dictionary, rng: RandomNumberGenerator) -> String:
	var x := rng.randf()
	var acc := 0.0
	for k: String in mix.keys():
		acc += float(mix[k])
		if x <= acc:
			return k
	return String(mix.keys()[mix.size() - 1])


func _markdown(rows: Array[Dictionary]) -> String:
	var s := "| player model (scripted) | level at 3:00 | first $ (s) | 1st upgrade affordable (s) | 1st bought (s) | upgrades by 60 s | by 180 s | next upgrade at 3:00 (s away) | longest wait between earnings (s) | inputs |\n"
	s += "|---|---|---|---|---|---|---|---|---|---|\n"
	for r: Dictionary in rows:
		s += "| %s | Lv%d | %.1f | %.1f | %.1f | %d | %d | %.1f | %.1f | %d |\n" % [r["model"], r["level"],
			r["first_earn_ms"] / 1000.0, r["first_affordable_ms"] / 1000.0, r["first_upgrade_ms"] / 1000.0,
			r["upgrades_by_60"], r["upgrades_by_180"], r["next_upgrade_s_at_180"], r["longest_gap_between_earnings_ms"] / 1000.0, r["inputs"]]
	return s
