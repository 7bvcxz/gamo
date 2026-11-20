extends "res://tests/framework/test_case.gd"

## Step 46: the model, every piece once -- each of the forty catalog machines through its
## whole life (built, working, paying its keep, paused, upgraded, sold), the five recipes sold
## at their price (recomputed here from data/economy.json, not by the game's own pack_price),
## mixed orders, an empty wallet, the three floors' throughput, and every news event and
## contest format applied and removed.

const Factory := preload("res://variants/factory/factory_rules.gd")
const Rules := preload("res://tests/unit/test_factory_rules.gd")
const RECIPES := ["plain", "cheese", "spicy", "caramel", "cocoa"]


func _catalog() -> Array:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/machines.json"))
	return d["machines"]


func _economy() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json")) as Dictionary)["factory"]


## A small working factory (two kettles, a bagger, a kiosk) with every gate open.
func _base(seed_value: int, steady: bool = true) -> PopRules:
	var f: PopRules = Factory.new(null, seed_value)
	if steady:
		f = Rules.new()._steady(f)
	f.sign_tier = 8
	f.packer_tier = 3
	f.level = 6
	f.money = 1 << 30
	f.stats["packed"] = maxi(1, int(f.stats["packed"]))
	f.stats["sold"] = maxi(1, int(f.stats["sold"]))
	for t: Array in [["cooker", "kitchen"], ["cooker", "kitchen"], ["bagger", "packing"], ["kiosk", "shop"]]:
		assert_true(bool(f.execute({"type": "build", "machine": t[0], "floor": t[1]})["ok"]), "base %s" % t[0])
	return f


func _hand(f: PopRules) -> void:
	if not bool(f.heating) and int(f.cooldown_left) <= 0 and f.glass.is_empty():
		if bool(f.execute({"type": "press"})["ok"]):
			f.advance(int(f.window_start()) + 40)
			f.execute({"type": "release"})


func _floor_for(e: Dictionary) -> String:
	var rt := _runtime(e)
	var fl := String(Factory.FLOOR_OF.get(rt, e["floor"])) if rt != "" else String(e["floor"])
	return "kitchen" if fl in ["any", "support"] else fl


func _runtime(e: Dictionary) -> String:
	return String(e["runtime"]) if e.get("runtime") != null else ""


