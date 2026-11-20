extends "res://tests/framework/test_case.gd"

## Step 46: the pathological model cases -- demand without end, production without a shop,
## every top level asked for one more, places that do not exist, and time cut in odd ways.
## Each must stay finite, refuse without charging, and keep every portion somewhere.

const Factory := preload("res://variants/factory/factory_rules.gd")
const Rules := preload("res://tests/unit/test_factory_rules.gd")


func _bounds(f: PopRules, label: String) -> void:
	assert_true(f.queue.size() <= f.queue_cap(), "%s: queue %d within its cap %d" % [label, f.queue.size(), f.queue_cap()])
	assert_true(f.bin_portions() + f.coating_portions() <= f.bin_cap(), "%s: bin within its size" % label)
	assert_true(f.shelf.size() <= f.shelf_cap() + 8, "%s: shelf %d within its cap %d" % [label, f.shelf.size(), f.shelf_cap()])
	for k: String in Factory.SAVE_MAX_GOODS.keys():
		assert_true((f.get(k) as Array).size() <= int(Factory.SAVE_MAX_GOODS[k]), "%s: %s within what a save accepts" % [label, k])
	assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "%s: every portion somewhere" % label)
	assert_true(int(f.money) >= 0, "%s: no debt" % label)


func test_demand_without_end_stays_finite_and_the_save_still_loads() -> void:
	var f: PopRules = Rules.new()._forty(20, 4681)
	f.base_mods["arrivals"] = 25.0   # twenty-five times the people, for half an hour
	f._news_apply()
	var peak := 0
	for k in 360:
		f.advance(5000)
		peak = maxi(peak, f.queue.size())
		if k % 60 == 59:
			_bounds(f, "minute %d" % ((k + 1) / 12))
	print("  25x arrivals, 30 min: peak queue %d (cap %d), arrived %d, passed by %d, sold %d" % [peak, f.queue_cap(), int(f.stats["arrived"]), int(f.stats.get("passed_by", 0)), int(f.stats["sold"])])
	assert_true(int(f.stats.get("passed_by", 0)) > 0, "the overflow passes by instead of piling up")
	var text := JSON.stringify(f.to_save())
	assert_true(text.length() < 200000, "the save stays small (%d bytes)" % text.length())
	var g: PopRules = Factory.new()
	assert_true(bool(g.from_save(JSON.parse_string(text))), "and loads")


func test_production_without_a_shop_fills_and_stops() -> void:
	var f: PopRules = Rules.new()._forty(44, 4682)
	assert_true(bool(f.execute({"type": "pause_floor", "floor": "shop", "paused": true})["ok"]), "the shop's machines paused")
	f.base_mods["arrivals"] = 0.0   # and no one comes
	f._news_apply()
	for k in 360:
		f.advance(5000)
		if f.glass.is_empty() and not bool(f.heating) and int(f.cooldown_left) <= 0 and bool(f.execute({"type": "press"})["ok"]):
			f.advance(int(f.window_start()) + 40)
			f.execute({"type": "release"})
	_bounds(f, "30 min, no customers")
	var blocked: int = f.machines.filter(func(m: Dictionary) -> bool: return String(m["state"]) in ["blocked", "starved", "idle", "paused"]).size()
	assert_true(blocked >= 30, "the kitchen and packing stop when there is nowhere to put goods (%d of 44 waiting)" % blocked)


func test_every_top_level_refuses_one_more_and_charges_nothing() -> void:
	var f: PopRules = Rules.new()._forty(44, 4683)
	f.money = 1 << 40
	var guard := 0
	while f.sign_cost() >= 0 and guard < 30:
		f.execute({"type": "buy_sign"})
		guard += 1
	var m0 := int(f.money)
	var r: Dictionary = f.execute({"type": "buy_sign"})
	assert_false(bool(r["ok"]), "the sign at its top refuses (%s)" % r.get("reason", ""))
	assert_eq(int(f.money), m0, "and charges nothing")
	guard = 0
	while f.station_open("packer") and guard < 30 and bool(f.execute({"type": "buy_packer"}).get("ok", false)):
		guard += 1
	m0 = int(f.money)
	assert_false(bool(f.execute({"type": "buy_packer"}).get("ok", false)), "the packing station at its top refuses")
	assert_eq(int(f.money), m0, "and charges nothing")
	var mid := int(f.machines[0]["id"])
	guard = 0
	while bool(f.execute({"type": "upgrade_machine", "id": mid})["ok"]) and guard < 20:
		guard += 1
	m0 = int(f.money)
	assert_eq(String(f.execute({"type": "upgrade_machine", "id": mid})["reason"]), "err.max_level", "a machine at its top tier refuses")
	assert_eq(int(f.money), m0, "and charges nothing")
	# Every floor full: one more machine has no place.
	for floor: String in ["kitchen", "packing", "shop"]:
		var g := 0
		while not f.floor_full(floor) and g < 40:
			f.execute({"type": "build", "machine": "cooker" if floor == "kitchen" else ("bagger" if floor == "packing" else "kiosk"), "floor": floor})
			g += 1
		while f.floor_full(floor) and bool(f.execute({"type": "buy_line", "floor": floor}).get("ok", false)):
			while not f.floor_full(floor) and g < 80:
				f.execute({"type": "build", "machine": "cooker" if floor == "kitchen" else ("bagger" if floor == "packing" else "kiosk"), "floor": floor})
				g += 1
		m0 = int(f.money)
		var n: int = f.machines.size()
		var rb: Dictionary = f.execute({"type": "build", "machine": "cooker" if floor == "kitchen" else ("bagger" if floor == "packing" else "kiosk"), "floor": floor})
		assert_false(bool(rb["ok"]), "%s full, every line bought: no place (%s)" % [floor, rb.get("reason", "")])
		assert_eq(f.machines.size(), n, "%s: nothing built" % floor)
		assert_eq(int(f.money), m0, "%s: nothing charged" % floor)
		assert_false(bool(f.execute({"type": "build", "machine": "cooker", "floor": floor, "slot": 999})["ok"]), "%s: a place that does not exist" % floor)
	_bounds(f, "everything at its top")


func test_time_cut_any_way_gives_the_same_factory() -> void:
	# The model steps in 50 ms of total time: 7, 49, 51, 333 and 2500 ms ticks (odd cuts, a
	# stalled frame, a tab back after seconds) make the same 44-machine factory.
	var runs: Array = []
	for chunk in [7, 49, 51, 333, 2500]:
		var f: PopRules = Rules.new()._forty(44, 4684)
		var t := 0
		while t < 90000:
			var d := mini(chunk, 90000 - t)
			f.advance(d)
			t += d
		runs.append(JSON.stringify(f.to_save()))
	for i in range(1, runs.size()):
		assert_eq(runs[i], runs[0], "the same factory cut in %d ms as in 7 ms" % [[7, 49, 51, 333, 2500][i]])
