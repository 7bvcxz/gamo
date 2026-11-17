extends SceneTree
## Step 25: the factory's economy on the canonical model (variants/factory/factory_rules.gd),
## played by simulated hands and purchase policies. SIMULATED TARGETS, NOT PLAYER ENJOYMENT.
##   godot --headless --path popcorn-glory --script res://tools/sim/economy.gd -- <out_dir> [minutes] [only]
## Writes <out>/runs.csv (per minute, every run), <out>/purchases.csv (each purchase with its
## measured payback) and <out>/summary.json; asserts conservation at every minute.
const Factory := preload("res://variants/factory/factory_rules.gd")

## Hands: how soon they press after the kettle frees (ms) and their grade odds.
const HANDS := {
	"fast": {"react": 300, "odds": {"perfect": 0.8, "near": 0.15, "late": 0.05}},
	"average": {"react": 1000, "odds": {"perfect": 0.5, "near": 0.3, "late": 0.1, "early": 0.1}},
	"slow": {"react": 8000, "odds": {"perfect": 0.3, "near": 0.3, "late": 0.2, "early": 0.15, "burnt": 0.05}},
	"specialist": {"react": 300, "odds": {"perfect": 0.95, "near": 0.05}},
	"idle": {"react": 30000, "odds": {"perfect": 0.5, "near": 0.5}},
}
const RUNS := [
	["fast", "early"], ["average", "early"], ["slow", "early"], ["specialist", "early"],
	["average", "late"], ["average", "supply"], ["average", "demand"], ["idle", "auto"], ["idle", "early"], ["average", "auto"],
]

var _rng := RandomNumberGenerator.new()


func _hold_for(f: PopRules, grade: String) -> int:
	var ws := int(f.window_start())
	var we := int(f.window_end())
	var near := int(f.near_ms())
	match grade:
		"perfect":
			return (ws + we) / 2
		"near":
			return we + near / 2 if _rng.randf() < 0.5 else ws - near / 2
		"early":
			return maxi(50, ws - near - 120)
		"late":
			return we + near + 60
	return int(f.burn_at()) + 20


func _grade(odds: Dictionary) -> String:
	var u := _rng.randf()
	var acc := 0.0
	for g: String in odds.keys():
		acc += float(odds[g])
		if u < acc:
			return g
	return "perfect"


func _buy(f: PopRules, cmd: String, log: Array, t: int) -> bool:
	var price: int = {"buy": f.cost(), "buy_packer": f.packer_cost(), "buy_sign": f.sign_cost(), "buy_auto": f.auto_cost()}[cmd]
	var before := int(f.per_min("sales"))
	var rev := int(f.stats["revenue"])
	var r: Dictionary = f.execute({"type": cmd})
	if bool(r["ok"]):
		log.append({"t": t, "what": cmd, "cost": price, "sales_before": before, "rev_at": rev, "bottleneck": String(f.bottleneck())})
		return true
	return false


func _affordable(f: PopRules, cmd: String, factor: float) -> bool:
	var price: int = {"buy": f.cost(), "buy_packer": f.packer_cost(), "buy_sign": f.sign_cost(), "buy_auto": f.auto_cost()}[cmd]
	var open: bool = {"buy": true, "buy_packer": f.station_open("packer"), "buy_sign": f.station_open("sign"), "buy_auto": f.station_open("auto")}[cmd]
	return bool(open) and price >= 0 and float(f.money) >= float(price) * factor


