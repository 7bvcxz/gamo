extends "res://tests/framework/test_case.gd"

## Step 17: the factory's canonical model (variants/factory/factory_rules.gd,
## design/FACTORY_FLOW.md): goods are conserved, money only from a real sale,
## backpressure, no customer = no revenue, determinism however time is cut.

const Factory := preload("res://variants/factory/factory_rules.gd")


func _pop(f: PopRules, offset: int = 10) -> Dictionary:
	var r := f.execute({"type": "press"})
	if not bool(r["ok"]):
		return r
	f.advance(f.window_start() + offset)
	return f.execute({"type": "release"})


func _quiet_shop(f: PopRules) -> void:
	# No customers (for the tests that need the shop empty).
	f.queue.clear()
	f.next_arrival_ms = 1 << 40


func _check_conservation(f: PopRules, label: String) -> void:
	assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "%s: every portion made is somewhere" % label)
	assert_true(f.money >= 0, "%s: money never negative" % label)
	assert_true(int(f.bin_portions()) <= int(f.state()["bin_cap"]), "%s: the bin within its size" % label)
	assert_true(f.shelf.size() <= int(f.state()["shelf_cap"]), "%s: the shelf within its size" % label)


func test_a_pop_makes_a_lot_not_money() -> void:
	var f: PopRules = Factory.new()
	var r := _pop(f)
	assert_eq(String(r["outcome"]), "perfect", "a perfect pop")
	assert_eq(f.money, 0, "no money from the pop")
	assert_eq(int(f.glass["portions"]), int(f.kettle_capacity()), "a full lot in the glass")
	assert_eq(int(f.glass["quality"]), 100, "perfect quality")
	_check_conservation(f, "after one pop")


func test_money_comes_only_with_a_sale_to_the_waiting_customer() -> void:
	var f: PopRules = Factory.new()
	assert_eq(f.queue.size(), 1, "the first customer is waiting when the shop opens")
	_pop(f)
	f.drain_events()
	f.advance(12000)
	var ev := f.drain_events()
	var sales := ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "sale")
	var earns := ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "earn")
	assert_true(sales.size() >= 1, "a sale")
	assert_eq(earns.size(), sales.size(), "one earn per sale, no other")
	assert_eq(f.money, int(f.stats["revenue"]), "money = revenue")
	assert_eq(int(sales[0]["data"]["coins"]), f.pack_price("plain", 2, 100), "a perfect pack's price")
	assert_true(int(sales[0]["data"]["customer"]) > 0 and int(sales[0]["data"]["pack"]) > 0, "a real customer and a real pack")
	_check_conservation(f, "after a sale")


func test_no_customer_means_no_revenue() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	for i in 3:
		_pop(f)
		f.advance(3000)
	f.advance(60000)
	assert_true(f.shelf.size() > 0, "packs wait on the shelf")
	assert_eq(f.money, 0, "no customer, no money")
	_check_conservation(f, "no customers")


func test_no_stock_means_the_customer_waits_then_leaves_and_nothing_is_sold() -> void:
	var f: PopRules = Factory.new()
	f.next_arrival_ms = 1 << 40
	f.advance(61000)
	assert_eq(f.queue.size(), 0, "the first customer left after waiting")
	assert_eq(int(f.stats["abandoned"]), 1, "counted, quietly")
	assert_eq(int(f.stats["sold"]), 0, "nothing sold")
	assert_eq(f.money, 0, "no money")


