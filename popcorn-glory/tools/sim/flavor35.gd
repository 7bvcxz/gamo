extends SceneTree
## Step 35: flavor craftsmanship on the canonical model -- the same flavor factory as
## Step 34's economy (two packing lines, four coaters, the flavor base mixer, sign 6) played
## for an hour under different policies and demands. SIMULATED TARGETS, NOT PLAYER ENJOYMENT.
##   godot --headless --path popcorn-glory --script res://tools/sim/flavor35.gd -- <out_dir> [minutes]
## Writes <out>/flavor35.json; asserts conservation and no wrong bag at every minute.
##
## The hand: it pops the kettle every 4.5 s, holding 1.5 s (Step 34's sim hand). In the gap a
## finishing policy may hold the spoon on one batch (the kettle is never pressed meanwhile --
## one hand); its grade comes from its odds, the hold from the flavor's gold.
const Factory := preload("res://variants/factory/factory_rules.gd")

const SKILLED := {"perfect": 0.8, "near": 0.15, "late": 0.05}
const AVERAGE := {"perfect": 0.5, "near": 0.3, "early": 0.1, "late": 0.1}

## name: [coater mode, hand odds ({} = no finishing), order-share scale, coater tier, promo on]
## (scale 1.5: 69% of new customers ask for a flavor or the mix; 2.0, the craze: all of them)
const RUNS := {
	"paused": ["paused", {}, 1.0, 0, true],
	"machines": ["fixed", {}, 1.0, 0, true],
	"hand_skilled": ["fixed", SKILLED, 1.0, 0, true],
	"hand_average": ["fixed", AVERAGE, 1.0, 0, true],
	"auto_mode": ["auto", {}, 1.0, 0, true],
	"auto_mode_hand": ["auto", SKILLED, 1.0, 0, true],
	"tier2_machines": ["fixed", {}, 1.0, 2, true],
	"low_demand_paused": ["paused", {}, 0.5, 0, true],
	"low_demand_machines": ["fixed", {}, 0.5, 0, true],
	"low_demand_hand": ["fixed", SKILLED, 0.5, 0, true],
	"high_demand_paused": ["paused", {}, 1.5, 0, true],
	"high_demand_machines": ["fixed", {}, 1.5, 0, true],
	"high_demand_hand": ["fixed", SKILLED, 1.5, 0, true],
	"high_demand_tier2": ["fixed", {}, 1.5, 2, true],
	"craze_machines": ["fixed", {}, 2.0, 0, true],
	"craze_tier2": ["fixed", {}, 2.0, 2, true],
	"craze_hand": ["fixed", SKILLED, 2.0, 0, true],
}

var _rng := RandomNumberGenerator.new()


func _grade(odds: Dictionary) -> String:
	var u := _rng.randf()
	var acc := 0.0
	for g: String in odds.keys():
		acc += float(odds[g])
		if u < acc:
			return g
	return "perfect"


func _spoon_ms(f: PopRules, fl: String, grade: String) -> int:
	var w: Array = f.finish_window(fl)
	var near := int(f.hand_rules()["near_ms"])
	match grade:
		"perfect":
			return (int(w[0]) + int(w[1])) / 2
		"near":
			return int(w[0]) - near / 2
		"early":
			return maxi(50, int(w[0]) - near - 150)
	return int(w[1]) + near + 100