func _shop(f: PopRules, policy: String, log: Array, t: int) -> void:
	var factor := 2.0 if policy == "late" else 1.0
	var want := ""
	match String(f.bottleneck()):
		"production":
			want = "buy_auto" if policy == "auto" and _affordable(f, "buy_auto", 1.0) else "buy"
		"packaging":
			want = "buy_packer"
		"demand", "":
			want = "buy_sign"
		"service":
			want = "build_kiosk"
	if policy == "supply" and want == "buy_sign":
		want = "buy"
	if policy == "demand" and want in ["buy", "buy_packer", "buy_auto"]:
		want = "buy_sign"
	if policy == "auto" and f.station_open("auto") and _affordable(f, "buy_auto", 1.5):
		want = "buy_auto"
	# Step 28: kettles hold five lots of kernels; an automating player keeps a hopper (M01)
	# for every four of them, as soon as the hopper is open and affordable.
	if policy == "auto":
		var kettles: int = f.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "cooker").size()
		var hoppers: int = f.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "M01").size()
		if hoppers * 4 < kettles and f.station_open("M01") and f.build_cost("M01") >= 0 and float(f.money) >= float(f.build_cost("M01")) and f._free_slot("kitchen") >= 0:
			var hp := int(f.build_cost("M01"))
			if bool(f.execute({"type": "build", "machine": "M01"})["ok"]):
				log.append({"t": t, "what": "build_hopper", "cost": hp, "sales_before": 0, "rev_at": 0, "bottleneck": "production"})
			return
	if want == "build_kiosk":
		if f.station_open("kiosk") and f.build_cost("kiosk") >= 0 and float(f.money) >= float(f.build_cost("kiosk")) * factor and f._free_slot("shop") >= 0:
			var price := int(f.build_cost("kiosk"))
			if bool(f.execute({"type": "build", "machine": "kiosk"})["ok"]):
				log.append({"t": t, "what": "build_kiosk", "cost": price, "sales_before": 0, "rev_at": 0, "bottleneck": "service"})
		return
	if want != "" and _affordable(f, want, factor):
		_buy(f, want, log, t)


func _run(hand: String, policy: String, minutes: int, seed_value: int, rows: Array, buys: Array) -> Dictionary:
	_rng.seed = seed_value
	var f: PopRules = Factory.new(null, seed_value)
	var h: Dictionary = HANDS[hand]
	var t := 0
	var free_since := 0
	var log: Array = []
	var spent := 0
	var shares := {"production": 0, "packaging": 0, "demand": 0, "service": 0, "": 0}
	var last_min := {"made": 0, "packed": 0, "served": 0}
	var marks := {}
	while t < minutes * 60000:
		var free: bool = f.glass.is_empty() and int(f.cooldown_left) <= 0 and not bool(f.heating)
		if not free:
			free_since = t
		elif t - free_since >= int(h["react"]):
			f.execute({"type": "press"})
			var hold := _hold_for(f, _grade(h["odds"]))
			f.advance(hold)
			t += hold
			f.execute({"type": "release"})
			free_since = t
		f.advance(250)
		t += 250
		shares[String(f.bottleneck())] += 250
		_shop(f, policy, log, t)
		if t / 60000 > rows.filter(func(r: Dictionary) -> bool: return r["run"] == "%s/%s" % [hand, policy]).size():
			var m := t / 60000
			var made := int(f.stats["made_portions"])
			var packed := 0
			for l: Dictionary in f.ledger:
				packed += 0
			var served := int(f.stats["sold_portions"])
			var spent_now := 0
			for b: Dictionary in log:
				spent_now += int(b["cost"])
			# Conservation, every minute: every portion is somewhere; every coin is accounted for.
			assert(int(f.portions_everywhere()) == made, "portions")
			# Step 28: the kitchen's inputs (kernels bought by the hopper or a refill, oil) are spent too.
			var inputs := int(f.stats.get("kernels_paid", 0)) + int(f.stats.get("oil_paid", 0))
			assert(int(f.money) == int(f.stats["revenue"]) - spent_now - int(f.stats["upkeep_paid"]) - inputs, "money")
			assert(int(f.money) >= 0, "never negative")
			rows.append({"run": "%s/%s" % [hand, policy], "min": m, "money": f.money, "revenue": f.stats["revenue"], "sold": f.stats["sold"],
				"lost": int(f.stats["abandoned"]) + int(f.stats["passed_by"]), "visitors": f.stats["visitors"],
				"raw_pm": made - int(last_min["made"]), "served_pm": served - int(last_min["served"]),
				"kettle": f.level, "station": f.packer_tier, "sign": f.sign_tier, "cookers": f.cookers.size(),
				"upkeep": f.stats["upkeep_paid"], "unpaid_ms": f.stats["auto_unpaid_ms"], "bottleneck": f.bottleneck()})
			last_min = {"made": made, "served": served}
			if m in [3, 10, 30, 60]:
				marks[m] = {"money": f.money, "revenue": f.stats["revenue"], "sold": f.stats["sold"], "lost": int(f.stats["abandoned"]) + int(f.stats["passed_by"]),
					"kettle": f.level, "station": f.packer_tier, "sign": f.sign_tier, "cookers": f.cookers.size(), "upkeep": f.stats["upkeep_paid"],
					"purchases": log.size(), "first_purchase_s": (float(log[0]["t"]) / 1000.0) if not log.is_empty() else -1.0}
	# Payback: revenue earned in the 2 minutes after a purchase vs the 2 minutes before, against its cost.
	var revs: Array = rows.filter(func(r: Dictionary) -> bool: return r["run"] == "%s/%s" % [hand, policy])
	for b: Dictionary in log:
		var m0 := int(b["t"]) / 60000
		var before := _rev_between(revs, m0 - 2, m0)
		var after := _rev_between(revs, m0 + 1, m0 + 3)
		var gain := (after - before) / 2.0
		buys.append({"run": "%s/%s" % [hand, policy], "t_s": int(b["t"]) / 1000, "what": b["what"], "cost": b["cost"], "bottleneck": b["bottleneck"],
			"rev_per_min_before": before / 2.0, "rev_per_min_after": after / 2.0, "payback_min": (float(b["cost"]) / gain) if gain > 0.0 else -1.0})
	var total := float(t)
	return {"marks": marks, "shares": {"production": shares["production"] / total, "packaging": shares["packaging"] / total, "demand": shares["demand"] / total, "service": shares["service"] / total}}


