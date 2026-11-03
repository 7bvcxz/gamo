extends "res://tests/framework/test_case.gd"

## Accelerated runs of the real rules (Step 07 V2): 3, 10, 30 and 60 minutes,
## every variant, an engaged player and a hands-off one. No NaN, no negative
## energy, exact accounting, growth capped by what the rules allow, and no
## softlock: the next doll is always reachable.

const DT := 0.1


func _run(variant: String, minutes: float, engaged: bool) -> Dictionary:
	var b := Balance.load_variant(variant)
	var a := Atelier.new(b)
	var steps := int(minutes * 60.0 / DT)
	var worst_jump := 0.0
	var problems: Array[String] = []
	var next_press := 0.0
	var last_energy_total := 0.0
	for s in steps:
		var t := s * DT
		var winding := engaged or (a.awake == 0 and a.waking < 0)
		if winding and t >= next_press:
			a.wind()
			a.release()
			next_press = t + 0.25
		a.tick(DT)
		var total := a.manual_energy + a.auto_energy
		# The most one step can add: the cap's turns at full power, every doll's
		# rate, and C's kick for a doll finishing this step.
		var allowed := (b.max_turns_per_second * DT + 1.0) * a.wind_power() + a.auto_rate() * DT
		if b.kick_seconds > 0.0 and a.awake > 0:
			allowed += b.rates[a.awake - 1] * b.kick_seconds
		worst_jump = maxf(worst_jump, (total - last_energy_total) / maxf(allowed, 1e-9))
		last_energy_total = total
		if is_nan(a.energy) or a.energy < -1e-9:
			problems.append("bad energy %f at %f" % [a.energy, t])
			break
		if absf(a.accounted_energy() - a.energy) > 1e-6 * maxf(1.0, total):
			problems.append("accounting drift at %f" % t)
			break
	return {"awake": a.awake, "problems": problems, "worst_jump": worst_jump, "target": a.target(), "rate": a.auto_rate(), "b": b}


func test_long_runs_every_variant() -> void:
	for v: String in ["base", "a", "b", "c"]:
		for minutes: float in [3.0, 10.0, 30.0, 60.0]:
			var r := _run(v, minutes, true)
			assert_eq(r["problems"], [] as Array[String], "%s %d min engaged" % [v, minutes])
			assert_true(float(r["worst_jump"]) <= 1.0 + 1e-6, "%s %d min: growth within what the rules allow (%.3f)" % [v, minutes, r["worst_jump"]])
		var full := _run(v, 60.0, true)
		assert_eq(full["awake"], 12, "%s: an engaged hour wakes every doll" % v)


func test_hands_off_never_softlocks() -> void:
	# After the first doll the hands-off player never presses again; the dolls'
	# own rate must keep waking the next one.
	for v: String in ["base", "a", "b", "c"]:
		var r := _run(v, 60.0, false)
		assert_eq(r["problems"], [] as Array[String], "%s hands-off hour" % v)
		assert_true(int(r["awake"]) >= 4, "%s: hands-off still progresses (%d dolls in an hour)" % [v, r["awake"]])
		assert_true(float(r["rate"]) > 0.0, "%s: a working doll keeps the atelier going" % v)
