extends SceneTree
## Step 36: the cast and the shop's popularity on the canonical model. SIMULATED TARGETS,
## NOT PLAYER ENJOYMENT.
##   godot --headless --path popcorn-glory --script res://tools/sim/customers36.gd -- <out_dir> [minutes]
## Writes <out>/customers36.json:
##  * signs: each sign tier's measured mean wait (popularity held still) against its table
##  * mixes: three seeds of the flavor factory hour (Step 34/35's), who came, who walked past,
##    who gave up, what each kind ordered, the popularity's path -- with the popularity's
##    arrival effect on and off (its cost or worth in coins)
##  * starved: a sign-6 shop whose kitchen stops for ten minutes, then cooks again -- the queue
##    cap, people walking past, the popularity falling and coming back
## Asserts conservation, no wrong bag and the queue cap every minute.
const Factory := preload("res://variants/factory/factory_rules.gd")


func _flavor_factory(seed_value: int, effect: bool) -> PopRules:
	var f: PopRules = Factory.new(null, seed_value)
	if not effect:
		f.economy.table("factory")["reputation"]["arrival_effect"] = 0.0
	f.sign_tier = 6
	f.packer_tier = 3
	f.level = 6
	f.stats["sold"] = 1
	f.stats["packed"] = 1
	f.money = 1 << 30
	for id in ["M07", "M10", "M07", "M01", "M16", "U02", "U03", "U01", "M13", "M12"]:
		f.execute({"type": "build", "machine": id, "floor": "kitchen"})
	for row: Array in [["bagger", ""], ["P07", ""], ["P05", "cheese"], ["P06", "caramel"], ["line", ""], ["bagger", ""], ["U04", ""], ["P05", "spicy"], ["P06", "cocoa"]]:
		if String(row[0]) == "line":
			f.execute({"type": "buy_line", "floor": "packing"})
			continue
		var r: Dictionary = f.execute({"type": "build", "machine": row[0], "floor": "packing"})
		if String(row[1]) != "":
			f.execute({"type": "set_flavor", "id": r["machine"], "flavor": row[1]})
	for id in ["S03", "S05", "S08", "S01"]:
		f.execute({"type": "build", "machine": id, "floor": "shop"})
	f.money = 2000
	f.stats["sold"] = 0
	return f


func _check(f: PopRules, label: String) -> void:
	assert(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "portions " + label)
	assert(int(f.stats.get("wrong_sku", 0)) == 0, "wrong bag " + label)
	assert(f.queue.size() <= int(f.queue_cap()), "queue cap " + label)
	assert(f.money >= 0, "money " + label)


func _hand(f: PopRules, i: int) -> void:
	# The Step 34 sim hand: a press every 4.5 s, held 1.5 s.
	if i % 3 == 0 and f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
		f.execute({"type": "press"})
	f.advance(1500)
	if f.heating:
		f.execute({"type": "release"})


func _hour(seed_value: int, effect: bool, minutes: int) -> Dictionary:
	var f := _flavor_factory(seed_value, effect)
	var path: Array = []
	for i in minutes * 40:
		_hand(f, i)
		if i % 40 == 39:
			_check(f, "mix %d" % seed_value)
			path.append(snappedf(f.popularity, 0.1))
	var costs := float(f.stats["upkeep_paid"]) + float(f.stats.get("kernels_paid", 0)) + float(f.stats.get("oil_paid", 0)) + float(f.stats.get("ingredient_coins", 0))
	var mins := float(f.flow_ms) / 60000.0
	return {"net_per_min": snappedf((float(f.stats["revenue"]) - costs) / mins, 0.1), "sold": f.stats["sold"], "happy_sales": int(f.stats.get("happy_sales", 0)),
		"abandoned": f.stats["abandoned"], "passed_by": f.stats["passed_by"], "arrived_who": f.stats.get("arrived_who", {}), "passed_by_who": f.stats.get("passed_by_who", {}),
		"flavor_sold": f.stats.get("flavor_sold", {}), "mix_sold": int(f.stats.get("mix_sold", 0)), "popularity_by_minute": path, "stars_end": f.stars(),
		"customers_per_min_end": snappedf(f.customers_per_min(), 0.1), "visitors": f.stats.get("visitors", 0)}


func _signs(minutes: int) -> Array:
	var out: Array = []
	for tier in 7:
		var f: PopRules = Factory.new(null, 3600 + tier)
		f.economy.table("factory")["reputation"]["arrival_effect"] = 0.0
		f.sign_tier = tier
		f.advance(minutes * 60000)
		var log: Array = f.arrival_log
		var gaps: Array = []
		for i in range(3, log.size()):
			gaps.append(int(log[i]) - int(log[i - 1]))
		var mean := 0.0
		for g: int in gaps:
			mean += g
		mean /= maxf(1.0, gaps.size())
		out.append({"tier": tier, "expected_ms": f.mean_wait_ms(tier), "measured_ms": snappedf(mean, 1.0), "visitors": f.stats["visitors"], "min_ms": gaps.min(), "max_ms": gaps.max()})
	return out


func _starved() -> Dictionary:
	var f := _flavor_factory(3700, true)
	var path: Array = []
	var longest := 0
	for i in 40 * 30:
		var stopped := i >= 40 * 5 and i < 40 * 15   # the kitchen stops from minute 5 to 15
		if stopped:
			for m: Dictionary in f.machines:
				if f._is_kettle(m) and String(m["state"]) != "paused":
					f.execute({"type": "pause_machine", "id": m["id"], "paused": true})
		elif i == 40 * 15:
			for m: Dictionary in f.machines:
				if f._is_kettle(m):
					f.execute({"type": "pause_machine", "id": m["id"], "paused": false})
		if stopped:
			f.advance(1500)
		else:
			_hand(f, i)
		longest = maxi(longest, f.queue.size())
		if i % 40 == 39:
			_check(f, "starved")
			path.append([i / 40 + 1, snappedf(f.popularity, 0.1), f.stats["abandoned"], f.stats["passed_by"], f.stats["sold"]])
	return {"by_minute": path, "queue_cap": f.queue_cap(), "longest_queue": longest}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var minutes := int(args[1]) if args.size() > 1 else 60
	var res := {"minutes": minutes, "signs": _signs(minutes), "mixes": {}, "starved": {}}
	for s: Dictionary in res["signs"]:
		print("sign %d: expected %d ms, measured %.0f ms" % [s["tier"], s["expected_ms"], s["measured_ms"]])
	for seed_value in [3601, 3602, 3603]:
		for effect: bool in [true, false]:
			var key := "%d_%s" % [seed_value, "popularity" if effect else "steady"]
			res["mixes"][key] = _hour(seed_value, effect, minutes)
			print("%s: net %.1f/min, sold %d, stars %d" % [key, res["mixes"][key]["net_per_min"], res["mixes"][key]["sold"], res["mixes"][key]["stars_end"]])
	res["starved"] = _starved()
	print("starved: %s" % [res["starved"]["by_minute"]])
	var fo := FileAccess.open(out + "/customers36.json", FileAccess.WRITE)
	fo.store_string(JSON.stringify(res, " "))
	fo.close()
	quit(0)
