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


func _open(f: PopRules) -> void:
	# Step 24: the station opens after its first sealed pack (the sign after the first sale: _open_sign).
	f.stats["packed"] = maxi(1, int(f.stats["packed"]))


func _open_sign(f: PopRules) -> void:
	f.stats["sold"] = maxi(1, int(f.stats["sold"]))


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
	# Keep cooking whenever the kettle lets you, until the shelf and the bin are full.
	for i in 60:
		_pop(f)
		f.advance(3000)
	assert_eq(f.shelf.size(), int(f.state()["shelf_cap"]), "the shelf is full")
	assert_false(f.glass.is_empty(), "the glass holds the last lot")
	assert_eq(String(f.bottleneck()), "demand", "demand is the bottleneck (packs wait for customers)")
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
		# Step 25: a basic cooker is a fixed basic machine, so the count grows with the hand's kettle;
		# early on a few out-produce a skilled hand, and within the 40-machine ceiling up to level 6.
		if lv <= 2:
			assert_true(n >= 2 and n <= 12, "level %d: %d basic cookers out-produce a skilled hand per minute (hand %.0f, one cooker %.0f)" % [lv, n, hand_per_min, auto_per_min])
		if lv <= 6:
			assert_true(n <= 40, "level %d: within the 40-machine ceiling (%d)" % [lv, n])


# -- Step 20: the packing station ---------------------------------------------

func _lot(f: PopRules, recipe: String, portions: int, quality: int) -> void:
	# A lot dropped straight into the bin, counted as made (the conservation still holds).
	f.bin.append({"id": f._new_id(), "recipe": recipe, "quality": quality, "portions": portions})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + portions


func _shelved(f: PopRules) -> Array:
	return f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "pack_shelved")


func test_a_partial_portion_waits_and_nothing_is_invented() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	_lot(f, "plain", 1, 100)
	f.advance(20000)
	assert_eq(f.packing.size(), 0, "one portion is not a pack of two")
	assert_eq(f.shelf.size(), 0, "no pack appears")
	assert_eq(f.bin_portions(), 1, "the portion waits in the bin")
	assert_eq(String(f.packer_state()), "starved", "the station says it is starved")
	assert_true(int(f.stats["packer_starved_ms"]) >= 19900, "and the starving is measured")
	_lot(f, "plain", 1, 60)
	f.advance(int(f.packer()["ms"]) + 100)
	assert_eq(f.shelf.size(), 1, "the second portion completes a pack")
	assert_eq(int(f.shelf[0]["quality"]), 80, "its quality is the portions' average (100 and 60)")
	assert_eq(f.bin_portions(), 0, "both portions used")
	_check_conservation(f, "partial")


func test_no_raw_input_no_packs_and_the_station_idles() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.advance(60000)
	assert_eq(int(f.stats["packed"]), 0, "nothing packed from nothing")
	assert_eq(f.shelf.size(), 0, "the shelf stays empty")
	assert_eq(int(f.stats["packer_starved_ms"]), 60000, "a minute starved, measured")
	assert_eq(f.money, 0, "no money from nothing")


func test_a_backlog_packs_one_cycle_per_head_in_order() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	for q in [100, 80, 60]:
		_lot(f, "plain", 4, q)
	var ms := int(f.packer()["ms"])
	f.advance(ms + 60)
	var ev := _shelved(f)
	assert_eq(ev.size(), 1, "tier 0: one head, one pack per cycle")
	assert_eq(int(f.shelf[0]["quality"]), 100, "FIFO: the oldest lot first")
	f.advance(ms * 5 + 300)
	assert_eq(f.shelf.size(), 6, "the backlog of twelve portions becomes six packs")
	assert_eq(f.bin_portions(), 0, "the bin emptied")
	_check_conservation(f, "backlog")


func test_a_full_shelf_blocks_the_station_measurably() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	_lot(f, "plain", 24, 100)
	f.advance(int(f.packer()["ms"]) * 12)
	var cap := int(f.state()["shelf_cap"])
	assert_eq(f.shelf.size(), cap, "the shelf fills to its size")
	assert_eq(f.bin_portions(), 24 - cap * 2, "the rest stays in the bin")
	var blocked := int(f.stats["packer_blocked_ms"])
	f.advance(10000)
	assert_eq(f.shelf.size(), cap, "never over-filled")
	assert_eq(String(f.packer_state()), "blocked", "the station says the shelf is full")
	assert_eq(int(f.stats["packer_blocked_ms"]) - blocked, 10000, "the blocking is measured")
	_check_conservation(f, "blocked")


func test_packer_upgrades_change_throughput_and_the_station() -> void:
	var f: PopRules = Factory.new()
	_open(f)
	_quiet_shop(f)
	var tiers: Array = f.economy.table("factory")["packer"]
	for k in range(1, tiers.size()):
		assert_true(f.packs_per_min(k) > f.packs_per_min(k - 1), "tier %d packs faster than tier %d" % [k, k - 1])
		assert_true(int(tiers[k]["cost"]) > int(tiers[k - 1]["cost"]), "and costs more")
	var r: Dictionary = f.execute({"type": "buy_packer"})
	assert_false(bool(r["ok"]), "no money: refused")
	assert_eq(String(r["reason"]), "err.not_enough_money", "with the reason")
	f.money = 10000
	assert_true(bool(f.execute({"type": "buy_packer"})["ok"]), "tier 1 bought")
	assert_true(bool(f.execute({"type": "buy_packer"})["ok"]), "tier 2 bought (two heads)")
	assert_eq(f.money, 10000 - int(tiers[1]["cost"]) - int(tiers[2]["cost"]), "paid the prices, once")
	assert_eq(int(f.level), 0, "the kettle untouched (an independent upgrade)")
	_lot(f, "plain", 8, 100)
	f.advance(60)
	assert_eq(f.packing.size(), 2, "two heads fill two packs at once")
	f.advance(int(f.packer()["ms"]) + 60)
	assert_eq(f.shelf.size(), 2, "both sealed after one cycle of the new tier's time")
	_check_conservation(f, "upgraded")


func test_an_upgrade_mid_cycle_keeps_the_packs_in_progress() -> void:
	var f: PopRules = Factory.new()
	_open(f)
	_quiet_shop(f)
	f.money = 1000
	_lot(f, "plain", 4, 100)
	f.advance(1000)
	assert_eq(f.packing.size(), 1, "a pack in progress")
	var left := int(f.packing[0]["left_ms"])
	f.execute({"type": "buy_packer"})
	assert_eq(int(f.packing[0]["left_ms"]), left, "the pack in progress keeps its time (not sped up, not lost)")
	_check_conservation(f, "mid-cycle")
	f.advance(left + 60)
	assert_eq(f.shelf.size(), 1, "it finishes")
	assert_eq(int(f.packing[0]["ms"]), int(f.packer(1)["ms"]), "the next pack uses the new tier's time")
	_check_conservation(f, "after")


func test_a_paused_cycle_resumes_exactly() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	_lot(f, "plain", 2, 100)
	f.advance(1200)
	var left := int(f.packing[0]["left_ms"])
	# No time passes (a hidden tab: the app stops advancing the model).
	assert_eq(int(f.packing[0]["left_ms"]), left, "nothing moves while the model does not advance")
	f.advance(left - 100)
	assert_eq(f.shelf.size(), 0, "not before its time")
	f.advance(200)
	assert_eq(f.shelf.size(), 1, "then sealed")