func _factory(mode: String, scale: float, tier: int) -> Dictionary:
	var f: PopRules = Factory.new(null, 20261117)
	f.coater_fair = OS.get_environment("COATER_FAIR") != "0"   # Step 44 A/B
	if scale != 1.0:
		for fl: String in ["cheese", "spicy", "caramel", "cocoa"]:
			var r: Dictionary = f.flavor(fl)
			r["order_share"] = float(r["order_share"]) * scale
		f.mix("duo")["order_share"] = float(f.mix("duo")["order_share"]) * scale
	f.sign_tier = 6
	f.packer_tier = 3
	f.level = 6
	f.presses = 30   # the hand cooks comfortably (the spoon is open)
	f.stats["sold"] = 1
	f.stats["packed"] = 1
	f.money = 1 << 30
	for id in ["M07", "M10", "M07", "M01", "M16", "U02", "U03", "U01", "M13", "M12"]:
		f.execute({"type": "build", "machine": id, "floor": "kitchen"})
	var coaters := {}
	for row: Array in [["bagger", ""], ["P07", ""], ["P05", "cheese"], ["P06", "caramel"], ["line", ""], ["bagger", ""], ["U04", ""], ["P05", "spicy"], ["P06", "cocoa"]]:
		if String(row[0]) == "line":
			f.execute({"type": "buy_line", "floor": "packing"})
			continue
		var r: Dictionary = f.execute({"type": "build", "machine": row[0], "floor": "packing"})
		assert(bool(r["ok"]), "flavor factory: %s (%s)" % [row[0], r.get("reason", "")])
		if String(row[1]) != "":
			f.execute({"type": "set_flavor", "id": r["machine"], "flavor": "auto" if mode == "auto" else row[1]})
			coaters[String(row[1])] = int(r["machine"])
			for t in tier:
				f.execute({"type": "upgrade_machine", "id": r["machine"]})
	for id in ["S03", "S05", "S08", "S01"]:
		f.execute({"type": "build", "machine": id, "floor": "shop"})
	if mode == "paused":
		for fl: String in coaters.keys():
			f.execute({"type": "pause_machine", "id": coaters[fl], "paused": true})
	var est := {}
	for fl: String in coaters.keys():
		var m: Dictionary = f.machine(int(coaters[fl]))
		est[fl] = f.coater_estimate(String(m["type"]), fl, int(m["tier"]), int(m["paid"]))
	f.money = 2000
	f.stats["sold"] = 0
	return {"f": f, "coaters": coaters, "estimate": est}


func _hour(spec: Array, minutes: int) -> Dictionary:
	_rng.seed = 35
	var built := _factory(String(spec[0]), float(spec[2]), int(spec[3]))
	var f: PopRules = built["f"]
	if not bool(spec[4]):
		f.flavors()["promo"]["surplus_portions"] = 1 << 30
	var odds: Dictionary = spec[1]
	var presses := 0
	var steps := minutes * 600   # 100 ms
	var hand_busy := 0           # ms the spoon still holds
	for i in steps:
		var t := i * 100
		# The kettle: pressed every 4.5 s, held 1.5 s (as Step 34's sim).
		if t % 4500 == 0 and hand_busy <= 0 and f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
			if bool(f.execute({"type": "press"})["ok"]):
				presses += 1
		if f.heating and int(f.heat_ms) >= 1500:
			f.execute({"type": "release"})
		# The spoon: in the gap (not heating, the next press at least 1.5 s away).
		if not odds.is_empty() and hand_busy <= 0 and not f.heating and (4500 - t % 4500) >= 1600:
			for x: String in ["P05", "P06"]:
				var done := false
				for m: Dictionary in f.of_type(x):
					if f.can_finish(m):
						var fl := String(m["held"]["recipe"])
						var ms := _spoon_ms(f, fl, _grade(odds))
						if bool(f.execute({"type": "finish_press", "id": m["id"]})["ok"]):
							hand_busy = ms
							done = true
							break
				if done:
					break
		f.advance(100)
		if hand_busy > 0:
			hand_busy -= 100
			if hand_busy <= 0 and not f.finishing.is_empty():
				f.execute({"type": "finish_release"})
		if t % 60000 == 0:
			assert(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "portions at %d" % t)
			assert(int(f.stats.get("wrong_sku", 0)) == 0, "wrong bag at %d" % t)
			assert(f.money >= 0, "money at %d" % t)
	var mins := float(f.flow_ms) / 60000.0
	var costs := float(f.stats["upkeep_paid"]) + float(f.stats.get("kernels_paid", 0)) + float(f.stats.get("oil_paid", 0)) + float(f.stats.get("ingredient_coins", 0))
	var per_coater := {}
	for fl: String in built["coaters"].keys():
		var m: Dictionary = f.machine(int(built["coaters"][fl]))
		per_coater[fl] = {"paid": int(m["paid"]), "margin": int(m.get("margin", 0)), "ingredients": int(m.get("ingredients_paid", 0)), "upkeep": int(m.get("upkeep_paid", 0)),
			"net": int(f.coater_net(m)), "net_per_min": snappedf(float(f.coater_net(m)) / mins, 0.1), "paid_back_min": snappedf(float(int(m.get("paid_back_ms", -1))) / 60000.0, 0.1) if m.has("paid_back_ms") else -1,
			"estimate": built["estimate"][fl]}
	return {"minutes": mins, "net_per_min": snappedf((float(f.stats["revenue"]) - costs) / mins, 0.1), "revenue": f.stats["revenue"], "sold": f.stats["sold"],
		"abandoned": f.stats["abandoned"], "passed_by": f.stats["passed_by"], "presses": presses, "made": f.stats["made_portions"],
		"flavor_sold": f.stats.get("flavor_sold", {}), "mix_sold": int(f.stats.get("mix_sold", 0)), "mix_revenue": int(f.stats.get("mix_revenue", 0)),
		"hand_finish": f.stats.get("hand_finish", {}), "hand_portions": int(f.stats.get("hand_portions", 0)), "hand_sold_portions": int(f.stats.get("hand_sold_portions", 0)),
		"lost_portions": int(f.stats.get("lost_portions", 0)), "lost": f.stats.get("lost", {}), "coated": f.stats.get("coated", {}),
		"ingredient_coins": int(f.stats.get("ingredient_coins", 0)), "promos": int(f.stats.get("promos", 0)), "wrong_sku": int(f.stats.get("wrong_sku", 0)), "coaters": per_coater}


