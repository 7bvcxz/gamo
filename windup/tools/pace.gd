extends SceneTree

## Runs the real rules (src/game/atelier.gd + data/balance.json) with scripted
## players and prints when each doll wakes. Not the game's view: the rules
## only, at fixed 1/60 s steps, so it answers in a second.
##
##   godot --headless --path windup --script res://tools/pace.gd [-- --seconds 600 --json /abs/out.json]
##
## Players (design/PLAYTEST_3MIN.md): engaged = presses 4/s from 2 s;
## holder = holds the key from 2 s (hold rate); novice = 2/s from 5 s, rests 3 s
## every 15 s; idle = 4/s until the first doll, then nothing.

const DT := 1.0 / 60.0


func _init() -> void:
	var args := RunConfig.parse_args(OS.get_cmdline_user_args())
	var seconds := float(args.get("seconds", "600"))
	var variant := String(args.get("variant", "base"))
	var b := Balance.load_variant(variant)
	print("variant %s" % variant)
	var out := {"variant": variant}
	for who: String in ["engaged", "holder", "novice", "idle"]:
		out[who] = _run(b, who, seconds)
		var r: Dictionary = out[who]
		print("%-8s awakenings %s | dolls@30/60/180/600 %s | player share@180 %.2f | longest gap(<=180) %.1f s" % [
			who, r["wakes"], r["dolls_at"], r["share_180"], r["longest_gap_180"]])
	if args.has("json"):
		var f := FileAccess.open(String(args["json"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  "))
	quit()


static func _run(b: Balance, who: String, seconds: float) -> Dictionary:
	var a := Atelier.new(b)
	var wakes: Array = []
	var seen := -1
	var next_press := 0.0
	var at := {}
	var share_180 := 0.0
	var steps := int(seconds / DT)
	for s in steps:
		var t := s * DT
		var active := false
		match who:
			"engaged":
				active = t >= 2.0
				if active and t >= next_press:
					a.wind()
					a.release()   # a tap lets go at once (A's spring; a no-op otherwise)
					next_press = t + 0.25
			"holder":
				if t >= 2.0 and t >= next_press:
					a.wind()
					# A: a holder lets go when the spring is full (the key strains).
					if b.spring_enabled and a.spring_fill() >= 0.999:
						a.release()
					next_press = t + 1.0 / b.hold_turns_per_second
			"novice":
				active = t >= 5.0 and fmod(t - 5.0, 15.0) < 12.0
				if active and t >= next_press:
					a.wind()
					a.release()
					next_press = t + 0.5
			"idle":
				if a.awake == 0 and a.waking < 0 and t >= 2.0 and t >= next_press:
					a.wind()
					a.release()
					next_press = t + 0.25
		a.tick(DT)
		if a.waking >= 0 and a.waking != seen:
			seen = a.waking
			wakes.append(snappedf(a.time, 0.1))
		for mark: int in [30, 60, 180, 600]:
			if not at.has(str(mark)) and t + DT >= mark:
				at[str(mark)] = a.awake + (1 if a.waking >= 0 else 0)
				if mark == 180:
					var total := a.manual_energy + a.auto_energy
					share_180 = a.manual_energy / total if total > 0.0 else 0.0
	var gaps: Array = []
	var prev := 0.0
	for w: float in wakes:
		if w <= 180.0:
			gaps.append(w - prev)
			prev = w
	var longest := 0.0
	for g: float in gaps:
		longest = maxf(longest, g)
	return {"wakes": wakes, "dolls_at": at, "share_180": share_180, "longest_gap_180": longest}
