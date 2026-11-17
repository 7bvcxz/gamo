extends SceneTree
## Step 37: the news on the canonical model. SIMULATED TARGETS, NOT PLAYER ENJOYMENT.
##   godot --headless --path popcorn-glory --script res://tools/sim/news37.gd -- <out_dir> [minutes]
## Writes <out>/news37.json:
##  * hours: the flavor factory hour (Steps 34-36's) on three seeds -- news off, news on (the
##    hand ignores the paper), news on with every flavor event focused (the card's button),
##    news on with U07 (focuses by itself) -- coins a minute, sales, the events that came,
##    what each brought (customers asking, bags sold) against the same minutes without it
##  * plain: a butter-only shop's hour (which events can come to it)
##  * steady: after each event the modifiers are back to the base (checked every second)
## Asserts conservation, no wrong bag, the queue cap and no money from nothing.
const Factory := preload("res://variants/factory/factory_rules.gd")
var ahead_override := -1   ## [3rd arg] focus_ahead for the focus/u07 hours (the default from the data otherwise)
var modes: Array = ["off", "on", "focus", "u07"]   ## [4th arg] e.g. focus,u07


func _flavor_factory(seed_value: int, news: bool, u07: bool) -> PopRules:
	var f: PopRules = Factory.new(null, seed_value)
	if not news:
		f.economy.table("factory")["news"] = {}
	f.sign_tier = 6
	f.packer_tier = 3
	f.level = 6
	f.stats["sold"] = 1
	f.stats["packed"] = 1
	f.money = 1 << 30
	var kitchen := ["M07", "M10", "M07", "M01", "M16", "U02", "U03", "U01", "M13", "M12"]
	for id: String in kitchen:
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
	if u07:   # (the kitchen is full: the demand scheduler stands in the shop's fifth place)
		f.execute({"type": "buy_line", "floor": "shop"})
		var r7: Dictionary = f.execute({"type": "build", "machine": "U07", "floor": "shop"})
		assert(bool(r7["ok"]), "U07 built: %s" % r7.get("reason", ""))
	f.money = 2000
	f.stats["sold"] = 0
	return f


func _check(f: PopRules, label: String) -> void:
	assert(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "portions " + label)
	assert(int(f.stats.get("wrong_sku", 0)) == 0, "wrong bag " + label)
	assert(f.queue.size() <= int(f.queue_cap()), "queue cap " + label)
	assert(f.money >= 0, "money " + label)


func _hand(f: PopRules, i: int) -> void:
	if i % 3 == 0 and f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
		f.execute({"type": "press"})
	f.advance(1500)
	if f.heating:
		f.execute({"type": "release"})


func _book(f: PopRules) -> int:
	return int(f.stats["revenue"]) - int(f.stats["upkeep_paid"]) - int(f.stats.get("kernels_paid", 0)) - int(f.stats.get("oil_paid", 0)) - int(f.stats.get("ingredient_coins", 0))


func _hour(seed_value: int, mode: String, minutes: int) -> Dictionary:
	var f := _flavor_factory(seed_value, mode != "off", mode == "u07")
	if ahead_override >= 0 and not f.news_rules().is_empty():
		f.economy.table("factory")["news"]["focus_ahead"] = ahead_override
	var money0 := int(f.money)
	var book0 := _book(f)
	var spent := 0   # (machines bought: none after setup)
	var steady_bad := 0
	for i in minutes * 40:
		if mode == "focus":
			for fl: String in f._news_flavors():
				if f.news_focus == "":
					f.execute({"type": "news_focus", "flavor": fl})
		_hand(f, i)
		if (f.news["active"] as Array).is_empty() and JSON.stringify(f.demand_mods) != JSON.stringify(f.base_mods):
			steady_bad += 1
		if i % 40 == 39:
			_check(f, "%d %s" % [seed_value, mode])
	assert(int(f.money) - money0 == _book(f) - book0 - spent, "money only from sales and costs")
	var costs := float(f.stats["upkeep_paid"]) + float(f.stats.get("kernels_paid", 0)) + float(f.stats.get("oil_paid", 0)) + float(f.stats.get("ingredient_coins", 0))
	var mins := float(f.flow_ms) / 60000.0
	var events: Array = []
	for a: Dictionary in (f.news.get("log", []) as Array) + (f.news.get("active", []) as Array):
		events.append({"id": a["id"], "start_min": snappedf(float(a["start"]) / 60000.0, 0.01), "asked": a["asked"], "sold": a["sold"], "saved": a.get("saved", 0)})
	return {"net_per_min": snappedf((float(f.stats["revenue"]) - costs) / mins, 0.1), "sold": f.stats["sold"], "abandoned": f.stats["abandoned"], "passed_by": f.stats["passed_by"],
		"asked_recipe": f.stats.get("asked_recipe", {}), "flavor_sold": f.stats.get("flavor_sold", {}), "news_started": int(f.stats.get("news_started", 0)),
		"news_skipped": int(f.stats.get("news_skipped", 0)), "news_spared": int(f.stats.get("news_spared", 0)), "news_saved_coins": int(f.stats.get("news_saved_coins", 0)),
		"events_logged": events.size(), "steady_violations": steady_bad, "popularity_end": snappedf(f.popularity, 0.1), "events": events}