## Every catalog machine: buildable exactly when its runtime and systems exist; then its life.
func test_every_catalog_machine_lives_its_whole_life() -> void:
	var table: Array = []
	var buildable := 0
	for e: Dictionary in _catalog():
		var id := String(e["id"])
		var f := _base(4600 + buildable)
		var rt := _runtime(e)
		if not f.catalog_buildable(id):
			# U06 needs "aging", a system the game does not have: not sold, not buildable.
			assert_eq(rt, "", "%s is unbuildable only when it has no runtime (or a missing system)" % id)
			var r0: Dictionary = f.execute({"type": "build", "machine": id, "floor": _floor_for(e)})
			assert_false(bool(r0["ok"]), "%s cannot be built" % id)
			table.append("%s: not buildable (%s)" % [id, ", ".join(PackedStringArray(e.get("requires", [])))])
			continue
		buildable += 1
		var floor := _floor_for(e)
		if rt == "U08":
			# U08 balances parallel packing lines: a full packing floor buys its second line.
			var guard := 0
			while not f.floor_full("packing") and guard < 20:
				f.execute({"type": "build", "machine": "bagger", "floor": "packing"})
				guard += 1
			var rl: Dictionary = f.execute({"type": "buy_line", "floor": "packing"})
			assert_true(bool(rl["ok"]) and f.parallel_lines(), "U08's parallel line: %s" % rl.get("reason", ""))
		var money0 := int(f.money)
		var n0: int = f.machines.size()
		var r: Dictionary = f.execute({"type": "build", "machine": rt, "floor": floor})
		assert_true(bool(r["ok"]), "%s (%s) builds on %s: %s" % [id, rt, floor, r.get("reason", "")])
		if not bool(r["ok"]):
			continue
		assert_eq(f.machines.size(), n0 + 1, "%s stands" % id)
		var m: Dictionary = f.machines[f.machines.size() - 1]
		var mid := int(m["id"])
		assert_true(int(f.money) < money0, "%s cost coins" % id)
		# Four minutes of a working factory with a hand: what it does.
		var seen := {}
		var done0 := int(m.get("done", 0))
		var busy_ms := 0
		var was_busy := false
		var t_prev := int(f.now_ms)
		for k in 480:
			if k % 10 == 0:
				_hand(f)   # (it advances the clock too: the time is the factory's own, below)
			f.advance(500)
			var mm: Dictionary = f.machine(mid)
			var now := int(f.now_ms)
			seen[String(mm["state"])] = true
			var busy := not String(mm["state"]) in ["idle", "paused", "unpaid", "saving"]
			if busy or was_busy:
				busy_ms += now - t_prev   # an interval counts when either end was busy (an upper bound)
			was_busy = busy
			t_prev = now
		var mm2: Dictionary = f.machine(mid)
		var upkeep := int(mm2.get("upkeep_paid", 0))
		# It pays its keep for the time it works, and nothing for the time it waits idle:
		# at most its rate over its busy time (+1 for the coin in progress); a machine that
		# never left idle (its partner missing: M12 without coaters, U02 without oil...) paid 0.
		var per_min := float(e.get("upkeep_per_min", 0))
		assert_true(float(upkeep) <= per_min * float(busy_ms) / 60000.0 + 1.0, "%s: keep %d within %.1f/min over %d busy ms" % [id, upkeep, per_min, busy_ms])
		if busy_ms == 0:
			assert_eq(upkeep, 0, "%s never worked and paid nothing" % id)
		elif per_min > 0.0 and busy_ms >= 120000:
			assert_true(upkeep >= 1, "%s worked %d ms and paid its keep" % [id, busy_ms])
		# Paused: no keep.
		assert_true(bool(f.execute({"type": "pause_machine", "id": mid, "paused": true})["ok"]), "%s pauses" % id)
		var paid_paused := int(f.machine(mid).get("upkeep_paid", 0))
		f.advance(60000)
		assert_eq(String(f.machine(mid)["state"]), "paused", "%s stays paused" % id)
		assert_eq(int(f.machine(mid).get("upkeep_paid", 0)), paid_paused, "%s pays nothing paused" % id)
		f.execute({"type": "pause_machine", "id": mid, "paused": false})
		# Upgraded (each catalog machine has tiers).
		var tier0 := int(f.machine(mid).get("tier", 0))
		var m_up := int(f.money)
		var ru: Dictionary = f.execute({"type": "upgrade_machine", "id": mid})
		assert_true(bool(ru["ok"]), "%s upgrades: %s" % [id, ru.get("reason", "")])
		if bool(ru["ok"]):
			assert_eq(int(f.machine(mid)["tier"]), tier0 + 1, "%s one tier up" % id)
			assert_true(int(f.money) < m_up, "%s's upgrade cost coins" % id)
		# Sold (when nothing is in its hands), and every portion is still somewhere.
		var sold_ok := false
		var why := ""
		for k in 240:
			var rs: Dictionary = f.execute({"type": "sell_machine", "id": mid})
			if bool(rs["ok"]):
				sold_ok = true
				break
			why = String(rs.get("reason", ""))
			f.advance(250)   # (running: what is in its hands finishes; a paused one would hold it)
		assert_true(sold_ok, "%s sells within a minute (%s)" % [id, why])
		assert_true(f.machine(mid).is_empty(), "%s gone" % id)
		assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "%s: every portion somewhere" % id)
		assert_true(int(f.money) >= 0, "%s: no debt" % id)
		var states := PackedStringArray(seen.keys())
		states.sort()
		table.append("%s %s: states %s, done %d, busy %d s, keep %d" % [id, rt, ",".join(states), int(mm2.get("done", 0)) - done0, busy_ms / 1000, upkeep])
	assert_eq(buildable, 39, "39 of the 40 are buildable (U06 needs aging)")
	print("  " + "\n  ".join(PackedStringArray(table)))


## The flavors34 factory plus a cup feeder: every recipe can be made, packed and sold.
func _flavor_shop(seed_value: int, steady: bool = true) -> PopRules:
	var f := _base(seed_value, steady)
	for t: Array in [["M01", "kitchen"], ["M12", "kitchen"]]:
		f.execute({"type": "build", "machine": t[0], "floor": t[1]})
	var coaters := {}
	for pair: Array in [["P05", "cheese"], ["P05", "spicy"], ["P06", "caramel"], ["P06", "cocoa"]]:
		if f.floor_full("packing"):
			f.execute({"type": "buy_line", "floor": "packing"})
		var r: Dictionary = f.execute({"type": "build", "machine": pair[0], "floor": "packing"})
		assert_true(bool(r["ok"]), "%s built: %s" % [pair[0], r.get("reason", "")])
		var id := int(f.machines[f.machines.size() - 1]["id"])
		f.execute({"type": "set_flavor", "id": id, "flavor": pair[1]})
		coaters[pair[1]] = id
	return f


