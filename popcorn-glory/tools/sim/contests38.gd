extends SceneTree
## Step 38: the contests on the canonical model. SIMULATED TARGETS, NOT PLAYER ENJOYMENT.
##   godot --headless --path popcorn-glory --script res://tools/sim/contests38.gd -- <out_dir>
## Writes <out>/contests38.json:
##  * streak: a plain stand (sign 2) when contests open, a hand that hits the gold with
##    probability p (0.5, 0.75, 0.9) -- tiers reached, prize - fee, against what the stand
##    earned in the same minutes
##  * factory: the flavor factory hour (Steps 34-37's) on three seeds -- contests ignored, and
##    entered whenever one is open (a player who takes every one, the hand as in Step 37's
##    sims) -- coins a minute, each format's tiers, prizes and fees
##  * sabotage: pausing every machine for the three minutes before balanced line does not
##    lower its mark (the best stretch of the last ten minutes)
## Asserts conservation, no wrong bag, money only from sales, costs, prizes and fees.
const Factory := preload("res://variants/factory/factory_rules.gd")


func _flavor_factory(seed_value: int) -> PopRules:
	var f: PopRules = Factory.new(null, seed_value)
	f.sign_tier = 6
	f.packer_tier = 3
	f.level = 6
	f.stats["sold"] = 1
	f.stats["packed"] = 1
	f.money = 1 << 30
	for id: String in ["M07", "M10", "M07", "M01", "M16", "U02", "U03", "U01", "M13", "M12"]:
		f.execute({"type": "build", "machine": id, "floor": "kitchen"})
	for row: Array in [["bagger", ""], ["P07", ""], ["P05", "auto"], ["P06", "auto"], ["line", ""], ["bagger", ""], ["U04", ""], ["P05", "spicy"], ["P06", "cocoa"]]:
		if String(row[0]) == "line":
			f.execute({"type": "buy_line", "floor": "packing"})
			continue
		var r: Dictionary = f.execute({"type": "build", "machine": row[0], "floor": "packing"})
		if String(row[1]) != "":
			f.execute({"type": "set_flavor", "id": r["machine"], "flavor": row[1]})
	for id in ["S03", "S05", "S08", "S01"]:
		f.execute({"type": "build", "machine": id, "floor": "shop"})
	f.money = 2000
	f.stats["sold"] = 15
	return f


func _check(f: PopRules, label: String) -> void:
	assert(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "portions " + label)
	assert(int(f.stats.get("wrong_sku", 0)) == 0, "wrong bag " + label)
	assert(f.money >= 0, "money " + label)


## The hand of Step 37's sims: a pop every few seconds, held 1.5 s.
func _hand(f: PopRules, i: int) -> void:
	if i % 3 == 0 and f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
		f.execute({"type": "press"})
	f.advance(1500)
	if f.heating:
		f.execute({"type": "release"})


## A hand that lets go in the gold with probability p (else 150 ms past it).
func _skilled_pop(f: PopRules, rng: RandomNumberGenerator, p: float) -> void:
	for i in 300:
		if f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
			break
		f.advance(100)
	if not bool(f.execute({"type": "press"})["ok"]):
		return
	var hold := int(f.window_start()) + 60 if rng.randf() < p else int(f.window_end()) + 150
	f.advance(hold)
	if f.heating:
		f.execute({"type": "release"})
	f.advance(400)


func _streak(seed_value: int, p: float, attempts: int) -> Dictionary:
	var f: PopRules = Factory.new(null, seed_value)
	f.sign_tier = 2
	f.packer_tier = 1
	f.level = 2
	f.stats["sold"] = 15
	f.stats["packed"] = 1
	f.money = 60
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7 + int(p * 100)
	var tiers := [0, 0, 0, 0]
	var net := 0
	var book_ms := 0
	var book_coins := 0
	for k in attempts:
		for i in 400:   # wait for it to be posted (rest)
			if (f.contests["posted"] as Array).any(func(x: Dictionary) -> bool: return String(x["id"]) == "perfect_streak"):
				break
			_skilled_pop(f, rng, p)
		var b0: int = f.book()
		var t0 := int(f.flow_ms)
		var r: Dictionary = f.execute({"type": "contest_enter", "id": "perfect_streak"})
		assert(bool(r["ok"]), "entered: %s" % r.get("reason", ""))
		var seq := int(r["seq"])
		while not (f.contests["entry"] as Dictionary).is_empty():
			_skilled_pop(f, rng, p)
		var res: Dictionary = (f.contests["results"] as Array).back()
		assert(int(res["seq"]) == seq)
		tiers[int(res["tier"])] += 1
		net += int(res["prize"]) - int(res["fee"])
		book_ms += int(f.flow_ms) - t0
		book_coins += f.book() - b0
		_check(f, "streak %d %.2f" % [seed_value, p])
	return {"p": p, "attempts": attempts, "none_bronze_silver_gold": tiers, "net_per_attempt": snappedf(float(net) / attempts, 0.1),
		"stand_coins_per_min_meanwhile": snappedf(float(book_coins) / (float(book_ms) / 60000.0), 0.1), "minutes_per_attempt": snappedf(float(book_ms) / attempts / 60000.0, 0.01)}