func test_recipes_convert_to_their_sku_never_mix_and_orders_get_their_own() -> void:
	var f: PopRules = Factory.new()
	_open(f)
	_quiet_shop(f)
	f.economy.table("factory")["pack_recipes"]["caramel"] = "caramel"
	f.money = 5000
	f.execute({"type": "buy_packer"})
	f.execute({"type": "buy_packer"})   # two heads: the mix test sees both at once
	_lot(f, "caramel", 1, 100)
	_lot(f, "plain", 1, 100)
	f.advance(3000)
	assert_eq(f.packing.size() + f.shelf.size(), 0, "one caramel and one plain portion never make a pack")
	_lot(f, "plain", 1, 80)
	f.advance(int(f.packer()["ms"]) + 60)
	assert_eq(f.shelf.size(), 1, "two plain portions do")
	assert_eq(String(f.shelf[0]["recipe"]), "plain", "as a plain pack")
	assert_eq(f.bin_portions_of("caramel"), 1, "the caramel portion still waits")
	_lot(f, "caramel", 3, 100)
	f.advance(int(f.packer()["ms"]) * 2 + 60)
	var skus: Array = f.shelf.map(func(p: Dictionary) -> String: return String(p["recipe"]))
	assert_eq(skus.count("caramel"), 2, "four caramel portions became two caramel packs")
	# A customer who orders plain gets the plain pack even though caramel is on the shelf.
	f.queue.append({"id": f._new_id(), "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
	f.drain_events()
	f.advance(100)
	var sv := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "serve_started")
	assert_eq(sv.size(), 1, "served")
	assert_eq(String(f.serving["pack"]["recipe"]), "plain", "with the plain pack it ordered")
	f.queue.append({"id": f._new_id(), "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
	f.advance(5000)
	assert_eq(int(f.stats["sold"]), 1, "a second plain order is not given caramel")
	_check_conservation(f, "recipes")
	f.economy.table("factory")["pack_recipes"].erase("caramel")


# -- Step 21: the counter -----------------------------------------------------

func test_each_pack_sells_once_to_one_customer_and_the_ledger_is_the_money() -> void:
	var f: PopRules = Factory.new()
	for i in 12:
		_pop(f)
		f.advance(2500)
	f.advance(120000)
	assert_true(int(f.stats["sold"]) >= 4, "sales happened (%d)" % int(f.stats["sold"]))
	assert_eq(f.ledger.size(), int(f.stats["sold"]), "one ledger line per sale")
	var coins := 0
	var packs := {}
	var people := {}
	for l: Dictionary in f.ledger:
		coins += int(l["coins"])
		assert_false(packs.has(int(l["pack"])), "pack %d sold once" % int(l["pack"]))
		assert_false(people.has(int(l["customer"])), "customer %d bought once" % int(l["customer"]))
		packs[int(l["pack"])] = true
		people[int(l["customer"])] = true
	assert_eq(coins, int(f.stats["revenue"]), "the ledger adds up to the revenue")
	assert_eq(f.money, coins, "and to the money (nothing bought)")
	_check_conservation(f, "sales")


func test_no_stock_no_sale_and_customers_leave_quietly() -> void:
	var f: PopRules = Factory.new()
	f.advance(200000)
	assert_eq(int(f.stats["sold"]), 0, "no packs: no sale")
	assert_eq(f.money, 0, "no money")
	assert_eq(f.ledger.size(), 0, "no ledger line")
	assert_true(int(f.stats["abandoned"]) >= 1, "people waited and left (%d)" % int(f.stats["abandoned"]))
	assert_true(f.queue.size() <= int(f.queue_cap()), "the queue never over its cap")


func test_two_lanes_serve_two_at_once_in_queue_order() -> void:
	var f: PopRules = Factory.new()
	f.economy.table("factory")["counter"]["lanes"] = 2
	_quiet_shop(f)
	for k in 3:
		f.queue.append({"id": f._new_id(), "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
	var order: Array = f.queue.map(func(c: Dictionary) -> int: return int(c["id"]))
	for k in 3:
		f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 100})
		f.stats["made_portions"] = int(f.stats["made_portions"]) + 2
	f.drain_events()
	f.advance(100)
	var started := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "serve_started")
	assert_eq(started.size(), 2, "two lanes: two hand-overs at once")
	assert_eq(int(started[0]["data"]["customer"]), int(order[0]), "the queue's head first")
	assert_eq(int(started[1]["data"]["customer"]), int(order[1]), "then the next")
	assert_true(int(started[0]["data"]["lane"]) != int(started[1]["data"]["lane"]), "on different lanes")
	var service := int(f.economy.table("factory")["service_ms"])
	f.advance(service + 100)
	assert_eq(int(f.stats["sold"]), 2, "both sold after one service time")
	f.advance(service + 100)
	assert_eq(int(f.stats["sold"]), 3, "then the third")
	_check_conservation(f, "lanes")
	f.economy.table("factory")["counter"]["lanes"] = 1


func test_nobody_jumps_the_queue() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.queue.append({"id": f._new_id(), "order": {"recipe": "caramel", "size": 2}, "patience_ms": 3000})
	f.queue.append({"id": f._new_id(), "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
	f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 100})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 2
	f.advance(1000)
	assert_eq(int(f.stats["sold"]), 0, "the head's order is not here: nobody behind is served first")
	f.advance(2500 + int(f.economy.table("factory")["service_ms"]) + 200)
	assert_eq(int(f.stats["abandoned"]), 1, "the head leaves after waiting")
	assert_eq(int(f.stats["sold"]), 1, "then the next customer gets the plain pack")


# -- Step 22: foot traffic, the sign, the save --------------------------------

func _traffic(tier: int, seed_value: int, minutes: int) -> Array:
	var f: PopRules = Factory.new(null, seed_value)
	f.sign_tier = tier
	f.advance(minutes * 60000)
	return f.arrival_log.duplicate()


func test_arrivals_follow_the_sign_never_fixed_never_bursts_never_droughts() -> void:
	var f: PopRules = Factory.new()
	for tier in [0, 3, 6]:
		var mins := 60
		var log := _traffic(tier, 1234 + tier, mins)
		var s: Dictionary = f.shop_sign(tier)
		var gaps: Array[int] = []
		for i in range(2, log.size()):   # from the third: the opening exception (one waiting, the second soon)
			gaps.append(int(log[i]) - int(log[i - 1]))
		var mean := 0.0
		for g in gaps:
			mean += g
		mean /= gaps.size()
		var want := float(f.mean_wait_ms(tier))
		assert_true(absf(mean - want) / want < 0.08, "tier %d: the mean wait %.0f ms is near the expected %.0f" % [tier, mean, want])
		assert_true(gaps.min() >= int(s["min_ms"]) - 50, "tier %d: no burst (shortest %d >= %d)" % [tier, gaps.min(), s["min_ms"]])
		assert_true(gaps.max() <= int(s["max_ms"]) + 100, "tier %d: no drought (longest %d <= %d)" % [tier, gaps.max(), s["max_ms"]])
		var distinct := {}
		for g in gaps:
			distinct[g / 100] = true
		assert_true(distinct.size() > 8, "tier %d: not a fixed timer (%d different waits)" % [tier, distinct.size()])
	var t0 := _traffic(0, 99, 10)
	var t1 := _traffic(0, 99, 10)
	var t2 := _traffic(0, 100, 10)
	assert_eq(t0, t1, "the same seed draws the same customers")
	assert_true(t0 != t2, "another seed draws others")
	assert_eq(int(t0[0]), 0, "the first customer is waiting when the shop opens")
	assert_true(int(t0[1]) >= 4000 and int(t0[1]) <= 8100, "the second comes within 4-8 s (%d)" % int(t0[1]))


func test_the_sign_buys_shorter_waits_and_a_bigger_shop() -> void:
	var f: PopRules = Factory.new()
	_open(f)
	_open_sign(f)
	var tiers: Array = f.economy.table("factory")["sign"]
	for k in range(1, tiers.size()):
		assert_true(f.mean_wait_ms(k) < f.mean_wait_ms(k - 1), "tier %d: customers come more often" % k)
		assert_true(int(tiers[k]["lanes"]) >= int(tiers[k - 1]["lanes"]) and int(tiers[k]["queue_cap"]) >= int(tiers[k - 1]["queue_cap"]), "tier %d: the shop never shrinks" % k)
		assert_true(int(tiers[k]["min_ms"]) < int(tiers[k]["mode_ms"]) and int(tiers[k]["mode_ms"]) < int(tiers[k]["max_ms"]), "tier %d: a real spread" % k)
	assert_false(bool(f.execute({"type": "buy_sign"})["ok"]), "no money: refused")
	f.money = 100
	assert_true(bool(f.execute({"type": "buy_sign"})["ok"]), "bought")
	assert_eq(int(f.sign_tier), 1, "tier 1")
	assert_eq(int(f.money), 100 - int(tiers[1]["cost"]), "paid once")
	assert_eq(int(f.level) + int(f.packer_tier), 0, "the kettle and the station untouched")


func test_a_slow_player_and_a_sold_out_counter() -> void:
	var f: PopRules = Factory.new()
	f.advance(600000)
	assert_true(f.queue.size() <= int(f.queue_cap()), "the queue never over its cap")
	assert_eq(f.money, 0, "a player who never pops earns nothing")
	assert_eq(int(f.stats["visitors"]), f.arrival_log.size(), "every visitor logged")
	assert_eq(int(f.stats["visitors"]), int(f.stats["arrived"]) + int(f.stats["passed_by"]), "visitors = joined + walked past")
	assert_eq(int(f.stats["arrived"]), f.queue.size() + int(f.stats["abandoned"]) + int(f.stats["sold"]) + f.serves.size(), "everyone who joined is waiting, served, or left")
	# Sold out: a customer waits; one pack arrives; they get it, the next keeps waiting.
	var g: PopRules = Factory.new()
	g.advance(9000)
	assert_eq(g.queue.size(), 2, "two waiting, nothing to sell")
	_pop(g)
	g.advance(12000)
	assert_eq(int(g.stats["sold"]), 2, "the one lot of four made two packs: two sales, no more")
	assert_eq(g.shelf.size(), 0, "sold out again")


func test_a_long_advance_equals_many_short_ones_with_a_bigger_shop() -> void:
	var a: PopRules = Factory.new()
	var b: PopRules = Factory.new()
	for f: PopRules in [a, b]:
		f.sign_tier = 3
		f.money = 0
	_pop(a)
	_pop(b)
	a.advance(300000)
	for i in 3000:
		b.advance(100)
	assert_eq(a.arrival_log, b.arrival_log, "the same customers however time is cut")
	assert_eq(a.stats, b.stats, "the same statistics")


func test_save_and_resume_continue_the_same_factory() -> void:
	var a: PopRules = Factory.new(null, 777)
	_open(a)
	_open_sign(a)
	a.money = 1000
	a.execute({"type": "buy_packer"})
	a.execute({"type": "buy_sign"})
	for i in 6:
		_pop(a)
		a.advance(2300)
	a.advance(7000)
	var text := JSON.stringify(a.to_save())
	var b: PopRules = Factory.new(null, 1)
	assert_true(bool(b.from_save(JSON.parse_string(text))), "a whole save loads")
	assert_eq(int(b.portions_everywhere()), int(b.stats["made_portions"]), "every portion where it was")
	assert_eq(b.money, a.money, "the money")
	assert_eq(int(b.packer_tier) + int(b.sign_tier), 2, "the tiers")
	a.advance(180000)
	b.advance(180000)
	assert_eq(b.arrival_log, a.arrival_log, "the resumed run draws the same customers")
	assert_eq(b.stats, a.stats, "and ends the same")
	assert_eq(b.money, a.money, "with the same money")
	var bad: Dictionary = JSON.parse_string(text)
	bad["stats"]["made_portions"] = int(bad["stats"]["made_portions"]) + 3
	var c: PopRules = Factory.new()
	assert_false(bool(c.from_save(bad)), "a save whose goods do not add up is refused")
	assert_eq(int(c.money), 0, "and changes nothing")
	var odd: Dictionary = JSON.parse_string(text)
	odd["sign_tier"] = 99
	assert_false(bool(c.from_save(odd)), "a tier out of range is refused")


# -- Step 23: orders, sizes, the bottleneck -----------------------------------

func _customer(f: PopRules, size: int, patience: int = 60000) -> int:
	var id: int = f._new_id()
	f.queue.append({"id": id, "order": {"recipe": "plain", "size": size}, "patience_ms": patience})
	return id


func test_the_large_bag_opens_with_the_station_and_orders_never_move_arrivals() -> void:
	var a: PopRules = Factory.new(null, 5)
	var b: PopRules = Factory.new(null, 5)
	b.packer_tier = 2
	assert_eq(a.sizes_open().size(), 1, "tier 0: the small bag only")
	assert_eq(b.sizes_open().size(), 2, "tier 2: the large bag opens")
	a.advance(3600000)
	b.advance(3600000)
	assert_eq(a.arrival_log, b.arrival_log, "the same customers arrive (orders have their own generator)")
	var large := 0
	var all := 0
	for l: Dictionary in b.ledger:
		all += 1
	# Orders of everyone who came: count from the generator directly.
	var c: PopRules = Factory.new(null, 5)
	c.packer_tier = 2
	for i in 400:
		all += 0
		if int(c._draw_order()["size"]) == 4:
			large += 1
	assert_true(large > 110 and large < 170, "about 35%% order the large bag (%d of 400)" % large)
	var d: PopRules = Factory.new(null, 5)
	for i in 100:
		assert_eq(int(d._draw_order()["size"]), 2, "before it opens nobody orders it")


func test_exact_size_matching_and_the_large_bag_price() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.packer_tier = 2
	f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 100})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 2
	_customer(f, 4, 20000)
	f.advance(2000)
	assert_eq(int(f.stats["sold"]), 0, "a large-bag customer is never given a small bag")
	assert_eq(int(f.packer_state() == "starved"), 1, "and the station has no popcorn for a large bag")
	_lot(f, "plain", 4, 100)
	f.advance(int(f.packer()["ms"]) + int(f.economy.table("factory")["service_ms"]) + 1000)
	assert_eq(int(f.stats["sold"]), 1, "a large bag packed for them and sold")
	assert_eq(int(f.ledger[0]["size"]), 4, "the large bag")
	assert_eq(int(f.ledger[0]["coins"]), 18, "at its own price")
	assert_eq(f.shelf.size(), 1, "the small bag still waits for a small order")
	_check_conservation(f, "sizes")


