extends SceneTree
# Deterministic input-economy comparison. Three policies play the SAME matched
# state (fixed upgrade levels, no buying) for fixed windows:
#   none    -- no touch at all
#   relaxed -- one tap every 4 s at a spot that changes each time
#   ready   -- one tap whenever 75% of the sheet is full again (at least 1 s apart)
#   spam    -- one tap every 0.125 s, nonstop, at changing spots
# A touch is counted as 0.15 s of finger-down, so input fraction = touches *
# 0.15 / window. A model of input time, not a measurement of a hand.
#   godot --headless --path bubble-wrap-empire --script res://tests/scenarios.gd -- [--write]
const Sim := preload("res://scripts/Sim.gd")
const TOUCH_S: float = 0.15
const WINDOWS: Array[float] = [10.0, 30.0, 60.0, 180.0]
const STATES: Array = [
	["fresh   lv 0/0/0/0/0", [0, 0, 0, 0, 0]],
	["early   lv 1/2/1/0/0", [1, 2, 1, 0, 0]],
	["mid     lv 3/4/4/2/1", [3, 4, 4, 2, 1]],
	["late    lv 7/8/7/5/3", [7, 8, 7, 5, 3]],
]

func spot(k: int) -> Vector2:
	return Vector2(fmod(float(k) * 2.37, 6.0), fmod(float(k) * 3.11, 7.8))

func play(levels: Array, policy: String, window: float) -> Dictionary:
	var s: RefCounted = Sim.new(5)
	for i in 5:
		s.lv[i] = int(levels[i])
	var touches: int = 0
	var accepted: int = 0
	var next_t: float = 0.0
	var dt: float = 1.0 / 60.0
	var t: float = 0.0
	while t < window:
		var go: bool = false
		match policy:
			"relaxed":
				go = t >= next_t
				if go:
					next_t = t + 4.0
			"ready":
				go = t >= next_t and s.full_count() >= 52
				if go:
					next_t = t + 1.0
			"spam":
				go = t >= next_t
				if go:
					next_t = t + 0.125
		if go:
			touches += 1
			if s.trigger(spot(touches)) >= 0:
				accepted += 1
		s.step(dt)
		t += dt
	return {
		"earned": s.earned, "pops": s.pops, "touches": touches, "accepted": accepted,
		"input": float(touches) * TOUCH_S / window,
		"waves": s.wave_total,
		"avg_wave": (float(s.wave_pops_sum) / float(s.wave_total)) if s.wave_total > 0 else 0.0,
		"max_wave": s.wave_max,
		"avg_secs": (s.wave_secs_sum / float(s.wave_total)) if s.wave_total > 0 else 0.0,
		"full": float(s.full_count()) / float(s.pos.size()),
	}

func _init() -> void:
	var out: PackedStringArray = PackedStringArray()
	out.append("# Bubble Wrap Empire -- input economy (deterministic, matched state, no buying)")
	out.append("")
	out.append("| state | window | policy | touches | accepted | input % | POP | POP/touch | waves | avg wave | max wave | avg wave s | sheet full % |")
	out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var worst: float = 0.0
	var ratios: PackedStringArray = PackedStringArray()
	for st in STATES:
		for w in WINDOWS:
			var res: Dictionary = {}
			for pol in ["none", "relaxed", "ready", "spam"]:
				var r: Dictionary = play(st[1], pol, w)
				res[pol] = r
				out.append("| %s | %ds | %s | %d | %d | %.0f | %.0f | %.1f | %d | %.1f | %d | %.2f | %.0f |" % [st[0], int(w), pol, r["touches"], r["accepted"], 100.0 * r["input"], r["earned"], (r["earned"] / r["touches"]) if r["touches"] > 0 else 0.0, r["waves"], r["avg_wave"], r["max_wave"], r["avg_secs"], 100.0 * r["full"]])
			var ratio: float = res["spam"]["earned"] / maxf(res["ready"]["earned"], 0.001)
			worst = maxf(worst, ratio)
			ratios.append("%s %ds spam/ready = %.2fx POP for %.0fx the touches (%d vs %d)" % [st[0].substr(0, 5), int(w), ratio, float(res["spam"]["touches"]) / maxf(float(res["ready"]["touches"]), 1.0), res["spam"]["touches"], res["ready"]["touches"]])
	out.append("")
	out.append("## spam / ready POP ratio")
	for l in ratios:
		out.append("- " + l)
	out.append("")
	out.append("worst spam/ready ratio: %.2fx" % worst)
	var text: String = "\n".join(out)
	print(text)
	var limit: float = 1.5
	print("%s: worst spam/ready %.2fx (limit %.1fx)" % ["PASS" if worst <= limit else "FAIL", worst, limit])
	if OS.get_cmdline_user_args().has("--write"):
		var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://evidence/step03/scenarios.md"), FileAccess.WRITE)
		f.store_string(text + "\n")
		f.close()
	quit(0 if worst <= limit else 1)