func _hour(seed_value: int, enter: bool, minutes: int) -> Dictionary:
	var f := _flavor_factory(seed_value)
	var money0 := int(f.money)
	var book0: int = f.book()
	var by := {}
	for i in minutes * 40:
		_hand(f, i)
		if enter and i % 40 == 0 and (f.contests["entry"] as Dictionary).is_empty():
			for p: Dictionary in f.contests["posted"]:
				if f.contest_problem(String(p["id"])) == "" and bool(f.execute({"type": "contest_enter", "id": p["id"]})["ok"]):
					break
		if i % 40 == 39:
			_check(f, "%d %s" % [seed_value, enter])
	var prizes := int(f.stats.get("contest_prizes", 0))
	var fees := int(f.stats.get("contest_fees", 0))
	assert(int(f.money) - money0 == f.book() - book0 + prizes - fees, "money only from sales, costs, prizes and fees")
	var mins := float(f.flow_ms) / 60000.0
	return {"book_per_min": snappedf(float(f.book() - book0) / mins, 0.1), "prizes": prizes, "fees": fees, "entered": int(f.stats.get("contests_entered", 0)),
		"won": int(f.stats.get("contests_won", 0)), "trophies": f.contests["trophies"], "results_last6": f.contests["results"], "sold": f.stats["sold"],
		"news_skipped": int(f.stats.get("news_skipped", 0)), "prizes_share_of_book": snappedf(float(prizes - fees) / maxf(1.0, float(f.book() - book0)) * 100.0, 0.1)}


func _sabotage(seed_value: int) -> Dictionary:
	var out := {}
	for pause: bool in [false, true]:
		var f := _flavor_factory(seed_value)
		for i in 10 * 40:
			_hand(f, i)
		if pause:
			f.execute({"type": "pause_all", "paused": true})
		for i in 3 * 40:
			_hand(f, i)
		if pause:
			f.execute({"type": "pause_all", "paused": false})
		out["paused" if pause else "running"] = {"mark": f.contest_baseline(), "tiers": f.contest_tiers("balanced_line")}
	return out


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var minutes := int(args[1]) if args.size() > 1 else 60
	var res := {"minutes": minutes, "streak": [], "factory": {}, "sabotage": {}}
	for p: float in [0.5, 0.75, 0.9]:
		var t0 := Time.get_ticks_msec()
		var s := _streak(3801, p, 12)
		res["streak"].append(s)
		print("streak p=%.2f: %s  [%d ms]" % [p, s, Time.get_ticks_msec() - t0])
	for seed_value in [3801, 3802, 3803]:
		for enter: bool in [false, true]:
			var t0 := Time.get_ticks_msec()
			var h := _hour(seed_value, enter, minutes)
			res["factory"]["%d_%s" % [seed_value, "enter" if enter else "ignore"]] = h
			print("%d %s: book %.1f/min, entered %d, won %d, prizes %d, fees %d (%.1f%% of the book), sold %d  [%d ms]" % [seed_value, "enter" if enter else "ignore", h["book_per_min"], h["entered"], h["won"], h["prizes"], h["fees"], h["prizes_share_of_book"], h["sold"], Time.get_ticks_msec() - t0])
	res["sabotage"] = _sabotage(3804)
	print("sabotage: %s" % [res["sabotage"]])
	var fo := FileAccess.open(out + "/contests38.json", FileAccess.WRITE)
	fo.store_string(JSON.stringify(res, " "))
	fo.close()
	quit(0)