func test_the_station_packs_for_the_head_first_and_never_floods_the_shelf_with_large_bags() -> void:
	var f: PopRules = Factory.new(null, 9)
	f.packer_tier = 2
	var worst := 0
	for i in 400:
		if i % 3 == 0:
			_pop(f)
		f.advance(700)
		var waiting_large := 0
		for c: Dictionary in f.queue:
			if int(c["order"]["size"]) == 4:
				waiting_large += 1
		worst = maxi(worst, f.on_hand("plain", 4) - waiting_large)
	assert_true(worst <= 2, "large bags on hand never beyond the orders waiting + a stock of 2 (worst %d)" % worst)
	assert_true(int(f.stats["sold"]) > 10, "sales happened (%d)" % int(f.stats["sold"]))
	var sizes := {}
	for l: Dictionary in f.ledger:
		sizes[int(l["size"])] = true
	assert_true(sizes.has(2) and sizes.has(4), "both bags sold")
	_check_conservation(f, "mixed")


func test_a_mixed_burst_is_served_once_each_in_order() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.packer_tier = 2
	var ids: Array[int] = []
	for s in [2, 4, 2, 2, 4]:
		ids.append(_customer(f, s))
	for s in [2, 2, 2, 4, 4]:
		f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": s, "quality": 100})
		f.stats["made_portions"] = int(f.stats["made_portions"]) + s
	f.advance(5 * int(f.economy.table("factory")["service_ms"]) + 2000)
	assert_eq(int(f.stats["sold"]), 5, "all five served")
	for i in 5:
		assert_eq(int(f.ledger[i]["customer"]), ids[i], "in queue order (%d)" % i)
	assert_eq(f.ledger.map(func(l: Dictionary) -> int: return int(l["size"])), [2, 4, 2, 2, 4], "each got the size they ordered")
	assert_eq(f.shelf.size(), 0, "no pack left over, none sold twice")
	_check_conservation(f, "burst")