func _rev_between(rows: Array, a: int, b: int) -> float:
	var ra := 0.0
	var rb := 0.0
	for r: Dictionary in rows:
		if int(r["min"]) == a:
			ra = float(r["revenue"])
		if int(r["min"]) == b:
			rb = float(r["revenue"])
	if a <= 0:
		ra = 0.0
	return rb - ra if rb > 0.0 else 0.0


## Edge scenarios on the same model (each asserts conservation and never-negative money).
func _scenario(name: String, out: Dictionary) -> void:
	_rng.seed = 7
	var f: PopRules = Factory.new(null, 20261116)
	var pop := func() -> void:
		if f.glass.is_empty() and int(f.cooldown_left) <= 0:
			f.execute({"type": "press"})
			f.advance((int(f.window_start()) + int(f.window_end())) / 2)
			f.execute({"type": "release"})
	match name:
		"zero_customers":   # a fast hand, and nobody ever comes
			f.queue.clear()
			f.next_arrival_ms = 1 << 40
			for i in 2400:
				pop.call()
				f.advance(250)
		"overproduction":   # the same, measured as stock: bounded by the bin, the shelf and the glass
			f.queue.clear()
			f.next_arrival_ms = 1 << 40
			for i in 2400:
				pop.call()
				f.advance(250)
		"max_customers":   # the landmark, the top station, kettle 8, a fast hand, 10 minutes
			f.sign_tier = 6
			f.packer_tier = 3
			f.level = 8
			for i in 2400:
				pop.call()
				f.advance(250)
		"sales_burst":   # eight customers walk in at once, every 2 minutes, at sign 3
			f.sign_tier = 3
			f.packer_tier = 1
			for i in 2400:
				if i % 480 == 0:
					for k in 8:
						if f.queue.size() < int(f.queue_cap()):
							f.queue.append({"id": f._new_id(), "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
							f.stats["visitors"] = int(f.stats["visitors"]) + 1
							f.stats["arrived"] = int(f.stats["arrived"]) + 1
				pop.call()
				f.advance(250)
		"advanced_kitchen":   # Step 29: the same room with the advanced kitchen, no hand, 30 minutes
			f.sign_tier = 6
			f.packer_tier = 3
			f.level = 8
			f.stats["sold"] = 1
			f.money = 1 << 30
			f.execute({"type": "build", "machine": "M07"})
			var dist: int = int(f.execute({"type": "build", "machine": "M10"}).get("machine", -1))
			f.execute({"type": "upgrade_machine", "id": dist})
			f.execute({"type": "upgrade_machine", "id": dist})
			for i in 5:
				f.execute({"type": "build", "machine": "M07"})
			for id in ["M16", "M01", "M01", "M13", "M14", "M15"]:
				f.execute({"type": "build", "machine": id})
			assert(f.machines.size() == 12, "advanced kitchen built")
			f.money = 0
			f.stats["sold"] = 0
			f.advance(1800000)
		"cookers_10", "cookers_20", "cookers_40":   # n cookers at sign 6, station 3, kettle 8, no hand, 30 minutes
			f.sign_tier = 6
			f.packer_tier = 3
			f.level = 8
			f.stats["sold"] = 1
			var n := int(name.split("_")[1])
			f.money = 1 << 30
			# Step 28: as many kettles as the kitchen's places hold beside a hopper for every
			# four of them (kettles hold five lots of kernels; the hoppers buy the rest).
			var places := int(f.slots("kitchen"))
			var kettles := 0
			while kettles < n and kettles + 1 + ceili((kettles + 1) / 4.0) <= places:
				if not bool(f.execute({"type": "buy_auto"})["ok"]):
					break
				kettles += 1
			for i in ceili(kettles / 4.0):
				f.execute({"type": "build", "machine": "M01"})
			f.money = 0
			f.stats["sold"] = 0
			f.advance(1800000)
	assert(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "portions " + name)
	assert(int(f.money) >= 0, "money " + name)
	var minutes := float(f.flow_ms) / 60000.0
	out[name] = {"minutes": minutes, "made": f.stats["made_portions"], "sold": f.stats["sold"], "revenue": f.stats["revenue"],
		"lost": int(f.stats["abandoned"]) + int(f.stats["passed_by"]), "upkeep": f.stats["upkeep_paid"], "money": f.money,
		"stock_portions": int(f.portions_everywhere()) - int(f.stats["sold_portions"]), "unpaid_ms": f.stats["auto_unpaid_ms"],
		"blocked_ms": f.stats["auto_blocked_ms"], "bin": f.bin_portions(), "shelf": f.shelf.size(), "glass": int(f.glass.get("portions", 0)),
		"inputs": int(f.stats.get("kernels_paid", 0)) + int(f.stats.get("oil_paid", 0)),
		"overheat_stops": int(f.stats.get("overheat_stops", 0)), "rotary_lots": int(f.stats.get("rotary_lots", 0)),
		"net_per_min": (float(f.stats["revenue"]) - float(f.stats["upkeep_paid"]) - float(f.stats.get("kernels_paid", 0)) - float(f.stats.get("oil_paid", 0))) / maxf(1.0, minutes), "presses_refused": f.stats["glass_wait_ms"]}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var minutes := int(args[1]) if args.size() > 1 else 60
	var only := args[2] if args.size() > 2 else ""
	var rows: Array = []
	var buys: Array = []
	var summary := {}
	for r: Array in RUNS:
		var key := "%s/%s" % [r[0], r[1]]
		if only != "" and key != only:
			continue
		var t0 := Time.get_ticks_msec()
		summary[key] = _run(r[0], r[1], minutes, 20261116, rows, buys)
		print("%s done in %d ms" % [key, Time.get_ticks_msec() - t0])
	var f := FileAccess.open(out + "/runs.csv", FileAccess.WRITE)
	var cols := ["run", "min", "money", "revenue", "sold", "lost", "visitors", "raw_pm", "served_pm", "kettle", "station", "sign", "cookers", "upkeep", "unpaid_ms", "bottleneck"]
	f.store_line(",".join(cols))
	for row: Dictionary in rows:
		f.store_line(",".join(cols.map(func(c: String) -> String: return str(row[c]))))
	f.close()
	var g := FileAccess.open(out + "/purchases.csv", FileAccess.WRITE)
	var bc := ["run", "t_s", "what", "cost", "bottleneck", "rev_per_min_before", "rev_per_min_after", "payback_min"]
	g.store_line(",".join(bc))
	for b: Dictionary in buys:
		g.store_line(",".join(bc.map(func(c: String) -> String: return str(b[c]))))
	g.close()
	var scen := {}
	if only == "":
		for name in ["zero_customers", "overproduction", "max_customers", "sales_burst", "cookers_10", "cookers_20", "cookers_40", "advanced_kitchen"]:
			_scenario(name, scen)
	summary["_scenarios"] = scen
	var s := FileAccess.open(out + "/summary.json", FileAccess.WRITE)
	s.store_string(JSON.stringify(summary, " "))
	s.close()
	quit(0)