## Per event kind: what customers asked for during it against the same flavor's rate outside
## events in the news-off run of the same seed (customers per minute asking for the subject).
func _effects(on: Dictionary, off: Dictionary, minutes: int) -> Dictionary:
	var out := {}
	var ev: Array = on["events"]
	for e: Dictionary in ev:
		var id := String(e["id"])
		var row: Dictionary = out.get(id, {"n": 0, "asked": 0, "sold": 0, "saved": 0})
		row["n"] = int(row["n"]) + 1
		row["asked"] = int(row["asked"]) + int(e["asked"])
		row["sold"] = int(row["sold"]) + int(e["sold"])
		row["saved"] = int(row["saved"]) + int(e["saved"])
		out[id] = row
	return out


func _plain(seed_value: int, minutes: int) -> Dictionary:
	var f: PopRules = Factory.new(null, seed_value)
	f.sign_tier = 3
	f.level = 3
	f.stats["sold"] = 1
	f.stats["packed"] = 1
	for i in minutes * 40:
		_hand(f, i)
		if i % 40 == 39:
			_check(f, "plain")
	var kinds := {}
	for a: Dictionary in (f.news.get("log", []) as Array) + (f.news.get("active", []) as Array):
		kinds[a["id"]] = int(kinds.get(a["id"], 0)) + 1
	return {"sizes_open": f.sizes_open().map(func(z: Dictionary) -> int: return int(z["size"])), "events": kinds, "sold": f.stats["sold"]}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var minutes := int(args[1]) if args.size() > 1 else 60
	if args.size() > 2:
		ahead_override = int(args[2])
	if args.size() > 3:
		modes = Array(String(args[3]).split(","))
	var res := {"minutes": minutes, "hours": {}, "effects": {}, "plain": {}}
	for seed_value in [3701, 3702, 3703]:
		for mode: String in modes:
			var key := "%d_%s" % [seed_value, mode]
			var t0 := Time.get_ticks_msec()
			res["hours"][key] = _hour(seed_value, mode, minutes)
			var h: Dictionary = res["hours"][key]
			print("%s: net %.1f/min, sold %d, events %d (skipped %d), spared %d, saved %d coins, steady bad %d  [%d ms]" % [key, h["net_per_min"], h["sold"], h["news_started"], h["news_skipped"], h["news_spared"], h["news_saved_coins"], h["steady_violations"], Time.get_ticks_msec() - t0])
		if res["hours"].has("%d_on" % seed_value) and res["hours"].has("%d_off" % seed_value):
			res["effects"][str(seed_value)] = _effects(res["hours"]["%d_on" % seed_value], res["hours"]["%d_off" % seed_value], minutes)
	for seed_value in [3711, 3712]:
		res["plain"][str(seed_value)] = _plain(seed_value, minutes)
		print("plain %d: %s" % [seed_value, res["plain"][str(seed_value)]])
	var fo := FileAccess.open(out + "/news37.json", FileAccess.WRITE)
	fo.store_string(JSON.stringify(res, " "))
	fo.close()
	quit(0)