func test_backpressure_a_full_bin_holds_the_glass_and_stops_the_kettle() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	var refused := false
	for i in 40:
		var r := _pop(f)
		f.advance(1500)
		if not bool(r["ok"]):
			refused = true
			assert_eq(String(r["reason"]), "err.kettle_full", "refused because the glass holds a lot")
			break
	assert_true(refused, "the kettle stops when nothing downstream has room")
	assert_eq(f.shelf.size(), int(f.state()["shelf_cap"]), "the shelf is full")
	assert_false(f.glass.is_empty(), "the glass holds the last lot")
	assert_eq(String(f.bottleneck()), "shop", "the shop is the bottleneck (packs wait for customers)")
	assert_true(int(f.stats["glass_wait_ms"]) > 0, "the wait is counted")
	_check_conservation(f, "full")
	# A customer frees a pack: the line moves again, nothing is lost.
	f.queue.append({"id": 9999, "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
	f.advance(20000)
	assert_eq(int(f.stats["sold"]), 1, "one sale")
	_check_conservation(f, "after the line moved")


func test_grades_set_portions_and_price_and_never_zero() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.execute({"type": "press"})
	f.advance(f.burn_at() + 5)
	var lots := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "lot_popped")
	assert_eq(lots.size(), 1, "the burn made one lot")
	assert_eq(int(lots[0]["data"]["portions"]), maxi(1, int(floor(f.kettle_capacity() * 0.25))), "burnt: a quarter, at least one")
	assert_eq(int(lots[0]["data"]["quality"]), 20, "burnt quality")
	assert_eq(f.pack_price("plain", 2, 20), int(round(10 * (0.6 + 0.4 * 0.2))), "a burnt pack sells for less")
	assert_eq(f.pack_price("plain", 2, 100), 10, "a perfect pack for the full price")


func test_customers_arrive_about_every_fifteen_seconds_never_fixed() -> void:
	var f: PopRules = Factory.new()
	f.queue.clear()
	var times: Array[int] = []
	for i in 400:
		var before := int(f.stats["arrived"])
		f.advance(1000)
		if int(f.stats["arrived"]) > before:
			times.append(f.now_ms)
		f.queue.clear()   # keep the queue from filling (we are measuring arrivals)
	var gaps: Array[int] = []
	for i in range(1, times.size()):
		gaps.append(times[i] - times[i - 1])
	var mean := 0.0
	for g: int in gaps:
		mean += g
	mean /= maxf(1.0, float(gaps.size()))
	assert_true(gaps.size() >= 20, "enough arrivals (%d)" % gaps.size())
	assert_true(mean > 13000.0 and mean < 17000.0, "mean gap about 15 s (%.0f)" % mean)
	assert_true(gaps.min() >= 9000 and gaps.max() <= 21000, "within about 10-20 s (%d-%d)" % [gaps.min(), gaps.max()])
	var distinct := {}
	for g: int in gaps:
		distinct[g] = true
	assert_true(distinct.size() > 5, "not a fixed timer")


func _run(cuts: Array) -> Dictionary:
	var f: PopRules = Factory.new()
	var t := 0
	var i := 0
	# The same commands at the same times, time cut differently between them.
	var script := [[500, "press"], [500 + 1460, "release"], [4000, "press"], [4000 + 1500, "release"], [9000, "press"], [9000 + 2600, "release"], [16000, "press"], [16000 + 1450, "release"]]
	for cmd: Array in script:
		while t < int(cmd[0]):
			var step := mini(int(cuts[i % cuts.size()]), int(cmd[0]) - t)
			f.advance(step)
			t += step
			i += 1
		f.execute({"type": String(cmd[1])})
	while t < 60000:
		var step := mini(int(cuts[i % cuts.size()]), 60000 - t)
		f.advance(step)
		t += step
		i += 1
	return {"money": f.money, "stats": f.stats.duplicate(), "bin": f.bin.duplicate(true), "shelf": f.shelf.duplicate(true),
		"queue": f.queue.size(), "glass": f.glass.duplicate(), "packing": f.packing.duplicate(), "outcomes": f.outcomes.duplicate()}


func test_the_same_commands_give_the_same_factory_however_time_is_cut() -> void:
	var a := _run([16])
	for cuts: Array in [[17], [50], [1000], [16, 17, 33, 7], [3]]:
		assert_eq(JSON.stringify(_run(cuts)), JSON.stringify(a), "cut %s" % [cuts])


func test_random_play_never_breaks_conservation_or_sells_from_nothing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var f: PopRules = Factory.new()
	var sold_ids := {}
	for step in 4000:
		match rng.randi() % 6:
			0:
				f.execute({"type": "press"})
			1:
				f.execute({"type": "release"})
			2:
				f.execute({"type": "buy"})
			_:
				pass
		f.advance(rng.randi_range(1, 400))
		for e: Dictionary in f.drain_events():
			if String(e["type"]) == "sale":
				var pid := int(e["data"]["pack"])
				assert_false(sold_ids.has(pid), "a pack sells once")
				sold_ids[pid] = true
		if step % 50 == 0:
			_check_conservation(f, "step %d" % step)
	_check_conservation(f, "end")
	assert_true(int(f.stats["sold"]) <= int(f.stats["packed"]), "sold <= packed")
	assert_eq(f.earned, int(f.stats["revenue"]), "every coin earned came from a sale")


# -- Step 19: the hand's kettle, its upgrades, the crescendo, hand vs auto ----

func test_every_kettle_level_changes_something_real() -> void:
	var f: PopRules = Factory.new()
	for lv in f.max_level():
		var a: Dictionary = f.kettle_stats(lv)
		var b: Dictionary = f.kettle_stats(lv + 1)
		assert_true(int(b["portions"]) > int(a["portions"]), "level %d -> %d: more popcorn per perfect pop" % [lv, lv + 1])
		var better := int(b["gold_ms"]) > int(a["gold_ms"]) or int(b["recovery_ms"]) < int(a["recovery_ms"])
		assert_true(better or lv + 1 >= 7, "level %d -> %d: a wider gold or a faster recovery too (early levels)" % [lv, lv + 1])
	assert_true(int(f.kettle_stats(f.max_level())["recovery_ms"]) < int(f.kettle_stats(0)["recovery_ms"]), "recovery gets faster")


func test_buying_a_level_really_changes_the_next_lot() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.money = 1000
	f.earned = 1000
	_pop(f)
	var first := int(f.glass["portions"]) if not f.glass.is_empty() else int(f.kettle_capacity())
	f.advance(3000)
	assert_true(bool(f.execute({"type": "buy"})["ok"]), "bought level 1")
	_pop(f)
	var lots := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "lot_popped")
	assert_eq(int(lots[-1]["data"]["portions"]), int(f.kettle_capacity(1)), "the next perfect lot has level 1's portions")
	assert_true(int(lots[-1]["data"]["portions"]) > first, "more than before")