## A bag's price from data/economy.json alone (the price table, the bag sizes, the
## quality weight) -- independent of the game's pack_price.
func _price(eco: Dictionary, recipe: String, size: int, quality: int) -> int:
	var recipes: Dictionary = (eco["flavors"]["recipes"] as Dictionary).duplicate()
	var mixes: Dictionary = eco["flavors"].get("mixes", {})
	if mixes.has(recipe) and recipe != "order" and recipe != "_doc":
		recipes[recipe] = mixes[recipe]   # Step 35: a mixed bag has its own price and weight
	var unit: int = int(eco["price"][recipe]) if (eco["price"] as Dictionary).has(recipe) else int(recipes[recipe]["price"])
	var base: int = unit * size / int(eco["pack"]["size"])
	for z: Dictionary in eco.get("sizes", []):
		if int(z["size"]) == size:
			base = int(z["price"]) * unit / 10
	if recipe == "plain" or not recipes.has(recipe):
		return maxi(1, int(round(base * (0.6 + 0.4 * float(quality) / 100.0))))
	var w := float(recipes[recipe].get("quality_weight", 0.4))
	return maxi(1, int(round(base * (1.0 - w + w * float(quality) / 100.0))))


func test_five_recipes_mixed_orders_and_every_sale_at_its_price() -> void:
	var eco := _economy()
	var f := _flavor_shop(4651)
	for k in 240:   # twenty minutes, the hand every 5 s
		_hand(f)
		f.advance(5000)
	var sold := {}
	var wrong := 0
	var total := 0
	for row: Dictionary in f.ledger:
		var want := _price(eco, String(row["recipe"]), int(row["size"]), int(row["quality"]))
		if int(row["coins"]) != want:
			wrong += 1
			if wrong <= 3:
				print("  price: %s size %d q%d paid %d, data says %d" % [row["recipe"], row["size"], row["quality"], row["coins"], want])
		sold[String(row["recipe"])] = int(sold.get(String(row["recipe"]), 0)) + 1
		total += int(row["coins"])
	print("  sold by recipe: %s, asked: %s, ledger %d rows" % [JSON.stringify(sold), JSON.stringify(f.stats.get("asked_recipe", {})), f.ledger.size()])
	assert_eq(wrong, 0, "every sale paid what the data says (%d rows)" % f.ledger.size())
	for r: String in RECIPES:
		assert_true(int(sold.get(r, 0)) >= 1, "%s sold" % r)
	assert_true((f.stats.get("asked_recipe", {}) as Dictionary).size() >= 5, "orders mixed all five recipes")
	assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "no customer got another recipe")
	if int(f.stats["sold"]) - 1 <= 500:   # (the ledger keeps 500 rows; the stats' sold started at 1)
		assert_eq(total, int(f.stats["revenue"]), "the ledger's coins are the revenue")
	assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "every portion somewhere")


func test_an_empty_wallet_stops_the_keep_never_makes_debt_and_sales_restart_it() -> void:
	var f := _flavor_shop(4652)
	for k in 24:
		_hand(f)
		f.advance(5000)
	f.money = 0
	var lowest := 0
	var unpaid0 := int(f.stats["auto_unpaid_ms"])
	var waited := {}
	for k in 1200:   # a minute of a player who spends every coin the moment it comes in
		f.money = 0
		f.advance(50)
		lowest = mini(lowest, int(f.money))
		for m: Dictionary in f.machines:
			if String(m["state"]) == "unpaid":
				waited[String(m["type"])] = true
	var st := {}
	for m: Dictionary in f.machines:
		st["%s:%s" % [m["type"], m["state"]]] = int(m.get("upkeep_ms", 0))
	print("  wallet zeroed a minute: unpaid_ms %d -> %d, money %d, states %s" % [unpaid0, int(f.stats["auto_unpaid_ms"]), int(f.money), JSON.stringify(st)])
	assert_eq(lowest, 0, "never below zero")
	# (an empty wallet stops a coin's worth of work wherever it is due: the keep in _pay, the
	# kernel sack of the hopper, a coater's ingredients -- each waits "unpaid", none borrows)
	assert_true(not waited.is_empty(), "machines waited unpaid (%s)" % ",".join(PackedStringArray(waited.keys())))
	f.money = 5000
	var ran := false
	for k in 60:
		f.advance(500)
		ran = ran or f.machines.any(func(m: Dictionary) -> bool: return String(m["state"]) == "run")
	assert_true(ran, "with coins again the machines run")
	assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "every portion somewhere")