func test_an_impatient_exit_costs_nothing_and_the_station_waits_for_the_right_popcorn() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.packer_tier = 2
	f.money = 50
	_customer(f, 4, 3000)
	_lot(f, "plain", 2, 100)
	f.advance(2000)
	assert_eq(f.packing.size(), 0, "two portions are not packed into a small bag while the head waits for a large one")
	f.advance(2000)
	assert_eq(int(f.stats["abandoned"]), 1, "the customer leaves")
	assert_eq(int(f.money), 50, "a gentle consequence: nothing is taken")
	f.advance(int(f.packer()["ms"]) + 200)
	assert_eq(f.shelf.size(), 1, "with nobody waiting, the portions become stock (a small bag)")
	_check_conservation(f, "exit")


func test_the_bottleneck_names_the_stage_that_holds_the_next_one_back() -> void:
	var f: PopRules = Factory.new()
	assert_eq(String(f.instant_bottleneck()), "", "a customer who just came in is not a shortage yet")
	f.advance(6500)
	assert_eq(String(f.instant_bottleneck()), "production", "a customer has waited 6 s, no popcorn: production (now)")
	assert_eq(String(f.bottleneck()), "", "but not yet for most of the last 30 s: nothing shown")
	f.advance(20000)
	assert_eq(String(f.bottleneck()), "production", "held for most of the last 30 s: shown")
	_pop(f)
	f.advance(1500)
	assert_eq(String(f.instant_bottleneck()), "packaging", "popcorn there, packing under way while they wait: packaging (now)")
	assert_eq(String(f.bottleneck()), "production", "a moment does not change what is shown")
	var g: PopRules = Factory.new()
	_quiet_shop(g)
	_lot(g, "plain", 24, 100)
	g.advance(60000)
	assert_eq(String(g.bottleneck()), "demand", "a full shelf, nobody waiting: demand")
	assert_true(int(g.per_min("packs")) >= 4, "the station's last minute counted (%d packs)" % int(g.per_min("packs")))
	g.advance(90000)
	assert_eq(int(g.per_min("packs")), 0, "a minute later, the count is of the last minute only")


# -- Step 24: a lot bigger than the bin, the unlock policy, truthful upgrades ----

func test_a_lot_bigger_than_the_bin_flows_through_in_parts() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.level = 9   # 45 portions a perfect pop: almost twice the bin (24)
	_pop(f)
	assert_eq(int(f.glass["portions"]), int(f.kettle_capacity()), "the lot is in the glass")
	var made := int(f.stats["made_portions"])
	for i in 60:
		f.advance(1000)
		f.shelf.clear()   # (sold off-screen: keep the shelf from blocking, to test the glass)
		f.stats["made_portions"] = made
	assert_true(f.glass.is_empty(), "the whole lot left the glass, in parts (before the fix it waited forever)")
	assert_true(bool(f.execute({"type": "press"})["ok"]), "and the kettle cooks again")


func test_the_station_and_the_sign_open_one_at_a_time() -> void:
	var f: PopRules = Factory.new()
	f.money = 10000
	assert_eq(String(f.execute({"type": "buy_packer"})["reason"]), "err.locked", "the station: not before its first sealed pack")
	assert_eq(String(f.execute({"type": "buy_sign"})["reason"]), "err.locked", "the sign: not before the first sale")
	assert_true(bool(f.execute({"type": "buy"})["ok"]), "the kettle from the start")
	_pop(f)
	f.advance(6000)
	assert_true(bool(f.station_open("packer")), "a pack sealed: the station opens")
	assert_true(bool(f.execute({"type": "buy_packer"})["ok"]), "and can be bought")
	f.advance(10000)
	assert_true(int(f.stats["sold"]) >= 1, "a sale")
	assert_true(bool(f.execute({"type": "buy_sign"})["ok"]), "then the sign")


## A hand that pops whenever the kettle is free, at most every `every_ms`, for `minutes`.
func _played(sign: int, packer: int, level: int, every_ms: int, minutes: int) -> PopRules:
	var f: PopRules = Factory.new(null, 20261116)
	f.sign_tier = sign
	f.packer_tier = packer
	f.level = level
	var t := 0
	var next_pop := 0
	while t < minutes * 60000:
		if t >= next_pop and f.glass.is_empty() and int(f.cooldown_left) <= 0:
			f.execute({"type": "press"})
			var hold: int = (int(f.window_start()) + int(f.window_end())) / 2
			f.advance(hold)
			t += hold
			f.execute({"type": "release"})
			next_pop = t + every_ms
		f.advance(250)
		t += 250
	return f


func test_every_upgrade_relieves_the_bottleneck_it_is_bought_for() -> void:
	var cases := [
		["the sign, when customers are the limit", [0, 0, 0, 2000], [3, 0, 0, 2000]],
		["the station's 1st tier, when sign 4 brings more than it packs", [4, 0, 0, 2000], [4, 1, 0, 2000]],
		["the station's 2nd tier, at sign 5", [5, 1, 0, 2000], [5, 2, 0, 2000]],
		["the kettle, when the hand cannot keep up with sign 6", [6, 3, 0, 2000], [6, 3, 4, 2000]],
		["the kettle, for a slow hand", [3, 0, 0, 20000], [3, 0, 4, 20000]],
	]
	for c: Array in cases:
		var a: Array = c[1]
		var b: Array = c[2]
		var before := _played(a[0], a[1], a[2], a[3], 5)
		var after := _played(b[0], b[1], b[2], b[3], 5)
		var s0 := int(before.stats["sold"])
		var s1 := int(after.stats["sold"])
		assert_true(s1 > s0 * 1.15, "%s: sales %d -> %d" % [c[0], s0, s1])
		_check_conservation(after, c[0])
	# The station's last tier only pays off once the kettle keeps up (bought alone at sign 6, the kettle is the limit).
	var alone := _played(6, 3, 0, 2000, 5)
	assert_eq(String(alone.bottleneck()) in ["production", "packaging", ""], true, "the next limit is named")


func test_the_sign_brings_people_never_goods_or_money() -> void:
	var a := _played(0, 0, 0, 2000, 5)
	var b := _played(3, 0, 0, 2000, 5)
	assert_true(int(b.stats["visitors"]) > int(a.stats["visitors"]) * 2, "more customers come (%d vs %d)" % [b.stats["visitors"], a.stats["visitors"]])
	for f: PopRules in [a, b]:
		assert_true(int(f.stats["sold"]) <= int(f.stats["packed"]), "never more sales than packs sealed")
		var coins := 0
		for l: Dictionary in f.ledger:
			coins += int(l["coins"])
		assert_eq(coins, int(f.stats["revenue"]), "all money from sales of real packs")
		_check_conservation(f, "sign")
	# With nobody cooking, the best sign brings a crowd and still makes nothing.
	var idle: PopRules = Factory.new()
	idle.sign_tier = 6
	idle.advance(600000)
	assert_true(int(idle.stats["visitors"]) > 300, "the landmark brings people (%d)" % int(idle.stats["visitors"]))
	assert_eq(int(idle.stats["made_portions"]) + int(idle.stats["packed"]) + int(idle.stats["sold"]) + int(idle.money), 0, "and no popcorn, no packs, no sales, no money")


# -- Step 25: the basic auto cooker and its upkeep ------------------------------