func test_the_factory_crescendo_makes_a_bigger_real_lot() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	var sizes: Array[int] = []
	for i in 4:
		f.drain_events()
		_pop(f)
		var lot := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "lot_popped")
		sizes.append(int(lot[0]["data"]["portions"]))
		f.advance(3000)
	var cap := int(f.kettle_capacity())
	assert_eq(sizes[0], cap, "an ordinary perfect lot")
	assert_eq(sizes[3], int(floor(cap * 1.5)), "the fourth perfect fills the crescendo: 1.5 x real portions")
	assert_eq(int(f.bursts), 1, "one burst")
	_check_conservation(f, "after a burst")


func test_the_hand_beats_one_basic_auto_cooker_per_attempt_and_parallel_cookers_win_over_time() -> void:
	var f: PopRules = Factory.new()
	for lv in f.max_level() + 1:
		var hand: Dictionary = f.hand_attempt(lv, "perfect")
		var near: Dictionary = f.hand_attempt(lv, "near")
		var auto: Dictionary = f.auto_attempt(lv)
		assert_true(float(hand["portions"]) > float(auto["portions"]), "level %d: a perfect hand makes more per attempt (%.1f vs %.1f)" % [lv, hand["portions"], auto["portions"]])
		assert_true(float(hand["quality"]) > float(auto["quality"]), "level %d: and better popcorn" % lv)
		assert_true(float(near["portions"]) >= float(auto["portions"]), "level %d: even a near hand matches it" % lv)
		# Per minute: a skilled hand pops about every (gold start + 100 ms + recovery + 300 ms of human).
		var t := f.economy.table("factory")
		var hand_cycle := int(t["window_start_ms"]) + 100 + int(f.kettle_stats(lv)["recovery_ms"]) + 300
		var hand_per_min := 60000.0 / hand_cycle * float(hand["portions"])
		var auto_per_min := 60000.0 / int(auto["cycle_ms"]) * float(auto["portions"])
		var n := ceili(hand_per_min / auto_per_min + 0.001)
		assert_true(n >= 2 and n <= 8, "level %d: %d basic cookers in parallel out-produce a skilled hand per minute (hand %.0f, one cooker %.0f)" % [lv, n, hand_per_min, auto_per_min])
