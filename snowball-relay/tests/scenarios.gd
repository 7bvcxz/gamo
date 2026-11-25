extends SceneTree
# Deterministic input-economy comparison. Three policies play the SAME matched
# state (fixed upgrade levels, no buying) for fixed windows:
#   none       -- no touch at all
#   occasional -- one push (strength 0.8) each time the ball has stopped
#   relaxed    -- one push each time the ball has slowed below 15% of its push speed
#   spam       -- one push every 0.125 s, nonstop (8 Hz)
# A touch is counted as 0.2 s of finger-down (a short swipe), so
# input fraction = touches * 0.2 / window. This is a model of input time, not a
# measurement of a hand.
#   godot --headless --path snowball-relay --script res://tests/scenarios.gd -- [--write]
const Sim := preload("res://scripts/Sim.gd")
const TOUCH_S: float = 0.2
const WINDOWS: Array[float] = [10.0, 30.0, 60.0, 180.0]
const STATES: Array = [
	["fresh   lv 0/0/0/0/0", [0, 0, 0, 0, 0]],
	["early   lv 2/2/2/2/1", [2, 2, 2, 2, 1]],
	["mid     lv 4/4/4/3/2", [4, 4, 4, 3, 2]],
	["late    lv 8/7/7/7/7", [8, 7, 7, 7, 7]],
]

func play(levels: Array, policy: String, window: float) -> Dictionary:
	var s: RefCounted = Sim.new(7)
	for i in 5:
		s.lv[i] = int(levels[i])
	var r0: float = s.radius()
	var touches: int = 0
	var next_spam: float = 0.0
	var dt: float = 1.0 / 60.0
	var t: float = 0.0
	while t < window:
		if policy == "occasional" and s.speed <= 0.0:
			s.push(0.8)
			touches += 1
		elif policy == "relaxed" and s.speed < 0.15 * s.v0():
			s.push(0.8)
			touches += 1
		elif policy == "spam" and t >= next_spam:
			s.push(0.8)
			touches += 1
			next_spam = t + 0.125
		s.step(dt)
		t += dt
	return {
		"earned": s.earned, "dist": s.dist, "growth": s.radius() / r0, "touches": touches,
		"input": float(touches) * TOUCH_S / window,
		"avg_roll": (s.roll_len_sum / float(s.rolls)) if s.rolls > 0 else (s.last_roll_len if s.last_roll_len > 0.0 else 0.0),
		"moving": s.moving_time / window,
	}

func _init() -> void:
	var out: PackedStringArray = PackedStringArray()
	out.append("# Snowball Relay -- input economy (deterministic, matched state, no buying)")
	out.append("")
	out.append("| state | window | policy | touches | input % | snow | snow/touch | distance | radius x | avg roll s | moving % |")
	out.append("|---|---|---|---|---|---|---|---|---|---|---|")
	var worst_ratio: float = 0.0
	var ratios: PackedStringArray = PackedStringArray()
	for st in STATES:
		for w in WINDOWS:
			var res: Dictionary = {}
			for pol in ["none", "occasional", "relaxed", "spam"]:
				var r: Dictionary = play(st[1], pol, w)
				res[pol] = r
				out.append("| %s | %ds | %s | %d | %.0f | %.0f | %.1f | %.0f | %.2f | %.1f | %.0f |" % [st[0], int(w), pol, r["touches"], 100.0 * r["input"], r["earned"], (r["earned"] / r["touches"]) if r["touches"] > 0 else 0.0, r["dist"], r["growth"], r["avg_roll"], 100.0 * r["moving"]])
			var ratio: float = res["spam"]["earned"] / maxf(res["relaxed"]["earned"], 0.001)
			worst_ratio = maxf(worst_ratio, ratio)
			ratios.append("%s %ds spam/relaxed = %.2fx snow for %.0fx the touches (%d vs %d)" % [st[0].substr(0, 5), int(w), ratio, float(res["spam"]["touches"]) / maxf(float(res["relaxed"]["touches"]), 1.0), res["spam"]["touches"], res["relaxed"]["touches"]])
	out.append("")
	out.append("## spam / relaxed snow ratio")
	for l in ratios:
		out.append("- " + l)
	out.append("")
	out.append("worst spam/relaxed ratio: %.2fx" % worst_ratio)
	var text: String = "\n".join(out)
	print(text)
	var limit: float = 2.5
	print("%s: worst spam/relaxed %.2fx (limit %.1fx)" % ["PASS" if worst_ratio <= limit else "FAIL", worst_ratio, limit])
	if OS.get_cmdline_user_args().has("--write"):
		var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://evidence/step03/scenarios.md"), FileAccess.WRITE)
		f.store_string(text + "\n")
		f.close()
	quit(0 if worst_ratio <= limit else 1)