func test_auto_cookers_open_with_the_sign_and_cost_more_each() -> void:
	var f: PopRules = Factory.new()
	f.money = 100000
	assert_eq(String(f.execute({"type": "buy_auto"})["reason"]), "err.locked", "not before the sign's unlock tier")
	f.sign_tier = int(f.economy.table("factory")["auto_cooker"]["unlock_sign"])
	var prices: Array[int] = []
	for i in int(f.slots("kitchen")):
		prices.append(int(f.auto_cost()))
		assert_true(bool(f.execute({"type": "buy_auto"})["ok"]), "cooker %d bought" % (i + 1))
	for i in range(1, prices.size()):
		assert_true(prices[i] > prices[i - 1], "each costs more (%d > %d)" % [prices[i], prices[i - 1]])
	assert_eq(String(f.execute({"type": "buy_auto"})["reason"]), "err.no_slot", "the kitchen's places are full (Step 26)")
	assert_eq(int(f.money), 100000 - prices.reduce(func(a: int, b: int) -> int: return a + b, 0), "paid each once")


func test_upkeep_is_paid_a_coin_at_a_time_and_never_becomes_a_debt() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.sign_tier = int(f.economy.table("factory")["auto_cooker"]["unlock_sign"])
	f.money = int(f.auto_cost())
	f.execute({"type": "buy_auto"})
	f.machines[0]["kernels"] = 1000   # (fed: this test is about upkeep, not kernels)
	assert_eq(int(f.money), 0, "the cooker took the last coin")
	f.money = 3
	f.advance(60000)
	assert_eq(int(f.money), 0, "it paid what there was")
	assert_eq(int(f.stats["upkeep_paid"]), 3, "three coins")
	assert_eq(String(f.cookers[0]["state"]), "unpaid", "then it paused (never below zero)")
	var lots := int(f.stats["auto_lots"])
	f.advance(30000)
	assert_eq(int(f.stats["auto_lots"]), lots, "paused: no lots, no debt")
	assert_true(int(f.money) >= 0, "money never negative")
	f.money = 10
	f.advance(20000)
	assert_true(int(f.stats["auto_lots"]) > lots, "a coin there: it resumes")
	_check_conservation(f, "upkeep")


func test_a_blocked_cooker_holds_its_lot_and_pays_nothing() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	f.sign_tier = int(f.economy.table("factory")["auto_cooker"]["unlock_sign"])
	f.money = int(f.auto_cost()) + 1000
	f.execute({"type": "buy_auto"})
	_lot(f, "plain", 24, 100)   # a full bin, and a full shelf so nothing drains it
	for k in 8:
		f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 100})
		f.stats["made_portions"] = int(f.stats["made_portions"]) + 2
	var paid := int(f.stats.get("upkeep_paid", 0))
	f.advance(6100)
	assert_eq(String(f.cookers[0]["state"]), "blocked", "its lot waits for room")
	f.advance(10000)
	assert_true(int(f.stats["upkeep_paid"]) - paid <= 1, "no upkeep while blocked")
	_check_conservation(f, "blocked cooker")


func test_a_good_hand_beats_one_cooker_per_batch_and_cookers_win_by_numbers() -> void:
	var f: PopRules = Factory.new()
	f.sign_tier = int(f.economy.table("factory")["auto_cooker"]["unlock_sign"])
	f.money = 1 << 30
	f.execute({"type": "buy_auto"})
	f.machines[0]["kernels"] = 1000
	_quiet_shop(f)
	var t := 0
	assert_eq(f.cookers.size(), 1, "a cooker bought")
	while int(f.stats.get("auto_lots", 0)) < 50 and t < 3600000:
		f.advance(1000)
		f.bin.clear()   # (an endless sink, to measure the cooker alone)
		f.lift.clear()
		t += 1000
	var auto_avg := float(f.stats["auto_portions"]) / float(f.stats["auto_lots"])
	assert_true(float(f.kettle_capacity()) > auto_avg * 1.4, "a perfect hand batch (%d) beats a cooker's batch (%.1f)" % [f.kettle_capacity(), auto_avg])
	# Over five minutes at sign 6: the hand alone vs the hand resting while 8 cookers work.
	var hand := _played(6, 3, 4, 2000, 5)
	var crew: PopRules = Factory.new(null, 20261116)
	crew.sign_tier = 6
	crew.packer_tier = 3
	crew.level = 4
	crew.money = 1 << 30
	for i in 4:
		crew.execute({"type": "buy_auto"})
	for m: Dictionary in crew.machines:
		crew.execute({"type": "upgrade_machine", "id": m["id"]})
		crew.execute({"type": "upgrade_machine", "id": m["id"]})
		m["kernels"] = 1000
	crew.money = 100000
	crew.advance(300000)
	assert_true(int(crew.stats["sold"]) >= int(hand.stats["sold"]) * 0.9, "4 top-tier cookers keep up with a skilled hand over time (%d vs %d sales)" % [crew.stats["sold"], hand.stats["sold"]])
	_check_conservation(crew, "crew")


# -- Step 26: the machine runtime -----------------------------------------------

func _rich(f: PopRules) -> void:
	f.sign_tier = 3
	f.packer_tier = 1
	f.money = 100000
	_open(f)


func test_build_sell_upgrade_pause_and_slots() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	_rich(f)
	var r: Dictionary = f.execute({"type": "build", "machine": "bagger", "slot": 1})
	assert_true(bool(r["ok"]), "a bagger built in place 1")
	assert_eq(String(f.execute({"type": "build", "machine": "bagger", "slot": 1})["reason"]), "err.slot_taken", "two machines never share a place")
	assert_eq(String(f.execute({"type": "build", "machine": "bagger", "slot": 9})["reason"]), "err.no_slot", "no place 9 on that floor")
	var id := int(r["machine"])
	var before := int(f.money)
	assert_true(bool(f.execute({"type": "upgrade_machine", "id": id})["ok"]), "upgraded")
	assert_eq(int(f.machine(id)["tier"]), 1, "tier 1")
	assert_true(bool(f.execute({"type": "pause_machine", "id": id, "paused": true})["ok"]), "paused")
	assert_eq(String(f.machine(id)["state"]), "paused", "it says so")
	_lot(f, "plain", 8, 100)
	f.advance(20000)
	assert_eq(String(f.machine(id)["state"]), "paused", "a paused machine stays paused")
	f.execute({"type": "pause_machine", "id": id, "paused": false})
	var paid := int(f.machine(id)["paid"])
	before = int(f.money)
	assert_true(bool(f.execute({"type": "sell_machine", "id": id})["ok"]) or not (f.machine(id)["held"] as Dictionary).is_empty(), "sold (or busy with a pack)")
	if f.machine(id).is_empty():
		assert_eq(int(f.money), before + paid / 2, "half of what it cost comes back")
	for k in int(f.slots("kitchen")):
		f.execute({"type": "build", "machine": "cooker", "slot": k})
	assert_eq(String(f.execute({"type": "build", "machine": "cooker"})["reason"]), "err.no_slot", "the kitchen's places are full")
	_check_conservation(f, "lifecycle")


func test_the_bagger_packs_real_portions_and_waits_or_holds_honestly() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	_rich(f)
	f.packer_tier = 1
	var id := int(f.execute({"type": "build", "machine": "bagger"})["machine"])
	f.advance(3000)
	assert_eq(String(f.machine(id)["state"]), "starved", "nothing in the bin: it waits, no upkeep")
	assert_eq(int(f.stats["upkeep_paid"]), 0, "and pays nothing")
	_lot(f, "plain", 24, 100)
	f.advance(60000)
	assert_true(int(f.stats["packed"]) >= 8, "the station and the bagger sealed real packs")
	assert_true(int(f.machine(id).get("done", 0)) >= 1, "the bagger sealed some of them (%d)" % int(f.machine(id).get("done", 0)))
	assert_true(int(f.stats["upkeep_paid"]) > 0 or int(f.machine(id)["upkeep_ms"]) > 0, "its work is charged (a coin per 20 s of work)")
	assert_eq(f.shelf.size(), int(f.state()["shelf_cap"]), "the shelf full")
	assert_true(String(f.machine(id)["state"]) in ["blocked", "starved"], "it stops when nothing is wanted or the shelf is full")
	_check_conservation(f, "bagger")