func test_three_floors_carry_the_goods_in_order() -> void:
	var f: PopRules = Rules.new()._forty(44, 4653)
	var made0 := int(f.stats["made_portions"])
	var sold0 := int(f.stats["sold_portions"])
	var packed0 := int(f.stats.get("packed_portions", 0))
	for k in 120:
		_hand(f)
		f.advance(5000)
	var made := int(f.stats["made_portions"]) - made0
	var packed := int(f.stats.get("packed_portions", 0)) - packed0
	var sold := int(f.stats["sold_portions"]) - sold0
	print("  ten minutes, 44 machines: made %d, packed %d, sold %d portions" % [made, packed, sold])
	assert_true(made > 0 and packed > 0 and sold > 0, "all three floors worked")
	assert_true(sold <= packed + 10 and packed <= made + 40, "the shop sells no more than packing packed, packing no more than the kitchen made (plus what waited at the start)")
	assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "every portion somewhere")


func test_every_news_event_changes_its_channel_and_ends() -> void:
	var eco := _economy()
	for id: String in (eco["news"]["events"] as Dictionary).keys():
		var e: Dictionary = eco["news"]["events"][id]
		var f := _flavor_shop(4660, false)   # (news on; the scheduler's own events held back below)
		f.advance(1000)
		f.news["next_ms"] = 1 << 40
		var before: Dictionary = f.demand_mods.duplicate(true)
		var r: Dictionary = f.news_force(id)
		assert_true(bool(r.get("ok", false)), "%s starts: %s" % [id, r.get("reason", "")])
		var m: Dictionary = f.demand_mods
		match String(e["channel"]):
			"flavor":
				assert_near(float((m.get("flavors", {}) as Dictionary).get(e["flavor"], 1.0)), float(e["demand"]), 0.001, "%s: %s demand x%s" % [id, e["flavor"], e["demand"]])
			"cost":
				assert_near(float((m.get("ingredients", {}) as Dictionary).get(e["flavor"], 1.0)), float(e["ingredients"]), 0.001, "%s: %s ingredients x%s" % [id, e["flavor"], e["ingredients"]])
			"size":
				assert_near(float(m.get("large", 1.0)), float(e["large"]), 0.001, "%s: large bags x%s" % [id, e["large"]])
			"arrivals":
				assert_near(float(m.get("arrivals", 1.0)), float(e["arrivals"]), 0.001, "%s: arrivals x%s" % [id, e["arrivals"]])
		for k in int(e["ms"]) / 5000 + 2:
			f.advance(5000)
		assert_false((f.news["active"] as Array).any(func(a: Dictionary) -> bool: return String(a["id"]) == id), "%s ends after %d ms" % [id, e["ms"]])
		assert_eq(JSON.stringify(f.demand_mods), JSON.stringify(before), "%s: the demand back as it was" % id)


func test_every_contest_format_charges_once_and_pays_once() -> void:
	var eco := _economy()
	for id: String in (eco["contests"]["formats"] as Dictionary).keys():
		var fm: Dictionary = eco["contests"]["formats"][id]
		# The flavor shop (a caramel coater for the best batch), with the history a "net" contest
		# measures against (contest_baseline: minutes of earnings): twelve minutes of play first.
		var f := _flavor_shop(4670)
		for k in 144:
			_hand(f)
			f.advance(5000)
		f.stats["sold"] = maxi(int(f.stats["sold"]), 200)
		var rp: Dictionary = f.contest_force_post(id)
		assert_true(bool(rp.get("ok", false)), "%s posts: %s" % [id, rp.get("reason", "")])
		if not bool(rp.get("ok", false)):
			continue
		var m0 := int(f.money)
		var re: Dictionary = f.execute({"type": "contest_enter", "id": id})
		assert_true(bool(re["ok"]), "%s entered: %s" % [id, re.get("reason", "")])
		assert_eq(int(f.money), m0 - int(fm["fee"]), "%s: the fee once" % id)
		var results0 := (f.contests["results"] as Array).size()
		for k in int(fm["ms"]) / 5000 + 3:
			_hand(f)
			f.advance(5000)
		assert_true((f.contests["entry"] as Dictionary).is_empty(), "%s over" % id)
		assert_eq((f.contests["results"] as Array).size(), results0 + 1, "%s: one result" % id)
		var res: Dictionary = (f.contests["results"] as Array).back()
		var tier := int(res["tier"])
		var want := 0 if tier == 0 else int((fm["prizes"] as Array)[tier - 1])
		assert_eq(int(res["prize"]), want, "%s: tier %d pays its prize" % [id, tier])
		for k in 24:   # two more minutes: no second prize
			f.advance(5000)
		assert_eq((f.contests["results"] as Array).filter(func(x: Dictionary) -> bool: return int(x["seq"]) == int(res["seq"])).size(), 1, "%s: paid once" % id)