## Too much spicy at the start (24 coated portions, its sprayer paused): minutes until it is
## sold down to one small bag, with and without the board's special.
func _surplus(promo_on: bool) -> Dictionary:
	_rng.seed = 35
	var built := _factory("fixed", 1.0, 0)
	var f: PopRules = built["f"]
	if not promo_on:
		f.flavors()["promo"]["surplus_portions"] = 1 << 30
	f.execute({"type": "pause_machine", "id": built["coaters"]["spicy"], "paused": true})
	f.bin.append({"id": f._new_id(), "recipe": "spicy", "quality": 70, "portions": 24, "line": 1})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 24
	var gone := -1
	var on := -1
	for i in 60 * 30 * 10:
		var t := i * 100
		if t % 4500 == 0 and f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
			f.execute({"type": "press"})
		if f.heating and int(f.heat_ms) >= 1500:
			f.execute({"type": "release"})
		f.advance(100)
		if on < 0 and f.promoted("spicy"):
			on = f.flow_ms
		if t % 1000 == 0 and f.flavor_have("spicy") <= f.pack_size():
			gone = f.flow_ms
			break
	assert(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "portions surplus")
	return {"special_on_s": snappedf(float(on) / 1000.0, 0.1) if on >= 0 else -1, "sold_down_min": snappedf(float(gone) / 60000.0, 0.01) if gone >= 0 else -1,
		"spicy_sold": int(f.stats.get("flavor_sold", {}).get("spicy", 0)), "abandoned": f.stats["abandoned"]}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var minutes := int(args[1]) if args.size() > 1 else 60
	var res := {"minutes": minutes, "runs": {}, "surplus": {}}
	for name: String in RUNS.keys():
		var t0 := Time.get_ticks_msec()
		res["runs"][name] = _hour(RUNS[name], minutes)
		print("%s: net %.1f/min (%d ms)" % [name, float(res["runs"][name]["net_per_min"]), Time.get_ticks_msec() - t0])
	for p: bool in [true, false]:
		res["surplus"]["special" if p else "no_special"] = _surplus(p)
		print("surplus %s: %s" % [p, res["surplus"]["special" if p else "no_special"]])
	var s := FileAccess.open(out + "/flavor35.json", FileAccess.WRITE)
	s.store_string(JSON.stringify(res, " "))
	s.close()
	quit(0)