func test_the_kiosk_serves_real_customers_and_pays_while_it_serves() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	_rich(f)
	var id := int(f.execute({"type": "build", "machine": "kiosk"})["machine"])
	for k in 6:
		f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 100})
		f.stats["made_portions"] = int(f.stats["made_portions"]) + 2
	for k in 4:
		_customer(f, 2)
	f.drain_events()
	f.advance(100)
	var ev := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "serve_started")
	var lanes := int(f.lanes())
	assert_eq(ev.size(), lanes + 1, "the counter's lanes and the kiosk serve at once")
	assert_true(ev.any(func(e: Dictionary) -> bool: return int(e["data"].get("kiosk", -1)) == id), "the kiosk took one")
	f.advance(10000)
	assert_eq(int(f.stats["sold"]), 4, "all four sold, each once")
	assert_true(int(f.stats["upkeep_paid"]) >= 0, "upkeep only while serving")
	_check_conservation(f, "kiosk")


func test_low_funds_pause_machines_and_nothing_is_lost() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	_rich(f)
	for k in 4:
		f.execute({"type": "build", "machine": "cooker", "slot": k})
	f.money = 2
	f.advance(120000)
	assert_eq(int(f.money), 0, "the last coins paid")
	assert_true(f.cookers.all(func(m: Dictionary) -> bool: return String(m["state"]) in ["unpaid", "blocked"]), "every cooker paused or holding a lot")
	assert_true(int(f.money) >= 0, "never a debt")
	_check_conservation(f, "low funds")


func test_simultaneous_finishes_and_any_cut_of_time_give_the_same_factory() -> void:
	var a: PopRules = Factory.new()
	var b: PopRules = Factory.new()
	for f: PopRules in [a, b]:
		_rich(f)
		for k in 4:
			f.execute({"type": "build", "machine": "cooker", "slot": k})   # all four start together: they finish together
		f.execute({"type": "build", "machine": "bagger"})
		f.execute({"type": "build", "machine": "kiosk"})
		f.money = 5000
	a.advance(240000)
	for i in 4800:
		b.advance(50)
	assert_eq(a.stats, b.stats, "one long advance = 4,800 short ones (machines and all)")
	assert_eq(a.money, b.money, "the same money")
	_check_conservation(a, "cut")
	# Four cookers that start together finish together: four lots in the same step, none lost.
	var c: PopRules = Factory.new()
	_quiet_shop(c)
	_rich(c)
	for k in 4:
		c.execute({"type": "build", "machine": "cooker", "slot": k})
	c.drain_events()
	c.advance(6000)
	var lots := c.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "auto_lot")
	assert_eq(lots.size(), 4, "four lots at the same moment")
	assert_eq(int(c.stats["auto_lots"]), 4, "all counted")
	_check_conservation(c, "simultaneous")


func test_machines_are_saved_and_a_0_25_save_keeps_its_cookers() -> void:
	var a: PopRules = Factory.new()
	_rich(a)
	a.execute({"type": "build", "machine": "cooker", "slot": 2})
	a.execute({"type": "build", "machine": "bagger"})
	a.execute({"type": "pause_machine", "id": 2, "paused": true})
	a.advance(30000)
	var b: PopRules = Factory.new()
	assert_true(bool(b.from_save(JSON.parse_string(JSON.stringify(a.to_save())))), "a save with machines loads")
	assert_eq(b.machines.size(), 2, "both machines")
	assert_eq(int(b.machine(1)["slot"]), 2, "in their places")
	assert_eq(String(b.machine(2)["state"]), "paused", "the paused one still paused")
	a.advance(60000)
	b.advance(60000)
	assert_eq(b.stats, a.stats, "and the resumed factory runs the same")
	var fresh: PopRules = Factory.new()
	var old: Dictionary = JSON.parse_string(JSON.stringify(fresh.to_save()))
	old.erase("machines")
	old.erase("next_machine_id")
	old["cookers"] = [{"left_ms": 1000, "held": {}, "state": "run", "upkeep_ms": 0}]
	var c: PopRules = Factory.new()
	assert_true(bool(c.from_save(old)), "a 0.25 save loads")
	assert_eq(c.cookers.size(), 1, "its cooker became a machine in the kitchen")


func test_the_hand_tunes_a_selected_cooker_for_a_few_lots_only() -> void:
	var f: PopRules = Factory.new()
	_quiet_shop(f)
	_rich(f)
	var id := int(f.execute({"type": "build", "machine": "cooker"})["machine"])
	f.execute({"type": "select_machine", "id": id})
	_pop(f)
	assert_eq(int(f.machine(id)["assist"]), 3, "a perfect pop tunes its next 3 lots")
	_pop(f)
	f.advance(3000)
	_pop(f)
	assert_eq(int(f.machine(id)["assist"]), 3, "never more than 3 waiting")
	var grades := []
	for i in 30:
		var ev := f.drain_events()
		f.advance(1000)
		f.bin.clear()
		f.lift.clear()
		f.glass = {}
		for e: Dictionary in f.drain_events():
			if String(e["type"]) == "auto_lot":
				grades.append(String(e["data"]["grade"]))
	assert_eq(grades.slice(0, 3), ["perfect", "perfect", "perfect"], "three perfect lots")
	assert_false(grades.slice(3).has("perfect"), "then back to the machine's own odds")


# -- Step 27: the 40-machine catalog and its no-fake-effects matrix ----------------

const CONTRACT_KINDS := ["feed", "dose", "regulate", "agitate", "detect", "eject", "produce", "cool", "sort", "capacity", "grade_split",
	"premix", "stabilize", "recycle", "dispatch", "container", "pack", "weigh", "season", "coat", "seal", "divert", "convey", "ticket",
	"cashier", "route", "express", "menu", "serve", "float_lane", "repair", "neighbor_speed", "upkeep", "buffer", "inspect",
	"freshness", "schedule", "balance"]
## The model's behaviour tests for each machine that runs today.
const RUNTIME_TESTS := {"cooker": "test_upkeep_is_paid_a_coin_at_a_time_and_never_becomes_a_debt",
	"M01": "test_m01_the_hopper_buys_kernels_and_keeps_kettles_cooking", "M02": "test_m02_the_oil_doser_pays_for_oil_and_raises_quality",
	"M03": "test_m03_the_heat_controller_stops_burnt_lots", "M04": "test_m04_the_motor_adds_a_portion_to_its_kettle_only",
	"M05": "test_m05_the_detector_stops_late_lots_and_shortens_its_kettle", "M06": "test_m06_the_ejector_shortens_the_lift_for_every_lot",
	"M08": "test_m08_the_fan_shortens_the_hand_cooldown_and_the_kettles_cycle",
	"bagger": "test_the_bagger_packs_real_portions_and_waits_or_holds_honestly",
	"kiosk": "test_the_kiosk_serves_real_customers_and_pays_while_it_serves"}


func test_forty_stable_ids_in_five_groups_of_eight_with_distinct_contracts() -> void:
	var all: Dictionary = Factory.new().forty()
	var ids := all.keys().filter(func(k: String) -> bool: return not k.begins_with("_"))
	assert_eq(ids.size(), 40, "forty machines")
	for prefix in ["M", "P", "S", "U"]:
		var n := ids.filter(func(k: String) -> bool: return k.begins_with(prefix)).size()
		assert_eq(n, 16 if prefix == "M" else 8, "%s group size" % prefix)
	for i in range(1, 17):
		assert_true(all.has("M%02d" % i), "M%02d exists" % i)
	var seen := {}
	for id: String in ids:
		var e: Dictionary = all[id]
		var c: Dictionary = e["contract"]
		assert_true(String(c["kind"]) in CONTRACT_KINDS, "%s: a named behaviour (%s), not a bare bonus" % [id, c["kind"]])
		var key := JSON.stringify(c)
		assert_false(seen.has(key), "%s: its contract is not a copy of %s" % [id, seen.get(key, "")])
		seen[key] = id
		for f in ["name", "floor", "slots", "parts", "motion", "operation", "inputs", "outputs", "queue", "prereq", "requires", "cost", "upkeep_per_min", "tiers", "marginal", "step"]:
			assert_true(e.has(f), "%s has %s" % [id, f])
		assert_eq((e["tiers"] as Array).size(), 3, "%s: three tiers" % id)
		assert_true(int(e["cost"]) > 0, "%s: a price" % id)
	# The same kind may appear twice only with different parameters (two producers, two containers).
	var kinds := {}
	for id: String in ids:
		kinds[String(all[id]["contract"]["kind"])] = int(kinds.get(String(all[id]["contract"]["kind"]), 0)) + 1
	assert_true(kinds.size() >= 36, "at least 36 different behaviours among 40 (%d)" % kinds.size())


func test_no_machine_is_sold_that_would_do_nothing() -> void:
	var f: PopRules = Factory.new()
	f.sign_tier = 6
	f.packer_tier = 3
	f.money = 1 << 30
	_open(f)
	_open_sign(f)
	var all: Dictionary = f.forty()
	var have: Array = all["_systems"]
	var runs := 1
	assert_true(bool(f.execute({"type": "build", "machine": "M07"})["ok"]), "M07 first (the kitchen devices serve kettles)")
	for id: String in all.keys():
		if id.begins_with("_"):
			continue
		var e: Dictionary = all[id]
		var missing: Array = (e["requires"] as Array).filter(func(s: String) -> bool: return not have.has(s))
		if id == "M07":
			continue
		var r: Dictionary = f.execute({"type": "build", "machine": id})
		if e.get("runtime") == null or not missing.is_empty():
			assert_false(bool(r["ok"]), "%s: not built (it does not run yet%s)" % [id, ", needs %s" % [missing] if not missing.is_empty() else ""])
			assert_eq(String(r["reason"]), "err.not_yet", "%s: with the honest reason" % id)
		else:
			runs += 1
			assert_true(bool(r["ok"]) or String(r["reason"]) in ["err.no_slot", "err.slot_taken"], "%s: a running machine is built (%s)" % [id, r.get("reason", "")])
			assert_true(RUNTIME_TESTS.has(String(e["runtime"])), "%s: its behaviour has a test" % id)
			assert_true(has_method(RUNTIME_TESTS[String(e["runtime"])]), "%s: that test exists (%s)" % [id, RUNTIME_TESTS[String(e["runtime"])]])
	assert_eq(runs, 10, "today: M01-M08, P03 and S07 run")
	assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "nothing invented")


# -- Step 28: M01-M08, the kitchen's devices -------------------------------------

func _kitchen(seed_value: int = 3) -> PopRules:
	var f: PopRules = Factory.new(null, seed_value)
	_quiet_shop(f)
	f.sign_tier = 4
	f.money = 100000
	_open(f)
	return f


## Auto lots made in `ms`, with an endless sink (the bin is emptied as lots arrive).
func _auto_lots(f: PopRules, ms: int) -> Array:
	var out: Array = []
	var t := 0
	while t < ms:
		f.drain_events()
		f.advance(500)
		t += 500
		for e: Dictionary in f.drain_events():
			if String(e["type"]) == "auto_lot":
				out.append(e["data"])
		f.bin.clear()
		f.lift.clear()
	return out


func test_m01_the_hopper_buys_kernels_and_keeps_kettles_cooking() -> void:
	var a := _kitchen()
	a.execute({"type": "build", "machine": "M07"})
	var lots := _auto_lots(a, 60000)
	assert_eq(lots.size(), int(a.economy.table("factory")["auto_cooker"]["kernel_buffer"]), "without a hopper a kettle makes its 5 lots of kernels, then starves")
	assert_eq(String(a.machines[0]["state"]), "starved", "and says so")
	var b := _kitchen()
	b.execute({"type": "build", "machine": "M07"})
	b.execute({"type": "build", "machine": "M01"})
	var before := int(b.money)
	var more := _auto_lots(b, 60000)
	assert_true(more.size() >= 9, "with the hopper it keeps cooking (%d lots)" % more.size())
	assert_true(int(b.stats["kernels_paid"]) >= more.size() - 5, "the kernels were bought from the wallet")
	assert_true(int(b.money) < before, "and paid for")
	var c := _kitchen()
	c.execute({"type": "build", "machine": "M07"})
	_auto_lots(c, 60000)
	var refill := int(c.refill_cost(c.machines[0]))
	assert_true(bool(c.execute({"type": "refill", "id": c.machines[0]["id"]})["ok"]), "a starved kettle is refilled by hand")
	assert_eq(int(c.stats["kernels_paid"]), refill, "at the kernels' price")


func test_m01_each_hopper_feeds_its_own_four_kettles() -> void:
	var f := _kitchen()
	for i in 5:
		f.execute({"type": "build", "machine": "M07", "slot": i})
	f.execute({"type": "build", "machine": "M01", "slot": 5})
	for m: Dictionary in f.machines:
		if String(m["type"]) == "cooker":
			m["kernels"] = 0
	f.advance(10000)
	var kettles: Array = f.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "cooker")
	assert_true(int(kettles[0]["kernels"]) + int(kettles[1]["kernels"]) + int(kettles[2]["kernels"]) + int(kettles[3]["kernels"]) > 0, "one hopper feeds the first four kettles")
	assert_eq(int(kettles[4]["kernels"]), 0, "not the fifth")
	f.execute({"type": "build", "machine": "M01", "slot": 6})
	f.advance(10000)
	assert_true(int(kettles[4]["kernels"]) > 0 or String(kettles[4]["state"]) == "run", "a second hopper feeds the fifth")


func test_m02_the_oil_doser_pays_for_oil_and_raises_quality() -> void:
	var a := _kitchen(5)
	a.execute({"type": "build", "machine": "M07"})
	a.machines[0]["kernels"] = 1000
	var plain := _auto_lots(a, 30000)
	var b := _kitchen(5)
	b.execute({"type": "build", "machine": "M07"})
	b.machines[0]["kernels"] = 1000
	b.execute({"type": "build", "machine": "M02"})
	var oiled := _auto_lots(b, 30000)
	assert_eq(oiled.size(), plain.size(), "the same lots")
	assert_eq(int(b.stats["oil_paid"]), oiled.size(), "a coin of oil each")
	# Quality lives on the lot: look at one that left the kettle.
	var c := _kitchen(5)
	c.execute({"type": "build", "machine": "M07"})
	c.machines[0]["kernels"] = 1000
	c.execute({"type": "build", "machine": "M02"})
	c.advance(6100)
	var held: Dictionary = c.machines[0]["held"]
	if held.is_empty() and not c.lift.is_empty():
		held = c.lift[0]["lot"]
	assert_true(int(held["quality"]) in [90, 70, 30], "an oiled lot is 10 better than its grade (%d)" % int(held["quality"]))


func test_m03_the_heat_controller_stops_burnt_lots() -> void:
	var a := _kitchen(11)
	a.execute({"type": "build", "machine": "M07"})
	a.machines[0]["kernels"] = 1000
	var lots := _auto_lots(a, 300000)
	var burnt := lots.filter(func(l: Dictionary) -> bool: return String(l["grade"]) == "burnt").size()
	assert_true(burnt > 0, "an auto kettle burns some lots (%d of %d)" % [burnt, lots.size()])
	var b := _kitchen(11)
	b.execute({"type": "build", "machine": "M07"})
	b.machines[0]["kernels"] = 1000
	b.execute({"type": "build", "machine": "M03"})
	var held := _auto_lots(b, 300000)
	assert_eq(held.filter(func(l: Dictionary) -> bool: return String(l["grade"]) == "burnt").size(), 0, "with the controller none burn")
	assert_true(int(b.stats["upkeep_paid"]) > int(a.stats["upkeep_paid"]), "and it paid its upkeep while the kettle cooked")


func test_m04_the_motor_adds_a_portion_to_its_kettle_only() -> void:
	var f := _kitchen(13)
	f.execute({"type": "build", "machine": "M07", "slot": 0})
	f.execute({"type": "build", "machine": "M07", "slot": 1})
	for m: Dictionary in f.machines:
		m["kernels"] = 1000
	f.execute({"type": "build", "machine": "M04"})
	var lots := _auto_lots(f, 60000)
	var first: int = f.machines[0]["id"]
	var with_motor := lots.filter(func(l: Dictionary) -> bool: return int(l["machine"]) == first)
	var without := lots.filter(func(l: Dictionary) -> bool: return int(l["machine"]) != first)
	var avg := func(ls: Array) -> float: return ls.reduce(func(a: float, l: Dictionary) -> float: return a + float(l["portions"]), 0.0) / maxf(1.0, ls.size())
	assert_true(float(avg.call(with_motor)) >= float(avg.call(without)) + 0.8, "the stirred kettle's lots are bigger (%.2f vs %.2f)" % [avg.call(with_motor), avg.call(without)])


func test_m05_the_detector_stops_late_lots_and_shortens_its_kettle() -> void:
	var a := _kitchen(17)
	a.execute({"type": "build", "machine": "M07"})
	a.machines[0]["kernels"] = 1000
	var plain := _auto_lots(a, 120000)
	var b := _kitchen(17)
	b.execute({"type": "build", "machine": "M07"})
	b.machines[0]["kernels"] = 1000
	b.execute({"type": "build", "machine": "M05"})
	var seen := _auto_lots(b, 120000)
	assert_true(plain.filter(func(l: Dictionary) -> bool: return String(l["grade"]) == "late").size() > 0, "without it, some late lots")
	assert_eq(seen.filter(func(l: Dictionary) -> bool: return String(l["grade"]) == "late").size(), 0, "with it, none")
	assert_true(seen.size() > plain.size(), "and its kettle cycles faster (%d vs %d lots)" % [seen.size(), plain.size()])


func test_m06_the_ejector_shortens_the_lift_for_every_lot() -> void:
	var f := _kitchen()
	var base := int(f.lift_ms())
	f.execute({"type": "build", "machine": "M06"})
	assert_eq(int(f.lift_ms()), base - 600, "on: the lift is 0.6 s shorter")
	_pop(f)
	f.advance(100)
	assert_true(not f.lift.is_empty(), "the hand's lot is in the lift")
	assert_true(int(f.lift[0]["left_ms"]) <= base - 600 + 100, "a shorter ride (%d vs %d)" % [int(f.lift[0]["left_ms"]), base])
	f.execute({"type": "pause_machine", "id": f.machines[0]["id"], "paused": true})
	assert_eq(int(f.lift_ms()), base, "paused, it does nothing")


func test_m08_the_fan_shortens_the_hand_cooldown_and_the_kettles_cycle() -> void:
	var f := _kitchen()
	_pop(f)
	var plain := int(f.cooldown_left)
	f.advance(2000)
	f.execute({"type": "build", "machine": "M08"})
	_pop(f)
	assert_true(int(f.cooldown_left) < plain, "the hand's kettle cools sooner (%d vs %d)" % [f.cooldown_left, plain])
	f.execute({"type": "build", "machine": "M07"})
	var k: Dictionary = f.cookers[0]
	assert_eq(int(f._cooker_cycle(k)), 6000 - 300, "an auto kettle's cycle 0.3 s shorter")


func test_a_kettle_saved_before_kernels_loads_with_a_full_buffer() -> void:
	var f := _kitchen()
	f.execute({"type": "build", "machine": "M07"})
	var d: Dictionary = JSON.parse_string(JSON.stringify(f.to_save()))
	for m: Dictionary in d["machines"]:
		m.erase("kernels")   # what 0.26 / 0.27 wrote
	var g: PopRules = Factory.new()
	assert_true(bool(g.from_save(d)), "an old save loads")
	assert_eq(int(g.machines[0]["kernels"]), int(g.economy.table("factory")["auto_cooker"]["kernel_buffer"]), "its kettle has a full buffer of kernels")
	g.advance(7000)
	assert_true(String(g.machines[0]["state"]) != "starved", "and keeps cooking")


func test_a_fully_equipped_auto_kettle_still_loses_to_a_skilled_hand_per_attempt() -> void:
	# Issue 28.3: with every basic device helping, an auto lot is a good lot -- never a
	# perfect one, and smaller than a perfect pop of the hand's kettle at the same level.
	var f := _kitchen(31)
	f.execute({"type": "build", "machine": "M07", "slot": 0})
	for id in ["M01", "M02", "M03", "M04", "M05", "M06", "M08"]:
		f.execute({"type": "build", "machine": id})
	f.money = 5000
	var lots := _auto_lots(f, 180000)
	assert_true(lots.size() >= 20, "the equipped kettle cooked (%d lots)" % lots.size())
	var best := 0
	var total := 0.0
	for l: Dictionary in lots:
		assert_true(String(l["grade"]) != "perfect", "no auto lot is perfect without the hand's assist")
		best = maxi(best, int(l["portions"]))
		total += float(l["portions"])
	var hand: Dictionary = f.hand_attempt(int(f.level), "perfect")
	assert_true(float(best) < float(hand["portions"]), "its biggest lot (%d) is smaller than a perfect hand's (%.1f)" % [best, hand["portions"]])
	assert_true(total / lots.size() < float(hand["portions"]), "and so is its average")


func test_eight_devices_at_once_any_cut_of_time_and_a_saved_layout() -> void:
	var a := _kitchen(21)
	var b := _kitchen(21)
	for f: PopRules in [a, b]:
		f.execute({"type": "build", "machine": "M07", "slot": 0})
		for id in ["M01", "M02", "M03", "M04", "M05", "M06", "M08"]:
			assert_true(bool(f.execute({"type": "build", "machine": id})["ok"]), "%s built" % id)
		f.money = 5000
	assert_eq(a.machines.size(), 8, "eight devices in the kitchen")
	a.advance(240000)
	for i in 2400:
		b.advance(100)
	assert_eq(a.stats, b.stats, "one long advance = many short ones, with eight devices")
	_check_conservation(a, "eight devices")
	assert_true(int(a.stats["kernels_paid"]) > 0 and int(a.stats["oil_paid"]) > 0 and int(a.stats["upkeep_paid"]) > 0, "kernels, oil and upkeep all paid")
	var c: PopRules = Factory.new()
	assert_true(bool(c.from_save(JSON.parse_string(JSON.stringify(a.to_save())))), "the layout saves")
	assert_eq(c.machines.map(func(m: Dictionary) -> String: return String(m["type"])), a.machines.map(func(m: Dictionary) -> String: return String(m["type"])), "the same devices in the same order")
	c.advance(60000)
	a.advance(60000)
	assert_eq(c.stats, a.stats, "and the same factory after a minute")
	# A device bought late (delayed activation) starts helping from then on.
	var d := _kitchen(23)
	d.execute({"type": "build", "machine": "M07"})
	d.machines[0]["kernels"] = 1000
	var early := _auto_lots(d, 60000).filter(func(l: Dictionary) -> bool: return String(l["grade"]) == "burnt").size()
	d.execute({"type": "build", "machine": "M03"})
	var later := _auto_lots(d, 60000).filter(func(l: Dictionary) -> bool: return String(l["grade"]) == "burnt").size()
	assert_eq(later, 0, "after the controller arrives no lot burns (before: %d)" % early)
	# Not enough money: the hopper stops buying and the kettle starves; nothing is owed.
	var e := _kitchen(25)
	e.execute({"type": "build", "machine": "M07"})
	e.execute({"type": "build", "machine": "M01"})
	e.money = 2
	_auto_lots(e, 90000)
	assert_true(int(e.money) >= 0, "never a debt")
	assert_true(String(e.machines[0]["state"]) in ["starved", "unpaid"], "the kettle waits for kernels it cannot buy")
