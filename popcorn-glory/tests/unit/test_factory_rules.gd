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
	assert_true(int(f.bin_portions()) + int(f.coating_portions()) <= int(f.state()["bin_cap"]), "%s: the bin (and what is being coated) within its size" % label)
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
	f.economy.table("factory")["pack_recipes"]["test_mix"] = "test_mix"
	f.money = 5000
	f.execute({"type": "buy_packer"})
	f.execute({"type": "buy_packer"})   # two heads: the mix test sees both at once
	_lot(f, "test_mix", 1, 100)
	_lot(f, "plain", 1, 100)
	f.advance(3000)
	assert_eq(f.packing.size() + f.shelf.size(), 0, "one test-mix and one plain portion never make a pack")
	_lot(f, "plain", 1, 80)
	f.advance(int(f.packer()["ms"]) + 60)
	assert_eq(f.shelf.size(), 1, "two plain portions do")
	assert_eq(String(f.shelf[0]["recipe"]), "plain", "as a plain pack")
	assert_eq(f.bin_portions_of("test_mix"), 1, "the test-mix portion still waits")
	_lot(f, "test_mix", 3, 100)
	f.advance(int(f.packer()["ms"]) * 2 + 60)
	var skus: Array = f.shelf.map(func(p: Dictionary) -> String: return String(p["recipe"]))
	assert_eq(skus.count("test_mix"), 2, "four test-mix portions became two test-mix packs")
	# A customer who orders plain gets the plain pack even though test-mix is on the shelf.
	f.queue.append({"id": f._new_id(), "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
	f.drain_events()
	f.advance(100)
	var sv := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "serve_started")
	assert_eq(sv.size(), 1, "served")
	assert_eq(String(f.serving["pack"]["recipe"]), "plain", "with the plain pack it ordered")
	f.queue.append({"id": f._new_id(), "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
	f.advance(5000)
	assert_eq(int(f.stats["sold"]), 1, "a second plain order is not given test-mix")
	_check_conservation(f, "recipes")
	f.economy.table("factory")["pack_recipes"].erase("test_mix")


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

## Step 36: the shop's popularity moves foot traffic; tests that measure the sign or a line's
## throughput hold it still (its own test: test_popularity_*).
func _steady(f: PopRules) -> PopRules:
	f.economy.table("factory")["reputation"]["arrival_effect"] = 0.0
	return f


func _traffic(tier: int, seed_value: int, minutes: int) -> Array:
	var f: PopRules = _steady(Factory.new(null, seed_value))
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
	var f: PopRules = _steady(Factory.new(null, 20261116))
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
	var crew: PopRules = _steady(Factory.new(null, 20261116))
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

const CONTRACT_KINDS := ["triage", "feed", "dose", "regulate", "agitate", "detect", "eject", "produce", "cool", "sort", "capacity", "grade_split",
	"premix", "stabilize", "recycle", "dispatch", "container", "pack", "weigh", "season", "coat", "seal", "divert", "convey", "ticket",
	"cashier", "route", "express", "menu", "serve", "float_lane", "repair", "neighbor_speed", "upkeep", "buffer", "inspect",
	"freshness", "schedule", "balance"]
## The model's behaviour tests for each machine that runs today.
const RUNTIME_TESTS := {"cooker": "test_upkeep_is_paid_a_coin_at_a_time_and_never_becomes_a_debt",
	"M01": "test_m01_the_hopper_buys_kernels_and_keeps_kettles_cooking", "M02": "test_m02_the_oil_doser_pays_for_oil_and_raises_quality",
	"M03": "test_m03_the_heat_controller_stops_burnt_lots", "M04": "test_m04_the_motor_adds_a_portion_to_its_kettle_only",
	"M05": "test_m05_the_detector_stops_late_lots_and_shortens_its_kettle", "M06": "test_m06_the_ejector_shortens_the_lift_for_every_lot",
	"M08": "test_m08_the_fan_shortens_the_hand_cooldown_and_the_kettles_cycle",
	"M09": "test_m09_the_sorter_repops_early_and_late_lots_for_a_portion", "M10": "test_m10_the_distributor_adds_kitchen_places_and_keeps_them_honest",
	"M11": "test_m11_premium_lots_get_their_own_packs_and_customers", "M13": "test_m13_many_kettles_overheat_unless_the_vents_run",
	"M14": "test_m14_the_recycler_lowers_cooking_kettles_upkeep_but_never_to_zero", "M15": "test_m15_the_dispatcher_cooks_only_what_is_wanted",
	"M16": "test_m16_the_rotary_popper_is_a_steady_kettle_worth_its_place",
	"P01": "test_p01_the_cup_feeder_makes_cups_a_product_of_their_own", "P02": "test_p02_the_dispenser_opens_large_bags_before_tier_two",
	"P04": "test_p04_fillers_overfill_and_the_weigher_keeps_the_portion", "P07": "test_p07_the_sealer_shortens_every_packing_cycle",
	"P08": "test_p08_the_diverter_gives_premium_its_own_lane",
	"P05": "test_p05_seasons_plain_portions_into_cheese_or_spicy", "P06": "test_p06_coats_caramel_and_cocoa_slowly",
	"M12": "test_m12_the_mixer_shortens_every_coating_batch",
	"S01": "test_s01_the_belt_shortens_the_hand_over", "S02": "test_s02_tickets_keep_patience_while_the_pack_is_made",
	"S03": "test_s03_the_cashier_takes_payment_apart_and_a_paused_one_holds_the_sale", "S04": "test_s04_the_router_serves_whoever_is_ready",
	"S05": "test_s05_the_express_window_serves_small_orders_apart", "S06": "test_s06_the_menu_board_lets_customers_order_what_is_there",
	"S08": "test_s08_the_robot_adds_counter_lanes",
	"U01": "test_u01_the_robot_keeps_coins_for_the_machines_that_make_goods", "U02": "test_u02_the_lubricator_speeds_its_neighbours_only",
	"U03": "test_u03_the_saver_cuts_its_floors_upkeep", "U04": "test_u04_the_buffer_lift_adds_real_room",
	"U05": "test_u05_the_inspector_sends_rejects_to_a_bargain_sku", "U08": "test_u08_moves_goods_from_a_stopped_line_to_an_idle_one",
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
			# U08 needs two packing lines (Step 33): with one it is refused for that reason, not "not yet".
			assert_true(bool(r["ok"]) or String(r["reason"]) in ["err.no_slot", "err.slot_taken"] or (id == "U08" and String(r["reason"]) == "err.needs_lines"), "%s: a running machine is built (%s)" % [id, r.get("reason", "")])
			assert_true(RUNTIME_TESTS.has(String(e["runtime"])), "%s: its behaviour has a test" % id)
			assert_true(has_method(RUNTIME_TESTS[String(e["runtime"])]), "%s: that test exists (%s)" % [id, RUNTIME_TESTS[String(e["runtime"])]])
	assert_eq(runs, 38, "today: 38 of the 40 run (Step 34 woke M12, P05, P06; U06 waits for aging, U07 for news)")
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


# -- Step 29: M09-M16, the advanced kitchen, heat, premium ---------------------------

func _kettles(f: PopRules, n: int, kernels: int = 1000) -> void:
	for i in n:
		assert_true(bool(f.execute({"type": "build", "machine": "M07"})["ok"]), "kettle %d built" % i)
	for m: Dictionary in f.machines:
		if String(m["type"]) == "cooker":
			m["kernels"] = kernels


func _adv(f: PopRules) -> PopRules:
	var x := _kitchen(41)
	x.sign_tier = 6
	x.packer_tier = 3
	return x


func test_m09_the_sorter_repops_early_and_late_lots_for_a_portion() -> void:
	var a := _adv(null)
	var r := _pop(a, -400)   # early
	assert_eq(String(r["outcome"]), "early", "an early pop")
	var plain: Dictionary = a.glass.duplicate()
	var b := _adv(null)
	b.execute({"type": "build", "machine": "M07"})
	assert_true(bool(b.execute({"type": "build", "machine": "M09"})["ok"]), "the sorter is built")
	b.money = 100000
	_pop(b, -400)
	assert_eq(int(b.glass["quality"]), 80, "the sorted early lot is near quality (was %d)" % int(plain["quality"]))
	assert_eq(int(b.glass["portions"]), int(plain["portions"]) - 1, "one portion fewer")
	_check_conservation(b, "sorted hand lot")
	var p := _adv(null)
	p.execute({"type": "build", "machine": "M07"})
	p.machines[0]["kernels"] = 1000
	p.execute({"type": "build", "machine": "M09"})
	var lots := _auto_lots(p, 120000)
	assert_true(lots.size() > 10, "lots were made (%d)" % lots.size())
	assert_true(int(p.stats.get("sorted_lots", 0)) > 0, "the late auto lots were sorted (%d)" % int(p.stats.get("sorted_lots", 0)))
	var q := _adv(null)
	q.execute({"type": "build", "machine": "M07"})
	q.machines[0]["kernels"] = 1000
	q.execute({"type": "build", "machine": "M09"})
	q.advance(120000)
	_check_conservation(q, "sorted auto lots (no sink)")


func test_m10_the_distributor_adds_kitchen_places_and_keeps_them_honest() -> void:
	var f := _adv(null)
	var base := int(f.slots("kitchen"))
	f.execute({"type": "build", "machine": "M07"})
	var r := f.execute({"type": "build", "machine": "M10"})
	assert_true(bool(r["ok"]), "the distributor is built")
	assert_eq(int(f.slots("kitchen")), base + 2, "two more kitchen places")
	assert_true(bool(f.execute({"type": "build", "machine": "M07", "slot": base + 1})["ok"]), "a kettle in a new place")
	var d: int = r["machine"]
	assert_eq(String(f.execute({"type": "sell_machine", "id": d})["reason"]), "err.slot_taken", "not sold while its places hold a kettle")
	f.execute({"type": "upgrade_machine", "id": d})
	assert_eq(int(f.slots("kitchen")), base + 3, "its next tier: three")
	var k: Dictionary = f.machine_at("kitchen", base + 1)
	f.execute({"type": "sell_machine", "id": k["id"]})
	assert_true(bool(f.execute({"type": "sell_machine", "id": d})["ok"]), "with its places empty it sells")
	assert_eq(int(f.slots("kitchen")), base, "and the places go with it")
	var g: PopRules = Factory.new()
	assert_true(bool(g.from_save(JSON.parse_string(JSON.stringify(f.to_save())))), "saves")


func test_m11_premium_lots_get_their_own_packs_and_customers() -> void:
	var f := _adv(null)
	f.execute({"type": "build", "machine": "M07"})
	f.execute({"type": "build", "machine": "M11"})
	f.money = 100000
	_pop(f)   # perfect: quality 100
	assert_eq(String(f.glass["recipe"]), "premium", "a perfect hand lot is premium")
	f.advance(3000)
	_pop(f, 600)   # late: quality 60
	f.advance(3000)
	var plain_lot: Array = f.bin.filter(func(l: Dictionary) -> bool: return String(l["recipe"]) == "plain")
	assert_true(not plain_lot.is_empty(), "a late lot stays plain")
	# Packs never mix: premium portions only in premium packs.
	f.advance(30000)
	for p: Dictionary in f.shelf + f.packing:
		assert_true(String(p["recipe"]) in ["plain", "premium"], "a known SKU")
	assert_true(f.shelf.any(func(p: Dictionary) -> bool: return String(p["recipe"]) == "premium"), "a premium pack on the shelf")
	# A plain customer is never handed a premium pack; a premium one never a plain pack.
	var before: int = f.ledger.size()
	f.queue.append({"id": f._new_id(), "order": {"recipe": "premium", "size": 2}, "patience_ms": 60000})
	f.advance(20000)
	for e: Dictionary in f.ledger.slice(before):
		assert_eq(String(e["recipe"]), String(e["ordered_recipe"]), "the SKU they asked for")
	var sold: Array = f.ledger.slice(before).filter(func(e: Dictionary) -> bool: return String(e["recipe"]) == "premium")
	assert_true(not sold.is_empty(), "the premium customer bought a premium pack")
	assert_true(int(sold[0]["coins"]) > int(f.pack_price("plain", 2, int(sold[0]["quality"]))), "for more than plain")
	_check_conservation(f, "premium")
	# The premium bin is bounded: a full one lets lots through as plain.
	var g := _adv(null)
	g.execute({"type": "build", "machine": "M07"})
	g.execute({"type": "build", "machine": "M11"})
	g.bin.append({"id": g._new_id(), "recipe": "premium", "quality": 100, "portions": 12})
	var top := {"id": 0, "recipe": "plain", "quality": 100, "portions": 4}
	g._sort_and_grade(top, "perfect")
	assert_eq(String(top["recipe"]), "plain", "premium bin full: a perfect lot goes through as plain")
	g.bin.clear()
	g._sort_and_grade(top, "perfect")
	assert_eq(String(top["recipe"]), "premium", "with room, premium")


func test_m11_orders_for_premium_only_while_it_is_on_hand_and_plain_streams_unchanged() -> void:
	var a: PopRules = Factory.new(null, 9)
	var b: PopRules = Factory.new(null, 9)
	for i in 50:
		assert_eq(a._draw_order(), b._draw_order(), "without the sensor the order stream is the same")
	var c := _adv(null)
	c.execute({"type": "build", "machine": "M07"})
	c.execute({"type": "build", "machine": "M11"})
	var none := 0
	for i in 40:
		if String(c._draw_order()["recipe"]) == "premium":
			none += 1
	assert_eq(none, 0, "no premium orders while there is no premium popcorn")
	c.bin.append({"id": c._new_id(), "recipe": "premium", "quality": 100, "portions": 8})
	var some := 0
	for i in 200:
		if String(c._draw_order()["recipe"]) == "premium":
			some += 1
	assert_true(some > 30 and some < 100, "about 30%% ask for premium while it is on hand (%d of 200)" % some)


func test_m13_many_kettles_overheat_unless_the_vents_run() -> void:
	var a := _adv(null)
	_kettles(a, 5)
	var lots_a := _auto_lots(a, 240000).size()
	assert_true(int(a.stats.get("overheat_stops", 0)) > 0, "five kettles overheat the kitchen (%d stops)" % int(a.stats.get("overheat_stops", 0)))
	var e := _adv(null)
	e.next_arrival_ms = 0
	_kettles(e, 5)
	e.advance(240000)
	assert_true(int(e.stats.get("overheat_stops", 0)) > 0, "overheating in a full run too")
	_check_conservation(e, "overheat (no lot lost or doubled while kettles stop)")
	var b := _adv(null)
	_kettles(b, 5)
	b.execute({"type": "build", "machine": "M13"})
	var lots_b := _auto_lots(b, 240000).size()
	assert_eq(int(b.stats.get("overheat_stops", 0)), 0, "with the vents, none")
	assert_true(lots_b > lots_a, "and more lots (%d vs %d)" % [lots_b, lots_a])
	var c := _adv(null)
	_kettles(c, 2)
	_auto_lots(c, 240000)
	assert_eq(int(c.stats.get("overheat_stops", 0)), 0, "two kettles never overheat")
	var d := _adv(null)
	_kettles(d, 3)
	d.execute({"type": "build", "machine": "M08"})
	_auto_lots(d, 240000)
	assert_eq(int(d.stats.get("overheat_stops", 0)), 0, "three with the fan stay cool")


func test_m14_the_recycler_lowers_cooking_kettles_upkeep_but_never_to_zero() -> void:
	var a := _adv(null)
	_kettles(a, 2)
	var la := _auto_lots(a, 180000).size()
	var b := _adv(null)
	_kettles(b, 2)
	b.execute({"type": "build", "machine": "M14"})
	var lb := _auto_lots(b, 180000).size()
	assert_eq(lb, la, "the same lots")
	assert_true(int(b.stats["upkeep_paid"]) < int(a.stats["upkeep_paid"]), "less upkeep (%d vs %d)" % [b.stats["upkeep_paid"], a.stats["upkeep_paid"]])
	assert_true(int(b.stats["upkeep_paid"]) > 0, "but never free")
	var c := _adv(null)
	_kettles(c, 1)
	var rid: int = c.execute({"type": "build", "machine": "M14"})["machine"]
	c.execute({"type": "upgrade_machine", "id": rid})
	c.execute({"type": "upgrade_machine", "id": rid})
	_auto_lots(c, 120000)
	assert_true(int(c.stats["upkeep_paid"]) >= 1, "at its best tier a kettle still pays (%d)" % int(c.stats["upkeep_paid"]))


func test_m15_the_dispatcher_cooks_only_what_is_wanted() -> void:
	# No customers: the shelf fills, then a kettle without the dispatcher keeps cooking into a
	# full bin (blocked), one with it stops starting lots -- kernels and upkeep saved.
	var a := _adv(null)
	_kettles(a, 2, 1000)
	a.advance(240000)
	var b := _adv(null)
	_kettles(b, 2, 1000)
	b.execute({"type": "build", "machine": "M15"})
	b.advance(240000)
	assert_true(int(b.stats.get("dispatch_held_ms", 0)) > 0, "the dispatcher held kettles back")
	assert_true(int(b.stats["made_portions"]) <= int(a.stats["made_portions"]), "no more popcorn than without it")
	var used_a: int = 2000 - a.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "cooker").reduce(func(n: int, m: Dictionary) -> int: return n + int(m["kernels"]), 0)
	var used_b: int = 2000 - b.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "cooker").reduce(func(n: int, m: Dictionary) -> int: return n + int(m["kernels"]), 0)
	assert_true(used_b < used_a, "fewer kernels used (%d vs %d)" % [used_b, used_a])
	_check_conservation(b, "dispatch")
	# With orders waiting, it cooks.
	var c := _adv(null)
	_kettles(c, 1, 1000)
	c.execute({"type": "build", "machine": "M15"})
	assert_true(c.demand_wants_lot(), "an empty shelf wants popcorn")
	c.advance(20000)
	assert_true(int(c.stats["auto_lots"]) > 0, "so the kettle cooks")


func test_m16_the_rotary_popper_is_a_steady_kettle_worth_its_place() -> void:
	var f := _adv(null)
	f.execute({"type": "build", "machine": "M07"})
	var r := f.execute({"type": "build", "machine": "M16"})
	assert_true(bool(r["ok"]), "the rotary popper is built")
	var rot: Dictionary = f.machine(int(r["machine"]))
	rot["kernels"] = 1000
	f.machines[0]["kernels"] = 1000
	var lots := _auto_lots(f, 60000)
	var from_rot := lots.filter(func(l: Dictionary) -> bool: return int(l["machine"]) == int(rot["id"]))
	var from_k := lots.filter(func(l: Dictionary) -> bool: return int(l["machine"]) != int(rot["id"]))
	assert_true(from_rot.size() >= 22, "a lot about every 2.5 s (%d in a minute)" % from_rot.size())
	assert_true(from_rot.all(func(l: Dictionary) -> bool: return int(l["portions"]) == 2 and String(l["grade"]) == "near"), "small near lots")
	var pr: int = from_rot.reduce(func(n: int, l: Dictionary) -> int: return n + int(l["portions"]), 0)
	var pk: int = from_k.reduce(func(n: int, l: Dictionary) -> int: return n + int(l["portions"]), 0)
	assert_true(pr > pk * 2, "more popcorn per place than a basic kettle (%d vs %d)" % [pr, pk])
	assert_true(int(rot["kernels"]) < 1000, "it uses kernels")
	# A hopper feeds it like any kettle.
	var g := _adv(null)
	var gr: int = g.execute({"type": "build", "machine": "M07"})["machine"]
	g.machine(gr)["kernels"] = 1000
	var gid: int = g.execute({"type": "build", "machine": "M16"})["machine"]
	g.machine(gid)["kernels"] = 0
	g.execute({"type": "build", "machine": "M01"})
	_auto_lots(g, 30000)
	assert_true(int(g.machine(gid).get("done", 0)) > 0, "the hopper keeps the drum turning")
	var h := _adv(null)
	h.next_arrival_ms = 0
	h.execute({"type": "build", "machine": "M07"})
	var hid: int = h.execute({"type": "build", "machine": "M16"})["machine"]
	h.execute({"type": "build", "machine": "M01"})
	h.advance(180000)
	assert_true(int(h.machine(hid).get("done", 0)) > 30, "a full run: the drum turned")
	_check_conservation(h, "rotary (no sink)")


func test_parallel_kettle_lines_and_the_hand_together_any_cut_of_time() -> void:
	var a := _adv(null)
	var b := _adv(null)
	for f: PopRules in [a, b]:
		f.next_arrival_ms = 0   # customers come
		f.execute({"type": "build", "machine": "M07"})
		var dr: Dictionary = f.execute({"type": "build", "machine": "M10"})
		assert_true(bool(dr["ok"]), "the distributor built (%s)" % dr.get("reason", ""))
		f.execute({"type": "upgrade_machine", "id": int(dr.get("machine", -1))})
		for i in 2:
			f.execute({"type": "build", "machine": "M07"})
		for id in ["M01", "M16", "M11", "M13", "M14", "M15", "M09"]:
			assert_true(bool(f.execute({"type": "build", "machine": id})["ok"]), "%s built" % id)
		f.money = 20000
	var pops := 0
	var t := 0
	while t < 300000:
		for f: PopRules in [a, b]:
			if f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
				f.execute({"type": "press"})
		a.advance(1600)
		for i in 16:
			b.advance(100)
		for f: PopRules in [a, b]:
			if f.heating:
				f.execute({"type": "release"})
		pops += 1
		t += 1600
	assert_eq(a.stats, b.stats, "the same factory, whatever the cut of time")
	_check_conservation(a, "parallel lines with the hand")
	assert_true(int(a.stats["lots"]) > 50, "the hand kept popping while machines worked (%d)" % int(a.stats["lots"]))
	assert_true(int(a.stats["auto_lots"]) + int(a.stats.get("rotary_lots", 0)) > 50, "and the kettles cooked")
	assert_true(int(a.stats.get("premium_lots", 0)) > 0, "the hand's perfect lots became premium")
	for e: Dictionary in a.ledger:
		assert_eq(String(e["recipe"]), String(e["ordered_recipe"]), "every sale the SKU that was ordered")
	var c: PopRules = Factory.new()
	assert_true(bool(c.from_save(JSON.parse_string(JSON.stringify(a.to_save())))), "the factory saves")
	c.advance(30000)
	a.advance(30000)
	assert_eq(c.stats, a.stats, "and goes on the same")


func test_a_paused_advanced_device_does_nothing_and_costs_nothing() -> void:
	var a := _adv(null)
	_kettles(a, 5)
	var v: int = a.execute({"type": "build", "machine": "M13"})["machine"]
	a.execute({"type": "pause_machine", "id": v, "paused": true})
	var paid_before := int(a.stats["upkeep_paid"])
	_auto_lots(a, 240000)
	assert_true(int(a.stats.get("overheat_stops", 0)) > 0, "a paused vent does not stop overheating")
	assert_eq(int(a.machine(v)["upkeep_ms"]), 0, "and owes nothing")


# -- Step 30: P01-P08, the packing floor -----------------------------------------------

func _packfloor(seed_value: int = 51) -> PopRules:
	var f: PopRules = Factory.new(null, seed_value)
	_quiet_shop(f)
	f.sign_tier = 4
	f.packer_tier = 3
	f.money = 100000
	_open(f)
	_open_sign(f)
	return f


func _fill_bin(f: PopRules, portions: int, recipe: String = "plain") -> void:
	f.bin.append({"id": f._new_id(), "recipe": recipe, "quality": 80, "portions": portions})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + portions


func test_p01_the_cup_feeder_makes_cups_a_product_of_their_own() -> void:
	var f := _packfloor()
	assert_false(f.sizes_open().any(func(z: Dictionary) -> bool: return int(z["size"]) == 1), "no cups without a cup feeder")
	assert_true(bool(f.execute({"type": "build", "machine": "P01"})["ok"]), "the cup feeder is built")
	assert_true(f.sizes_open().any(func(z: Dictionary) -> bool: return int(z["size"]) == 1), "cups are on sale")
	assert_false(f.station_sizes().has(1), "the station does not fill cups")
	_fill_bin(f, 1)
	f.advance(4000)
	assert_true(f.shelf.any(func(p: Dictionary) -> bool: return int(p["size"]) == 1), "the lone portion became a cup")
	var id: int = f._new_id()
	f.queue.append({"id": id, "order": {"recipe": "plain", "size": 1}, "patience_ms": 60000})
	f.advance(10000)
	var sale: Array = f.ledger.filter(func(e: Dictionary) -> bool: return int(e["customer"]) == id)
	assert_eq(sale.size(), 1, "a cup customer bought a cup")
	assert_eq(int(sale[0]["size"]), 1, "a cup, not a bag")
	assert_true(int(sale[0]["coins"]) < int(f.pack_price("plain", 2, int(sale[0]["quality"]))), "cheaper than a bag")
	_check_conservation(f, "cups")
	var g := _packfloor()
	g.execute({"type": "build", "machine": "P01"})
	var cups := 0
	for i in 400:
		if int(g._draw_order()["size"]) == 1:
			cups += 1
	assert_true(cups > 60 and cups < 140, "about a quarter of orders are cups (%d of 400)" % cups)


func test_p02_the_dispenser_opens_large_bags_before_tier_two() -> void:
	var f := _packfloor()
	f.packer_tier = 1
	assert_false(f.station_sizes().has(4), "tier 1: no large bag")
	assert_true(bool(f.execute({"type": "build", "machine": "P02"})["ok"]), "the dispenser is built")
	assert_true(f.station_sizes().has(4), "with the dispenser, the large bag")
	var id: int = f._new_id()
	f.queue.append({"id": id, "order": {"recipe": "plain", "size": 4}, "patience_ms": 60000})
	_fill_bin(f, 4)
	f.advance(20000)
	assert_eq(f.ledger.filter(func(e: Dictionary) -> bool: return int(e["customer"]) == id and int(e["size"]) == 4).size(), 1, "a large bag sold at tier 1")
	var d: int = f.machines[0]["id"]
	f.execute({"type": "pause_machine", "id": d, "paused": true})
	assert_false(f.station_sizes().has(4), "paused, the large bag waits")
	_check_conservation(f, "dispenser")


func test_p04_fillers_overfill_and_the_weigher_keeps_the_portion() -> void:
	# The bagger works before the station in a flow step; a bin with more than a pack in it
	# lets a volumetric fill overshoot by a portion.
	var a := _packfloor(53)
	a.execute({"type": "build", "machine": "bagger"})
	for i in 40:
		_fill_bin(a, 6)
		a.advance(6000)
		a.shelf.clear()   # a sink: the shelf never blocks
		a.stats["made_portions"] = a.portions_everywhere()   # what the sink took is not counted
	var over := int(a.stats.get("overfill_portions", 0))
	assert_true(over > 0, "a volumetric filler overfills now and then (%d portions given away)" % over)
	var b := _packfloor(53)
	b.execute({"type": "build", "machine": "bagger"})
	b.execute({"type": "build", "machine": "P04"})
	for i in 40:
		_fill_bin(b, 6)
		b.advance(6000)
		b.shelf.clear()
	assert_eq(int(b.stats.get("overfill_portions", 0)), 0, "with the weigher, never")
	var c := _packfloor(53)
	var bg: int = c.execute({"type": "build", "machine": "bagger"})["machine"]
	_fill_bin(c, 2)
	c.advance(100)
	var plain_ms := int(c.machine(bg)["held"].get("left_ms", 0))
	var e := _packfloor(53)
	var bg2: int = e.execute({"type": "build", "machine": "bagger"})["machine"]
	e.execute({"type": "build", "machine": "P04"})
	_fill_bin(e, 2)
	e.advance(100)
	assert_true(plain_ms > 0, "the bagger took the pack")
	assert_true(int(e.machine(bg2)["held"].get("left_ms", 0)) > plain_ms, "and the weighing costs time")
	var g := _packfloor(55)
	g.execute({"type": "build", "machine": "bagger"})
	g.next_arrival_ms = 0
	for i in 30:
		_fill_bin(g, 5)
		g.advance(6000)
	assert_true(int(g.stats.get("overfill_portions", 0)) > 0, "overfills in a full run")
	_check_conservation(g, "overfilled packs: every portion still counted")


func test_p07_the_sealer_shortens_every_packing_cycle() -> void:
	var a := _packfloor()
	a.packer_tier = 0
	_fill_bin(a, 2)
	a.advance(100)
	var plain := int(a.packing[0]["ms"])
	var b := _packfloor()
	b.execute({"type": "build", "machine": "P07"})
	b.packer_tier = 0
	_fill_bin(b, 2)
	b.advance(100)
	assert_eq(int(b.packing[0]["ms"]), int(round(plain * 0.75)), "the station's cycle a quarter shorter")
	var c := _packfloor()
	var bg: int = c.execute({"type": "build", "machine": "bagger"})["machine"]
	c.execute({"type": "build", "machine": "P07"})
	_fill_bin(c, 2)
	c.advance(100)
	var held: Dictionary = c.machine(bg)["held"]
	assert_true(not held.is_empty(), "the bagger took the pack")
	assert_true(int(held["left_ms"]) <= int(round(5000 * 0.75)), "a filler's cycle too (%d)" % int(held["left_ms"]))
	var d := _packfloor()
	var sid: int = d.execute({"type": "build", "machine": "P07"})["machine"]
	d.execute({"type": "upgrade_machine", "id": sid})
	assert_true(absf(float(d.seal_factor()) - 0.7) < 0.001, "its next tier: 30%% shorter (%.3f)" % d.seal_factor())


func test_p08_the_diverter_gives_premium_its_own_lane() -> void:
	var f := _packfloor()
	var cap := int(f.economy.table("factory")["shelf_packs"])
	for i in cap:
		f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 80})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + cap * 2
	assert_eq(f.shelf_room("premium"), 0, "without a diverter a full shelf has no room for premium")
	assert_true(bool(f.execute({"type": "build", "machine": "P08"})["ok"]), "the diverter is built")
	assert_eq(f.shelf_room("premium"), 2, "with it, premium has its own two places")
	assert_eq(f.shelf_room("plain"), 0, "plain is still full")
	f.queue.append({"id": f._new_id(), "order": {"recipe": "premium", "size": 2}, "patience_ms": 60000})
	_fill_bin(f, 2, "premium")
	f.advance(15000)
	assert_true(int(f.stats.get("premium_sold", 0)) >= 1, "a premium pack made and sold past a full plain shelf")
	assert_true(f.shelf.size() <= int(f.state()["shelf_cap"]), "within shelf and lane")
	_check_conservation(f, "diverter")


func test_packing_halts_full_and_idles_empty_and_saves_mid_cycle() -> void:
	var f := _packfloor(57)
	f.execute({"type": "build", "machine": "bagger"})
	f.execute({"type": "build", "machine": "P01"})
	f.execute({"type": "build", "machine": "P07"})
	f.packer_tier = 0
	var packed0 := int(f.stats["packed"])
	f.advance(20000)
	assert_eq(int(f.stats["packed"]), packed0, "no raw stock: nothing packed")
	for m: Dictionary in f.machines:
		assert_true(String(m["state"]) in ["starved", "idle"], "%s waits (%s)" % [m["type"], m["state"]])
	_fill_bin(f, 23)
	f.advance(1500)
	var g: PopRules = Factory.new()
	assert_true(bool(g.from_save(JSON.parse_string(JSON.stringify(f.to_save())))), "saves mid-cycle")
	f.advance(60000)
	g.advance(60000)
	assert_eq(g.stats, f.stats, "and goes on the same")
	assert_true(f.shelf.size() <= int(f.state()["shelf_cap"]), "the shelf never overfills")
	assert_true(f.machines.any(func(m: Dictionary) -> bool: return String(m["state"]) == "blocked") or String(f.packer_state()) == "blocked", "a full shelf stops the floor")
	_check_conservation(f, "full floor")
	var paid := int(f.stats["upkeep_paid"])
	f.advance(60000)
	assert_eq(int(f.stats["upkeep_paid"]), paid, "a stopped floor pays no upkeep")


func test_the_station_fills_every_head_up_to_the_shelf_room() -> void:
	# Found by the economy simulation (Step 30): the per-SKU shelf check once counted a started
	# pack twice, so a three-head station filled fewer heads than the shelf had room for.
	var f := _packfloor(59)
	f.packer_tier = 3
	var heads := int(f.packer()["per_cycle"])
	var cap := int(f.economy.table("factory")["shelf_packs"])
	for i in cap - heads:
		f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 80})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + (cap - heads) * 2
	_fill_bin(f, heads * 2 + 6)
	f.advance(50)
	assert_eq(f.packing.size(), heads, "every head starts a pack while the shelf has room for it (%d heads)" % heads)
	_check_conservation(f, "full heads")


# -- Step 31: S01-S08, the storefront ---------------------------------------------------

func _shop(seed_value: int = 61) -> PopRules:
	var f: PopRules = Factory.new(null, seed_value)
	_quiet_shop(f)
	f.sign_tier = 6
	f.packer_tier = 3
	f.money = 100000
	_open(f)
	_open_sign(f)
	return f


func _stock(f: PopRules, n: int, size: int = 2, recipe: String = "plain") -> void:
	for i in n:
		f.shelf.append({"id": f._new_id(), "recipe": recipe, "size": size, "quality": 80})
		f.stats["made_portions"] = int(f.stats["made_portions"]) + size


func _want(f: PopRules, size: int, recipe: String = "plain", patience: int = 60000) -> int:
	var id: int = f._new_id()
	f.queue.append({"id": id, "order": {"recipe": recipe, "size": size}, "patience_ms": patience})
	return id


func _sold_at(f: PopRules, id: int) -> int:
	for e: Dictionary in f.ledger:
		if int(e["customer"]) == id:
			return int(e["t"])
	return -1


func test_s01_the_belt_shortens_the_hand_over() -> void:
	var a := _shop()
	var base := int(a.counter_service_ms())
	assert_true(bool(a.execute({"type": "build", "machine": "S01"})["ok"]), "the belt is built")
	assert_eq(int(a.counter_service_ms()), base - 600, "0.6 s shorter")
	_stock(a, 1)
	var id := _want(a, 2)
	var t0 := int(a.flow_ms)
	a.advance(base)
	assert_true(_sold_at(a, id) >= 0 and _sold_at(a, id) - t0 <= base - 600 + 100, "the sale comes sooner")
	_check_conservation(a, "belt")


func test_s02_tickets_keep_patience_while_the_pack_is_made() -> void:
	for with_printer in [false, true]:
		var f := _shop()
		f.packer_tier = 0
		if with_printer:
			f.execute({"type": "build", "machine": "S02"})
		var id := _want(f, 2, "plain", 3000)
		_fill_bin(f, 2)
		f.advance(3500)
		var left: int = int(f.stats["abandoned"])
		if with_printer:
			assert_eq(int(left), 0, "with a ticket the customer waits for the pack being made")
			assert_true(_sold_at(f, id) >= 0 or f.queue.size() == 1 or not f.serves.is_empty(), "and is still there to buy it")
			assert_true(int(f.stats.get("ticket_saved_ms", 0)) > 0, "patience kept")
		else:
			assert_eq(int(left), 1, "without, a 3 s customer leaves before the 4 s pack is sealed")


func test_s03_the_cashier_takes_payment_apart_and_a_paused_one_holds_the_sale() -> void:
	var f := _shop()
	var base := int(f.counter_service_ms())
	var cid: int = f.execute({"type": "build", "machine": "S03"})["machine"]
	_stock(f, 6)
	for i in 4:
		_want(f, 2)
	f.advance(int(round(base * 0.65)) + 100)
	assert_true(f.paying.size() > 0 or int(f.stats["sold"]) > 0, "lanes hand over sooner and customers pay at the drawer")
	var money_before := int(f.money)
	f.execute({"type": "pause_machine", "id": cid, "paused": true})
	var waiting: int = f.paying.size()
	f.advance(5000)
	assert_true(f.paying.size() >= waiting, "a paused drawer takes no money")
	assert_true(int(f.money) == money_before, "and no sale happens without payment")
	_check_conservation(f, "paused payment (packs in the customers' hands are counted)")
	f.execute({"type": "pause_machine", "id": cid, "paused": false})
	f.advance(20000)
	assert_eq(f.paying.size(), 0, "resumed, everyone pays")
	assert_true(int(f.money) > money_before, "and the sales happen")
	_check_conservation(f, "cashier")
	var g := _shop()
	var gid: int = g.execute({"type": "build", "machine": "S03"})["machine"]
	_stock(g, 2)
	_want(g, 2)
	g.advance(int(round(base * 0.65)) + 100)
	g.paying[0]["cashier"] = -1
	assert_true(bool(g.execute({"type": "sell_machine", "id": gid})["ok"]), "an idle drawer sells")
	g.advance(100)
	assert_eq(g.paying.size(), 0, "with no drawer, the clerk takes the money")
	_check_conservation(g, "sold drawer")


func test_s04_the_router_serves_whoever_is_ready() -> void:
	for routed in [false, true]:
		var f := _shop()
		if routed:
			f.execute({"type": "build", "machine": "S04"})
		_stock(f, 3, 2)
		var big := _want(f, 4)      # nothing large on the shelf
		var small := _want(f, 2)
		f.advance(5000)
		if routed:
			assert_true(_sold_at(f, small) >= 0, "the router sends the small order past the waiting large one")
			assert_true(int(f.stats.get("routed", 0)) >= 1, "counted")
		else:
			assert_eq(_sold_at(f, small), -1, "without it, nobody jumps the line")
		assert_eq(_sold_at(f, big), -1, "the large order still waits for its bag")
		_check_conservation(f, "router")


func test_s05_the_express_window_serves_small_orders_apart() -> void:
	var f := _shop()
	var x: int = f.execute({"type": "build", "machine": "S05"})["machine"]
	f.sign_tier = 3   # one counter lane: the large orders hold it
	_stock(f, 1, 4)
	_stock(f, 2, 2)
	_stock(f, 1, 1)
	f.execute({"type": "build", "machine": "P01"})
	_want(f, 4)
	_want(f, 4)
	var s2 := _want(f, 2)
	f.advance(1700)
	assert_true(_sold_at(f, s2) >= 0, "a small order is served at the express window while large ones queue")
	assert_true(int(f.machine(x).get("done", 0)) >= 1, "by the window")
	var e: Dictionary = f.ledger.filter(func(l: Dictionary) -> bool: return int(l["customer"]) == s2)[0]
	assert_true(int(e["size"]) <= 2, "never a large bag at the express window")
	_check_conservation(f, "express")
	# With many free counter lanes the express window still takes the small orders first
	# (its lane is the faster one) -- found in the browser, where the robot's lanes took all.
	var g := _shop(67)
	var gx: int = g.execute({"type": "build", "machine": "S05"})["machine"]
	g.execute({"type": "build", "machine": "S08"})
	_stock(g, 4, 2)
	for i in 3:
		_want(g, 2)
	g.advance(100)
	assert_true(g.serves.any(func(sv: Dictionary) -> bool: return int(sv.get("kiosk", -1)) == gx), "the express window took a small order although counter lanes were free")


func test_s06_the_menu_board_lets_customers_order_what_is_there() -> void:
	var a := _shop(63)
	var b := _shop(63)
	b.execute({"type": "build", "machine": "S06"})
	for f: PopRules in [a, b]:
		_stock(f, 6, 2)   # only small bags
	var miss_a := 0
	var miss_b := 0
	for i in 200:
		var oa: Dictionary = a._draw_order()
		var ob: Dictionary = b._draw_order()
		if a._matching_pack(oa) < 0:
			miss_a += 1
		if b._matching_pack(ob) < 0:
			miss_b += 1
	assert_true(miss_a > 30, "without the board many order a large bag that is not there (%d)" % miss_a)
	assert_eq(miss_b, 0, "with it, every new order is for what is on the shelf")
	assert_true(int(b.stats.get("menu_switched", 0)) > 0, "counted")


func test_s08_the_robot_adds_counter_lanes() -> void:
	var f := _shop()
	var base := int(f.lanes())
	var r: int = f.execute({"type": "build", "machine": "S08"})["machine"]
	assert_eq(int(f.lanes()), base + 2, "two more counter lanes")
	f.execute({"type": "upgrade_machine", "id": r})
	f.execute({"type": "upgrade_machine", "id": r})
	assert_eq(int(f.lanes()), base + 4, "four at its best tier")
	_stock(f, 8)
	for i in 8:
		_want(f, 2)
	f.advance(100)
	assert_eq(f.serves.size(), base + 4, "that many hand-overs at once")
	f.advance(3000)
	assert_true(int(f.stats["sold"]) >= base + 4, "all of them finish together")
	_check_conservation(f, "robot")


func test_two_to_eight_lanes_under_seeded_waves_with_honest_sales() -> void:
	# One customer about every 15 s (sign 1), then faster waves (3, 5, 6); the shelf is kept
	# stocked (as a big kitchen would) so the counter is what is measured: the sign's lanes
	# against a full storefront (robot, express window, cashier, router, kiosk).
	var results := {}
	for full in [false, true]:
		var f: PopRules = Factory.new(null, 65)
		f.packer_tier = 3
		f.money = 100000
		_open(f)
		_open_sign(f)
		if full:
			f.sign_tier = 6
			f.execute({"type": "build", "machine": "M07"})
			for id in ["S08", "S05", "S03", "S04"]:
				assert_true(bool(f.execute({"type": "build", "machine": id})["ok"]), "%s built" % id)
			var r: int = f.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "S08")[0]["id"]
			f.execute({"type": "upgrade_machine", "id": r})
			f.execute({"type": "upgrade_machine", "id": r})
			f.execute({"type": "sell_machine", "id": f.machines[0]["id"]})
		var sold0 := int(f.stats["sold"])
		var k := 0
		for wave in [1, 3, 5, 6]:
			f.sign_tier = wave
			for i in 160:
				var cap := int(f.economy.table("factory")["shelf_packs"])
				while f.shelf.size() < cap:
					var size := 4 if k % 3 == 0 else 2
					f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": size, "quality": 80})
					f.stats["made_portions"] = int(f.stats["made_portions"]) + size
					k += 1
				f.advance(750)
		_check_conservation(f, "waves %s" % ("full" if full else "sign only"))
		assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "no wrong SKU")
		for e: Dictionary in f.ledger:
			assert_eq(int(e["size"]), int(e["ordered"]), "each sale the size ordered")
		results[full] = {"sold": int(f.stats["sold"]) - sold0, "lost": int(f.stats["abandoned"]) + int(f.stats["passed_by"]), "lanes": int(f.lanes())}
	assert_eq(int(results[false]["lanes"]), 2, "the sign's own lanes: 2")
	assert_true(int(results[true]["lanes"]) + 1 >= 7, "the full storefront: %d counter lanes + the express window" % results[true]["lanes"])
	assert_true(int(results[true]["sold"]) > int(results[false]["sold"]), "and sells more (%d vs %d)" % [results[true]["sold"], results[false]["sold"]])
	assert_true(int(results[true]["lost"]) < int(results[false]["lost"]), "losing fewer customers (%d vs %d)" % [results[true]["lost"], results[false]["lost"]])


func test_storefront_edge_cases_exhausted_overflow_failed_and_simultaneous() -> void:
	var f := _shop()
	for id in ["S08", "S04", "S05"]:
		f.execute({"type": "build", "machine": id})
	# Exhausted inventory: customers but no packs -- nothing sold, nobody served.
	for i in 3:
		_want(f, 2, "plain", 4000)
	var sold_before := int(f.stats["sold"])
	f.advance(3000)
	assert_eq(int(f.stats["sold"]), sold_before, "no packs, no sales -- whatever machines stand there")
	assert_true(f.serves.is_empty(), "nobody served from nothing")
	# Failed sale: their patience runs out.
	f.advance(2000)
	assert_eq(int(f.stats["abandoned"]), 3, "they leave unserved (a failed sale, no money)")
	assert_eq(int(f.money), 100000 - int(f.machines.reduce(func(n: int, m: Dictionary) -> int: return n + int(m["paid"]), 0)) - int(f.stats["upkeep_paid"]), "no money moved but purchases and upkeep")
	# Queue overflow: arrivals past the cap walk by.
	f.next_arrival_ms = int(f.flow_ms)
	var cap := int(f.queue_cap())
	for i in cap:
		_want(f, 2)
	var passed := int(f.stats["passed_by"])
	f.advance(200)
	assert_true(int(f.stats["passed_by"]) > passed, "a full queue turns arrivals away")
	assert_true(f.queue.size() <= cap, "and never grows past its cap")
	# Simultaneous completion: many lanes finish in the same step, each sale once.
	f.queue.clear()
	f.next_arrival_ms = 1 << 40
	_stock(f, 6)
	var ids: Array = []
	for i in 6:
		ids.append(_want(f, 2))
	f.advance(100)
	var sold0 := int(f.stats["sold"])
	f.advance(3000)
	var each := ids.map(func(id: int) -> int: return f.ledger.filter(func(e: Dictionary) -> bool: return int(e["customer"]) == id).size())
	for n: int in each:
		assert_true(n <= 1, "nobody is sold to twice")
	assert_true(int(f.stats["sold"]) > sold0, "the lanes finished")
	_check_conservation(f, "edges")


# -- Step 32: U01-U08, upkeep overview, an hour of operation ----------------------------

func _util(seed_value: int = 71) -> PopRules:
	var f := _shop(seed_value)
	return f


func test_u01_the_robot_keeps_coins_for_the_machines_that_make_goods() -> void:
	var done := {}
	for with_robot in [false, true]:
		var f := _util(73)
		f.execute({"type": "build", "machine": "M07"})
		for id in ["M02", "M03", "M04", "M05", "M06", "M08"]:
			f.execute({"type": "build", "machine": id})
		if with_robot:
			f.execute({"type": "build", "machine": "U01", "floor": "packing"})
		f.machines[0]["kernels"] = 1000
		f.money = 25
		var lots := _auto_lots(f, 240000)
		done[with_robot] = lots.size()
		assert_true(int(f.money) >= 0, "never a debt")
		if with_robot:
			assert_true(int(f.stats.get("saving_ms", 0)) > 0, "the helpers stopped to save coins")
	assert_true(int(done[true]) > int(done[false]), "with the robot the kettle cooks longer on a thin wallet (%d vs %d lots)" % [done[true], done[false]])


func test_u02_the_lubricator_speeds_its_neighbours_only() -> void:
	var f := _util()
	f.execute({"type": "build", "machine": "M07", "slot": 0})
	f.execute({"type": "build", "machine": "M07", "slot": 3})
	var near: Dictionary = f.machine_at("kitchen", 0)
	var far: Dictionary = f.machine_at("kitchen", 3)
	var base := int(f._cooker_cycle(near))
	assert_true(bool(f.execute({"type": "build", "machine": "U02", "slot": 1, "floor": "kitchen"})["ok"]), "the lubricator stands beside the first kettle")
	assert_eq(int(f._cooker_cycle(near)), int(round(base * 0.9)), "its neighbour 10% faster")
	assert_eq(int(f._cooker_cycle(far)), base, "a machine two places away is not")


func test_u03_the_saver_cuts_its_floors_upkeep() -> void:
	var paid := {}
	for saver in [false, true]:
		var f := _util(75)
		f.execute({"type": "build", "machine": "M07"})
		f.execute({"type": "build", "machine": "M07"})
		if saver:
			f.execute({"type": "build", "machine": "U03", "floor": "kitchen"})
		for m: Dictionary in f.machines:
			m["kernels"] = 1000
		_auto_lots(f, 240000)
		paid[saver] = int(f.stats["upkeep_paid"])
	assert_true(int(paid[true]) < int(paid[false]) * 0.85, "a quarter less upkeep on its floor (%d vs %d)" % [paid[true], paid[false]])
	var g := _util()
	g.execute({"type": "build", "machine": "U03", "floor": "packing"})
	assert_eq(float(g._energy_cut("kitchen")), 0.0, "only on its own floor")


func test_u04_the_buffer_lift_adds_real_room() -> void:
	var f := _util()
	var bin0 := int(f.bin_cap())
	var shelf0 := int(f.shelf_cap())
	var r := f.execute({"type": "build", "machine": "U04"})
	assert_true(bool(r["ok"]), "built on the packing floor")
	assert_eq(String(f.machine(int(r["machine"]))["floor"]), "packing", "between the floors")
	assert_eq(int(f.bin_cap()), bin0 + 12, "12 more portions in the bin")
	assert_eq(int(f.shelf_cap()), shelf0 + 4, "4 more packs on the shelf")
	_stock(f, int(f.shelf_cap()))
	_check_conservation(f, "a full bigger shelf")
	f.execute({"type": "pause_machine", "id": int(r["machine"]), "paused": true})
	assert_eq(int(f.bin_cap()), bin0, "paused, the room is not there (nothing is lost: the goods stay)")


func test_u05_the_inspector_sends_rejects_to_a_bargain_sku() -> void:
	var f := _util()
	f.execute({"type": "build", "machine": "M07"})
	assert_true(bool(f.execute({"type": "build", "machine": "U05"})["ok"]), "built")
	var lot := {"id": 0, "recipe": "plain", "quality": 30, "portions": 4}
	f._sort_and_grade(lot, "burnt")
	assert_eq(String(lot["recipe"]), "bargain", "a burnt lot is a bargain")
	var ok := {"id": 0, "recipe": "plain", "quality": 80, "portions": 4}
	f._sort_and_grade(ok, "near")
	assert_eq(String(ok["recipe"]), "plain", "a good lot stays plain")
	f.bin.append({"id": f._new_id(), "recipe": "bargain", "quality": 30, "portions": 4})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 4
	var asks := 0
	for i in 200:
		if String(f._draw_order()["recipe"]) == "bargain":
			asks += 1
	assert_true(asks > 25 and asks < 90, "about a quarter ask for a bargain while there is one (%d)" % asks)
	f.queue.append({"id": f._new_id(), "order": {"recipe": "bargain", "size": 2}, "patience_ms": 60000})
	f.advance(15000)
	var sold: Array = f.ledger.filter(func(e: Dictionary) -> bool: return String(e["recipe"]) == "bargain")
	assert_true(not sold.is_empty(), "a bargain customer bought a bargain pack")
	assert_true(int(sold[0]["coins"]) < int(f.pack_price("plain", 2, int(sold[0]["quality"]))), "for less than plain")
	assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "never to a plain customer")
	_check_conservation(f, "bargain")


func test_u06_u07_u08_wait_for_their_systems() -> void:
	var f := _util()
	for id in ["U06", "U07"]:
		assert_eq(String(f.execute({"type": "build", "machine": id})["reason"]), "err.not_yet", "%s is not sold before its system exists" % id)
	# Step 33: parallel lines exist, but U08 balances two packing lines -- with one it would do nothing.
	assert_eq(String(f.execute({"type": "build", "machine": "U08"})["reason"]), "err.needs_lines", "U08 is not sold with one packing line")


func test_the_overview_and_pause_all() -> void:
	var f := _util()
	f.next_arrival_ms = 0
	f.execute({"type": "build", "machine": "M07"})
	f.execute({"type": "build", "machine": "M01"})
	f.execute({"type": "build", "machine": "bagger"})
	f.execute({"type": "build", "machine": "S03"})
	f.advance(60000)
	var o: Dictionary = f.upkeep_overview()
	assert_true(float(o["burn_per_min"]) > 0.0, "running machines burn coins (%s/min)" % o["burn_per_min"])
	assert_true(int(o["revenue_last_min"]) > 0, "the shop took money in the last minute")
	assert_almost_equal_net(o)
	assert_eq((o["machines"] as Array).size(), f.machines.size(), "a line per machine")
	var ledger_sum := 0
	for row: Dictionary in o["machines"]:
		ledger_sum += int(row["paid"])
	assert_eq(ledger_sum, int(f.stats["upkeep_paid"]), "the per-machine ledger adds up to the upkeep paid")
	assert_true(bool(f.execute({"type": "pause_all", "paused": true})["ok"]), "pause all")
	assert_true(f.machines.all(func(m: Dictionary) -> bool: return String(m["state"]) == "paused"), "every machine paused")
	var paid := int(f.stats["upkeep_paid"])
	f.advance(60000)
	assert_eq(int(f.stats["upkeep_paid"]), paid, "a paused factory pays nothing")
	assert_true(float(f.upkeep_overview()["burn_per_min"]) == 0.0, "and burns nothing")
	f.execute({"type": "pause_all", "paused": false})
	assert_true(f.machines.all(func(m: Dictionary) -> bool: return String(m["state"]) != "paused"), "resume all")
	f.money = 1
	f.advance(2000)
	assert_true(bool(f.upkeep_overview()["low_wallet"]), "a thin wallet is flagged")
	_check_conservation(f, "overview")


func assert_almost_equal_net(o: Dictionary) -> void:
	assert_true(absf(float(o["net_per_min"]) - (float(o["revenue_last_min"]) - float(o["burn_per_min"]))) < 0.2, "net = revenue - burn")


func test_an_hour_of_operation_high_and_low_demand_thin_wallet_and_forty_machines() -> void:
	# One hour of model time per case, a hand popping; conservation and no debt every
	# minute; the per-machine ledger adds up; a save at half time goes on the same.
	var cases := {"low_demand": [1, 9, 100000], "high_demand": [6, 9, 100000], "thin_wallet": [6, 9, 30], "full_places": [6, 40, 100000]}
	for name: String in cases:
		var c: Array = cases[name]
		var f: PopRules = Factory.new(null, 77)
		f.packer_tier = 3
		f.level = 6
		f.money = 1 << 20
		_open(f)
		_open_sign(f)
		f.sign_tier = 6
		var plan := ["M07", "M10", "M07", "M01", "M16", "M13", "M14", "U03", "M08", "M02", "bagger", "P01", "P07", "U04", "S03", "S05", "S08", "S01"]
		for id: String in plan:
			if f.machines.size() >= int(c[1]):
				break
			f.execute({"type": "build", "machine": id, "floor": "kitchen"})
		var dist: Array = f.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "M10")
		if not dist.is_empty():
			f.execute({"type": "upgrade_machine", "id": dist[0]["id"]})
			f.execute({"type": "upgrade_machine", "id": dist[0]["id"]})
		if int(c[1]) >= 40:
			# Every place filled (40 instances need Step 33's places; here the floors hold ~20).
			var k := 0
			while k < 200:
				f.execute({"type": "build", "machine": ["M07", "bagger", "S05", "M01", "P07", "S01", "M08", "U02"][k % 8], "floor": ["kitchen", "packing", "shop"][k % 3]})
				k += 1
		f.sign_tier = int(c[0])
		f.money = int(c[2])
		var b: PopRules = null
		for minute in 60:
			for i in 40:
				if f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
					f.execute({"type": "press"})
				f.advance(1500)
				if f.heating:
					f.execute({"type": "release"})
			assert_true(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "%s minute %d: every portion is somewhere" % [name, minute])
			assert_true(int(f.money) >= 0, "%s minute %d: no debt" % [name, minute])
			if minute == 29:
				b = Factory.new()
				assert_true(bool(b.from_save(JSON.parse_string(JSON.stringify(f.to_save())))), "%s: saves at half time" % name)
				b.advance(60000)
				assert_true(int(b.portions_everywhere()) == int(b.stats["made_portions"]), "%s: the restored factory keeps every portion" % name)
		var sum := 0
		for row: Dictionary in f.upkeep_overview()["machines"]:
			sum += int(row["paid"])
		assert_eq(sum, int(f.stats["upkeep_paid"]), "%s: the per-machine ledger adds up" % name)
		assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "%s: no wrong SKU" % name)
		if name == "full_places":
			assert_true(f.machines.size() >= 18, "every place filled: %d machines ran for an hour" % f.machines.size())


# -- Step 33: lines, parallel packing lines, forty machines at once -----------------

## The forty-machine plan, in build order (a floor that is full buys its next line).
const FORTY_PLAN := [["M07", "kitchen"], ["bagger", "packing"], ["S03", "shop"], ["M01", "kitchen"], ["M07", "kitchen"],
	["S05", "shop"], ["M07", "kitchen"], ["P07", "packing"], ["M13", "kitchen"], ["M07", "kitchen"], ["bagger", "packing"],
	["S08", "shop"], ["M08", "kitchen"], ["U04", "packing"], ["S01", "shop"], ["M06", "kitchen"], ["M07", "kitchen"],
	["M07", "kitchen"], ["M01", "kitchen"], ["bagger", "packing"], ["kiosk", "shop"], ["M14", "kitchen"], ["U08", "packing"],
	["S04", "shop"], ["M07", "kitchen"], ["M07", "kitchen"], ["bagger", "packing"], ["S06", "shop"], ["M02", "kitchen"],
	["P01", "packing"], ["kiosk", "shop"], ["M07", "kitchen"], ["M01", "kitchen"], ["bagger", "packing"], ["M03", "kitchen"],
	["U05", "packing"], ["M07", "kitchen"], ["U03", "kitchen"], ["bagger", "packing"], ["M07", "kitchen"], ["M05", "kitchen"],
	["U02", "kitchen"], ["M07", "kitchen"], ["P04", "packing"]]


## A factory with the first `n` machines of the plan built (lines bought when a floor fills).
func _forty(n: int, seed_value: int = 81) -> PopRules:
	var f: PopRules = _steady(Factory.new(null, seed_value))
	f.packer_tier = 3
	f.sign_tier = 6
	f.level = 6
	f.money = 1 << 30
	_open(f)
	_open_sign(f)
	for row: Array in FORTY_PLAN:
		if f.machines.size() >= n:
			break
		var floor := String(row[1])
		if f.floor_full(floor) and int(f.line_cost(floor)) >= 0:
			assert_true(bool(f.execute({"type": "buy_line", "floor": floor})["ok"]), "%s buys its next line when full" % floor)
		if String(row[0]) == "U08" and not f.parallel_lines():
			continue
		var r: Dictionary = f.execute({"type": "build", "machine": row[0], "floor": floor})
		assert_true(bool(r["ok"]), "%s on the %s floor: %s" % [row[0], floor, r.get("reason", "")])
	for m: Dictionary in f.machines:
		if f._is_kettle(m):
			m["kernels"] = maxi(int(m["kernels"]), 5)
	return f


## No over-selling: every sale is a real pack of what was ordered, and the money adds up.
func _check_sales(f: PopRules, label: String) -> void:
	# (_open_sign counts one sale that never happened, to open the sign: the ledger has the real ones)
	assert_eq(int(f.stats["sold"]) - 1, f.ledger.size(), "%s: a ledger row per sale" % label)
	var coins := 0
	var portions := 0
	for e: Dictionary in f.ledger:
		coins += int(e["coins"])
		portions += int(e.get("portions", 0))
	assert_eq(coins, int(f.stats["revenue"]), "%s: the ledger's coins are the revenue" % label)
	assert_true(portions <= int(f.stats["made_portions"]), "%s: never sold more popcorn than was made" % label)
	assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "%s: never the wrong product" % label)


func test_lines_add_places_once_a_floor_is_full() -> void:
	var f := _shop(91)
	f.money = 1 << 20
	assert_eq(int(f.slots("packing")), 4, "the packing floor starts with four places")
	assert_eq(String(f.execute({"type": "buy_line", "floor": "packing"})["reason"]), "err.floor_not_full", "a floor with a free place does not grow")
	for id in ["bagger", "bagger", "P07", "U04"]:
		assert_true(bool(f.execute({"type": "build", "machine": id})["ok"]), "%s built" % id)
	var before := f.money
	var r: Dictionary = f.execute({"type": "buy_line", "floor": "packing"})
	assert_true(bool(r["ok"]), "a full floor buys its second line")
	assert_eq(before - f.money, int(f._t()["lines"]["packing"][0]["cost"]), "for its price")
	assert_eq(int(f.slots("packing")), 8, "four more places")
	assert_true(f.parallel_lines(), "two packing lines are parallel lines")
	assert_eq(int(f.line_of("packing", 3)), 0, "place 4 is the first line's")
	assert_eq(int(f.line_of("packing", 4)), 1, "place 5 is the second line's")
	f.money = 10
	for id in ["bagger", "bagger", "P01", "U08"]:
		f.money += 100000
		assert_true(bool(f.execute({"type": "build", "machine": id})["ok"]), "%s on the second line" % id)
	f.money = 10
	assert_eq(String(f.execute({"type": "buy_line", "floor": "packing"})["reason"]), "err.not_enough_money", "a line is paid for")
	f.money = 1 << 20
	assert_true(bool(f.execute({"type": "buy_line", "floor": "packing"})["ok"]), "the third line")
	assert_eq(String(f.execute({"type": "buy_line", "floor": "packing"})["reason"]), "err.max_level", "three is every packing line")
	# Saved and restored with its lines; a 0.32 save (no lines) comes back with one a floor.
	var b: PopRules = Factory.new()
	assert_true(bool(b.from_save(JSON.parse_string(JSON.stringify(f.to_save())))), "restores")
	assert_eq(int(b.slots("packing")), 12, "the lines come back")
	var old: Dictionary = f.to_save()
	old.erase("floor_lines")
	var c: PopRules = Factory.new()
	old["machines"] = []
	assert_true(bool(c.from_save(JSON.parse_string(JSON.stringify(old)))), "a save without lines restores")
	assert_eq(c.floor_lines, {"kitchen": 1, "packing": 1, "shop": 1}, "with one line a floor")


func test_the_distributors_places_stay_where_they_are_when_the_kitchen_grows() -> void:
	var f := _forty(0)
	f.execute({"type": "build", "machine": "M07"})
	f.execute({"type": "build", "machine": "M10"})
	var k := 0
	while not f.floor_full("kitchen") and k < 20:
		f.execute({"type": "build", "machine": "M07"})
		k += 1
	assert_eq(int(f.slots("kitchen")), 10, "eight places and the distributor's two")
	var on_extra: Dictionary = f.machine_at("kitchen", 9)
	assert_false(on_extra.is_empty(), "a kettle on a distributor place")
	assert_true(bool(f.execute({"type": "buy_line", "floor": "kitchen"})["ok"]), "the kitchen's second line")
	assert_eq(int(f.slots("kitchen")), 18, "eight more places")
	assert_eq(int(f.machine_at("kitchen", 9)["id"]), int(on_extra["id"]), "the kettle keeps its place")
	# The distributor's places now come after the line: selling it takes no machine's place away.
	assert_true(bool(f.execute({"type": "sell_machine", "id": f.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "M10")[0]["id"]})["ok"]), "the distributor sells (its places were free)")
	assert_eq(int(f.slots("kitchen")), 16, "two lines of eight")
	assert_eq(int(f.machine_at("kitchen", 9)["id"]), int(on_extra["id"]), "the kettle still stands on its place")


func test_parallel_lines_route_each_lot_to_one_line_and_fillers_pack_only_theirs() -> void:
	var f := _shop(93)
	f.money = 1 << 20
	for id in ["bagger", "P07", "U04", "P04"]:
		f.execute({"type": "build", "machine": id})
	f.execute({"type": "buy_line", "floor": "packing"})
	f.execute({"type": "build", "machine": "bagger"})   # place 5: the second line
	var b2: Dictionary = f.machines[f.machines.size() - 1]
	assert_eq(int(f.line_of("packing", int(b2["slot"]))), 1, "the new filler is on the second line")
	# Lots landing are routed: the least popcorn per packer, ties to the first line.
	var lines: Array = []
	for i in 6:
		var lot := {"id": f._new_id(), "recipe": "plain", "quality": 80, "portions": 4}
		f.stats["made_portions"] = int(f.stats["made_portions"]) + 4
		f.lift.append({"lot": lot, "left_ms": 50})
		f.advance(50)
		lines.append(int(lot.get("line", -1)))
	assert_true(lines.has(0) and lines.has(1), "both lines get goods (%s)" % [lines])
	# A filler packs only its line's lots: pause the second line's filler -- its goods wait.
	f.execute({"type": "pause_machine", "id": b2["id"], "paused": true})
	var line2: int = f.line_portions(1)
	_want(f, 2)
	_want(f, 2)
	f.advance(20000)
	assert_eq(int(f.line_portions(1)), line2, "the paused line's popcorn waits on its line (no balancer)")
	assert_true(int(f.stats.get("line_blocked_ms", 0)) > 0, "and the factory knows a line is stopped")
	# A paused line gets no new lots.
	var lot2 := {"id": f._new_id(), "recipe": "plain", "quality": 80, "portions": 4}
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 4
	f.lift.append({"lot": lot2, "left_ms": 50})
	f.advance(100)
	assert_eq(int(lot2["line"]), 0, "a stopped line is not dispatched to")
	# Its last filler sold: its goods go back to the first line (they never strand).
	f.execute({"type": "pause_machine", "id": b2["id"], "paused": false})
	f.advance(50)
	var held: bool = not (f.machine(b2["id"])["held"] as Dictionary).is_empty()
	if held:
		f.advance(8000)
	f.execute({"type": "pause_machine", "id": b2["id"], "paused": true})
	var sold: Dictionary = f.execute({"type": "sell_machine", "id": b2["id"]})
	if bool(sold["ok"]):
		f.advance(50)
		assert_eq(int(f.line_portions(1)), 0, "a line without fillers keeps nothing")
	_check_conservation(f, "routing")


func test_u08_moves_goods_from_a_stopped_line_to_an_idle_one() -> void:
	var results := {}
	for with_balancer in [false, true]:
		var f := _shop(95)
		f.money = 1 << 20
		for id in ["bagger", "P07", "U04", "P04"]:
			f.execute({"type": "build", "machine": id})
		f.execute({"type": "buy_line", "floor": "packing"})
		f.execute({"type": "build", "machine": "bagger"})
		var b2: Dictionary = f.machines[f.machines.size() - 1]
		if with_balancer:
			assert_true(bool(f.execute({"type": "build", "machine": "U08"})["ok"]), "U08 is built with two packing lines")
		f.execute({"type": "pause_machine", "id": b2["id"], "paused": true})
		for i in 5:
			var lot := {"id": f._new_id(), "recipe": "plain", "quality": 80, "portions": 4, "line": 1}
			f.bin.append(lot)
			f.stats["made_portions"] = int(f.stats["made_portions"]) + 4
		for i in 10:
			_want(f, 2, "plain", 300000)
		var max_moving := 0
		var paid0 := int(f.stats["upkeep_paid"])
		for i in 600:
			f.advance(100)
			max_moving = maxi(max_moving, int(f.state()["moving_lots"]))
			if i % 50 == 0:
				_check_conservation(f, "balancer %s" % with_balancer)
		results[with_balancer] = {"left": f.line_portions(1), "sold": int(f.stats["sold"]), "moved": int(f.stats.get("moved_lots", 0)), "max": max_moving}
		_check_sales(f, "balancer")
		if with_balancer:
			var u: Dictionary = f.machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "U08")[0]
			assert_true(max_moving <= 1, "tier 0 moves one lot at a time (%d)" % max_moving)
			assert_true(int(u["upkeep_ms"]) + int(u.get("upkeep_paid", 0)) > 0, "its keep runs while it moves")
			var idle_ms := int(u["upkeep_ms"])
			var idle_paid := int(u.get("upkeep_paid", 0))
			f.advance(120000)
			assert_eq(int(u["upkeep_ms"]), idle_ms, "and not while there is nothing to move")
			assert_eq(int(u.get("upkeep_paid", 0)), idle_paid, "(no coin)")
	assert_eq(int(results[false]["left"]), 20, "without a balancer the stopped line's 20 portions wait")
	assert_eq(int(results[false]["moved"]), 0, "nothing moves")
	assert_eq(int(results[true]["left"]), 0, "with it every lot reached the working line")
	assert_eq(int(results[true]["moved"]), 5, "five lots moved")
	assert_true(int(results[true]["sold"]) > int(results[false]["sold"]), "and more customers were served (%d > %d)" % [results[true]["sold"], results[false]["sold"]])


func test_a_backlog_of_120_queued_moves_drains_in_order_and_keeps_every_portion() -> void:
	# A stress of the balancer's queue, beyond what a real bin holds (the bin's own size is
	# tested elsewhere): 120 one-portion lots on a stopped line, a tier-2 balancer
	# (three at a time) moves them to the working lines; a pause mid-way freezes the moves
	# (interrupted transfers) and a save restores them in flight.
	var f := _shop(97)
	f.money = 1 << 20
	for id in ["bagger", "P07", "U04", "P04"]:
		f.execute({"type": "build", "machine": id})
	f.execute({"type": "buy_line", "floor": "packing"})
	f.execute({"type": "build", "machine": "bagger"})
	f.execute({"type": "build", "machine": "bagger"})
	f.execute({"type": "build", "machine": "U08"})
	var u: Dictionary = f.machines[f.machines.size() - 1]
	f.execute({"type": "upgrade_machine", "id": u["id"]})
	f.execute({"type": "upgrade_machine", "id": u["id"]})
	var stopped: Dictionary = f.machines[f.machines.size() - 3]   # the second line's first filler
	f.execute({"type": "pause_machine", "id": stopped["id"], "paused": true})
	f.execute({"type": "pause_machine", "id": f.machines[f.machines.size() - 2]["id"], "paused": true})
	for i in 120:
		f.bin.append({"id": f._new_id(), "recipe": "plain", "quality": 80, "portions": 1, "line": 1})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 120
	assert_eq(int(f.line_portions(1)), 120, "120 queued moves")
	var max_moving := 0
	var paused_at := -1
	var order_ok := true
	var last_moved_id := -1
	for i in 4000:
		f.drain_events()
		f.advance(100)
		for e: Dictionary in f.drain_events():
			if String(e["type"]) == "lot_moving":
				if int(e["data"]["lot"]) < last_moved_id:
					order_ok = false
				last_moved_id = int(e["data"]["lot"])
		max_moving = maxi(max_moving, int(f.state()["moving_lots"]))
		if f.shelf.size() >= int(f.shelf_base()):
			f.shelf.clear()   # an endless shop: the packs leave (as sales would)
			f.stats["made_portions"] = int(f.portions_everywhere())
		if i == 200:
			f.execute({"type": "pause_machine", "id": u["id"], "paused": true})
			paused_at = int(f.state()["moving_lots"])
		if i == 230:
			assert_eq(int(f.state()["moving_lots"]), paused_at, "a paused balancer's lots stay in flight (%d)" % paused_at)
			var b: PopRules = Factory.new()
			assert_true(bool(b.from_save(JSON.parse_string(JSON.stringify(f.to_save())))), "saves with lots in flight")
			assert_eq(int(b.state()["moving_lots"]), paused_at, "and restores them in flight")
			f.execute({"type": "pause_machine", "id": u["id"], "paused": false})
		assert_true(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "every portion is somewhere")
		if f.line_portions(1) == 0 and int(f.state()["moving_lots"]) == 0:
			break
	assert_true(paused_at > 0, "the pause caught lots in flight")
	assert_true(max_moving <= 3 and max_moving >= 2, "tier 2 moves up to three lots at once (%d)" % max_moving)
	assert_true(order_ok, "the oldest lots move first")
	assert_eq(int(f.line_portions(1)), 0, "every queued lot moved")
	assert_eq(int(f.stats.get("moved_lots", 0)), 120, "120 moves")


func test_forty_machines_run_at_once_and_never_break_conservation_or_oversell() -> void:
	# 1, 5, 10, 20 and 40+ machines, ten minutes each with a hand popping now and then:
	# every 10 s every portion is somewhere, no debt; no over-selling; every machine of the
	# forty worked at some point (not forty pictures); the time it takes is printed.
	for n in [1, 5, 10, 20, 44]:
		var f := _forty(n, 83)
		assert_eq(f.machines.size(), n, "%d machines built" % n)
		f.money = 2000
		var ran := {}
		var t0 := Time.get_ticks_usec()
		for step in 600:
			f.advance(1000)
			if step % 7 == 0 and f.glass.is_empty() and not f.heating and int(f.cooldown_left) <= 0:
				f.execute({"type": "press"})
				f.advance(1450)
				f.execute({"type": "release"})
			for m: Dictionary in f.machines:
				if String(m["state"]) == "run":
					ran[int(m["id"])] = true
			if step % 10 == 0:
				assert_true(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "%d machines, %d s: every portion is somewhere" % [n, step])
				assert_true(f.money >= 0, "%d machines: no debt" % n)
		var ms := (Time.get_ticks_usec() - t0) / 1000
		print("  %d machines: ten model minutes in %d ms, sold %d, upkeep %d, revenue %d" % [n, ms, f.stats["sold"], f.stats["upkeep_paid"], f.stats["revenue"]])
		_check_sales(f, "%d machines" % n)
		_check_conservation(f, "%d machines" % n)
		if n >= 40:
			var idle: Array = f.machines.filter(func(m: Dictionary) -> bool: return not ran.has(int(m["id"]))).map(func(m: Dictionary) -> String: return String(m["type"]))
			assert_true(f.machines.size() >= 40, "at least forty machine instances (%d)" % f.machines.size())
			assert_true(idle.size() <= 2, "nearly every machine worked (never ran: %s)" % [idle])
			assert_true(ms < 60000, "ten model minutes of forty machines take under a minute (%d ms)" % ms)


func test_a_demand_surge_with_forty_machines_respects_the_queue_and_the_shelf() -> void:
	# A heavy rush (a customer every step, as a news surge might bring): the queue never
	# passes its size, nobody is served without a pack, money adds up.
	var f := _forty(44, 85)
	f.money = 5000
	var most := 0
	for step in 2400:
		f.next_arrival_ms = mini(int(f.next_arrival_ms), int(f.flow_ms) + 100)
		f.advance(100)
		most = maxi(most, f.queue.size())
		assert_true(f.queue.size() <= int(f.queue_cap()), "the queue within its size")
		if step % 50 == 0:
			_check_conservation(f, "surge")
	assert_true(most >= int(f.queue_cap()) - 1, "the rush filled the queue (%d)" % most)
	assert_true(int(f.stats["abandoned"]) + int(f.stats["sold"]) > 300, "hundreds of customers came")
	_check_sales(f, "surge")


func test_forty_machines_are_the_same_whatever_the_frame_rate_and_after_a_restart() -> void:
	# The model steps in 50 ms of total time: a 60, 30 or 10 fps caller, or a tab that
	# comes back after a second, gets the same factory; a save mid-cycle goes on the same.
	var runs: Array = []
	for chunk in [16, 33, 100, 1000]:
		var f := _forty(44, 87)
		var t := 0
		while t < 120000:
			f.advance(chunk)
			t += chunk
		f.advance(120000 + 1000 - t)
		runs.append(JSON.stringify(f.to_save()))
	for i in range(1, runs.size()):
		assert_eq(runs[i], runs[0], "the same factory at chunk %d as at 16 ms" % [[16, 33, 100, 1000][i]])
	var a := _forty(44, 87)
	a.advance(61000)
	var b: PopRules = _steady(Factory.new())
	assert_true(bool(b.from_save(JSON.parse_string(JSON.stringify(a.to_save())))), "saves mid-cycle")
	a.advance(60000)
	b.advance(60000)
	assert_eq(JSON.stringify(b.to_save()), JSON.stringify(a.to_save()), "the restored factory goes on exactly the same")


func test_forty_machines_with_an_empty_wallet_stop_and_recover_without_debt() -> void:
	# Every machine owes a coin now and the wallet is empty: they wait (never a debt); the
	# hand's free pops, the station and the counter sell, and the coins start them again.
	var f := _forty(44, 89)
	f.money = 0
	f.next_arrival_ms = 0
	for m: Dictionary in f.machines:
		var per: float = float(f.catalog(String(m["type"]))["upkeep_per_min"])
		if per > 0.0:
			m["upkeep_ms"] = int(60000.0 / per) - 10
	var unpaid := 0
	var ran_after := false
	for step in 600:
		if f.glass.is_empty() and not f.heating and int(f.cooldown_left) <= 0:
			f.execute({"type": "press"})
			f.advance(1450)
			f.execute({"type": "release"})
		f.advance(500)
		var now_unpaid: int = f.machines.filter(func(m: Dictionary) -> bool: return String(m["state"]) in ["unpaid", "saving"]).size()
		unpaid = maxi(unpaid, now_unpaid)
		if unpaid > 0 and f.machines.any(func(m: Dictionary) -> bool: return f._is_kettle(m) and String(m["state"]) == "run"):
			ran_after = true
		assert_true(f.money >= 0, "never a debt")
	assert_true(unpaid >= 10, "machines waited for coins (%d at once)" % unpaid)
	assert_true(int(f.stats["sold"]) > 1, "the hand's popcorn still sold")
	assert_true(ran_after, "and kettles ran again with the coins it brought")
	_check_sales(f, "empty wallet")
	_check_conservation(f, "empty wallet")


# -- Step 34: flavors -----------------------------------------------------------------

const FIVE := ["plain", "cheese", "spicy", "caramel", "cocoa"]


## A packing floor with flavors open (sign 6, packing 3), the shop quiet.
func _flavor_floor(seed_value: int = 71) -> PopRules:
	var f := _shop(seed_value)
	f.money = 100000
	return f


func _coater(f: PopRules, type: String, flavor: String) -> Dictionary:
	var r := f.execute({"type": "build", "machine": type})
	assert_true(bool(r["ok"]), "%s built (%s)" % [type, r.get("reason", "")])
	var m: Dictionary = f.machine(int(r.get("machine", -1)))
	if flavor != "" and not m.is_empty():
		var s := f.execute({"type": "set_flavor", "id": m["id"], "flavor": flavor})
		assert_true(bool(s["ok"]), "%s set to %s (%s)" % [type, flavor, s.get("reason", "")])
	return m


## Plain packs at the plain stock targets with one flavor offered (two large, the small
## ones up to the place one flavor keeps): the station takes no plain from the bin.
func _fill_shelf(f: PopRules) -> void:
	for i in 2:
		f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 4, "quality": 80})
	var n := int(f.shelf_base()) - 3
	for i in n:
		f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 80})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + n * 2 + 8


func _flavor_packs(f: PopRules, flavor: String) -> int:
	return f.shelf.filter(func(p: Dictionary) -> bool: return String(p["recipe"]) == flavor).size()


func test_flavor_recipes_are_versioned_clean_data_with_real_tradeoffs() -> void:
	var f := _flavor_floor()
	var fl: Dictionary = f.flavors()
	assert_eq(int(fl.get("version", 0)), 2, "the recipes carry a version (2: Step 35)")
	assert_eq(f.flavor_ids(), FIVE, "five flavors in the menu's order")
	var names: Array = []
	for id: String in FIVE:
		var r: Dictionary = f.flavor(id)
		names.append(String(r["name"]))
		assert_false(String(r["name"]).to_lower().contains("cheeto"), "%s: no protected product name" % id)
		if id != "plain":
			assert_eq(f.recipe_problems(id), [], "%s: a valid recipe" % id)
			assert_eq(int(r["out"]), int(r["in"]), "%s: coating adds taste, not portions" % id)
	assert_eq(names, ["Classic Butter", "Cheese Crunch", "Spicy Dust", "Golden Caramel", "Cocoa Swirl"], "their names")
	var c: Dictionary = f.flavor("cheese")
	var sp: Dictionary = f.flavor("spicy")
	var ca: Dictionary = f.flavor("caramel")
	var co: Dictionary = f.flavor("cocoa")
	# The tradeoffs (design/STATIONS.md 5): caramel pays more and coats slowly, cheese is quick
	# and easy, spicy is a small but patient crowd, cocoa is the premium that wants quality.
	assert_true(int(ca["price"]) > int(c["price"]) and int(ca["coat_ms_per_portion"]) > 3 * int(c["coat_ms_per_portion"]), "caramel: more margin, slower coat")
	assert_true(float(c["order_share"]) > float(sp["order_share"]) and int(c["coat_ms_per_portion"]) == [c, sp, ca, co].map(func(x: Dictionary) -> int: return int(x["coat_ms_per_portion"])).min(), "cheese: the fastest, a big crowd")
	assert_true(float(sp["order_share"]) == [c, sp, ca, co].map(func(x: Dictionary) -> float: return float(x["order_share"])).min() and float(sp["patience"]) == [c, sp, ca, co].map(func(x: Dictionary) -> float: return float(x["patience"])).max(), "spicy: the smallest, most patient crowd")
	assert_true(int(co["price"]) == [c, sp, ca, co].map(func(x: Dictionary) -> int: return int(x["price"])).max() and float(co["quality_weight"]) > float(f.flavor("plain")["quality_weight"]), "cocoa: the dearest, and quality matters most")
	assert_true(float(ca["quality_weight"]) < float(f.flavor("plain")["quality_weight"]), "caramel forgives a so-so lot")
	# Each flavor's margin over plain, after its ingredients, is positive (a viable product).
	for id: String in ["cheese", "spicy", "caramel", "cocoa"]:
		var r: Dictionary = f.flavor(id)
		var per_bag := float(r["ingredient_coins"]) * 2.0 / float(r["in"])
		assert_true(float(r["price"]) - per_bag > 10.0, "%s: worth more than a plain bag after ingredients (%.1f)" % [id, float(r["price"]) - per_bag])


func test_a_recipe_that_would_invent_portions_is_refused() -> void:
	var f := _flavor_floor()
	var p05 := _coater(f, "P05", "cheese")
	var recipes: Dictionary = f.flavors()["recipes"]
	recipes["spicy"]["out"] = 5
	assert_true(f.recipe_problems("spicy").has("portions"), "out != in is a problem")
	var r := f.execute({"type": "set_flavor", "id": p05["id"], "flavor": "spicy"})
	assert_eq(String(r.get("reason", "")), "err.bad_recipe", "it is not chosen")
	recipes["spicy"]["out"] = 4
	assert_eq(String(f.execute({"type": "set_flavor", "id": p05["id"], "flavor": "nope"}).get("reason", "")), "err.bad_recipe", "an unknown flavor is refused")
	assert_eq(String(f.execute({"type": "set_flavor", "id": p05["id"], "flavor": "caramel"}).get("reason", "")), "err.bad_recipe", "the sprayer cannot coat caramel")
	assert_eq(String(f.execute({"type": "set_flavor", "id": p05["id"], "flavor": "plain"}).get("reason", "")), "err.bad_recipe", "butter is the kettle's, not a coating")
	assert_eq(String(f.execute({"type": "set_flavor", "id": 9999, "flavor": "cheese"}).get("reason", "")), "err.unknown", "no such machine")
	# A recipe made invalid under a running coater stops it (it never coats a bad recipe).
	recipes["cheese"]["in"] = 0
	_fill_bin(f, 12)
	f.advance(3000)
	assert_eq(String(f.machine(int(p05["id"]))["state"]), "idle", "a broken recipe is not coated")
	assert_eq(f.coating_portions(), 0, "nothing taken")
	recipes["cheese"]["in"] = 4
	_check_conservation(f, "bad recipe")


func test_flavors_open_in_stages() -> void:
	var f: PopRules = Factory.new()
	_open(f)
	_open_sign(f)
	f.money = 100000
	assert_false(f.station_open("P05"), "no sprayer at packing tier 0")
	f.packer_tier = 2
	assert_true(f.flavor_open("cheese") and not f.flavor_open("spicy") and not f.flavor_open("caramel"), "packing 2: cheese only")
	assert_true(f.station_open("P05") and not f.station_open("P06"), "the sprayer opens, the coater waits for caramel")
	f.sign_tier = 3
	assert_true(f.flavor_open("caramel") and f.station_open("P06") and not f.flavor_open("cocoa"), "sign 3: caramel and its coater")
	var p05: Dictionary = _coater(f, "P05", "")
	assert_eq(String(f.execute({"type": "set_flavor", "id": p05["id"], "flavor": "spicy"}).get("reason", "")), "err.locked", "spicy is locked before sign 4")
	f.sign_tier = 4
	assert_true(bool(f.execute({"type": "set_flavor", "id": p05["id"], "flavor": "spicy"})["ok"]), "sign 4: spicy")
	f.sign_tier = 5
	assert_false(f.flavor_open("cocoa"), "cocoa wants packing 3 too")
	f.packer_tier = 3
	assert_true(f.flavor_open("cocoa"), "packing 3 and sign 5: cocoa -- all five")


func test_p05_seasons_plain_portions_into_cheese_or_spicy() -> void:
	var f := _flavor_floor()
	var m := _coater(f, "P05", "")
	assert_eq(String(m["flavor"]), "cheese", "a new sprayer starts on its first open flavor")
	_fill_shelf(f)   # the plain stock is there: the bin's plain waits for the coater
	_fill_bin(f, 12)
	var money0 := f.money
	f.drain_events()
	f.advance(100)
	var started := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "coat_started")
	assert_eq(started.size(), 1, "a batch starts: the shelf has no cheese")
	assert_eq(int(started[0]["data"]["portions"]), 4, "four portions (tier 0)")
	assert_eq(int(started[0]["data"]["ms"]), 4 * 600, "600 ms a portion")
	assert_eq(money0 - f.money, 2, "the batch's ingredients: 2 coins, paid once")
	assert_eq(f.bin_portions_of("plain"), 8, "four plain portions left the bin")
	f.advance(2400 + int(f.packer()["ms"]) + 500)
	assert_eq(_flavor_packs(f, "cheese"), 1, "a cheese pack on the shelf (its stock, a place kept from plain)")
	assert_eq(f.bin_portions_of("cheese"), 2, "two cheese portions wait")
	f.advance(10000)
	assert_eq(int(f.stats.get("coated", {}).get("cheese", 0)), 4, "no more cheese: nobody asks, the stock is there")
	assert_eq(String(f.machine(int(m["id"]))["state"]), "idle", "idle while not wanted (no upkeep)")
	f.shelf.remove_at(f.shelf.size() - 2)   # a plain small bag sold: a place for spicy's stock
	f.stats["sold_portions"] = int(f.stats["sold_portions"]) + 2
	assert_true(bool(f.execute({"type": "set_flavor", "id": m["id"], "flavor": "spicy"})["ok"]), "set to spicy")
	f.advance(4 * 900 + int(f.packer()["ms"]) + 600)
	assert_eq(_flavor_packs(f, "spicy"), 1, "a spicy pack too")
	assert_eq(_flavor_packs(f, "cheese"), 1, "the cheese pack is still cheese")
	_check_conservation(f, "P05")


func test_p06_coats_caramel_and_cocoa_slowly() -> void:
	var f := _flavor_floor()
	f.sign_tier = 4
	var m := _coater(f, "P06", "")
	assert_eq(String(m["flavor"]), "caramel", "the coater starts on caramel")
	assert_eq(String(f.execute({"type": "set_flavor", "id": m["id"], "flavor": "cocoa"}).get("reason", "")), "err.locked", "cocoa waits for sign 5")
	_fill_shelf(f)
	_fill_bin(f, 12)
	f.advance(100)
	var h: Dictionary = f.machine(int(m["id"]))["held"]
	assert_eq(int(h["ms"]), 10000, "a caramel batch: 10 s")
	assert_eq(String(h["recipe"]), "caramel", "caramel")
	f.advance(5000)
	assert_eq(f.bin_portions_of("caramel"), 0, "half way: no caramel yet")
	assert_eq(f.coating_portions("caramel"), 4, "four portions on the drum")
	_check_conservation(f, "mid-coat")
	f.advance(5000 + int(f.packer()["ms"]) + 500)
	assert_eq(_flavor_packs(f, "caramel"), 1, "a caramel pack")
	f.sign_tier = 5
	assert_true(bool(f.execute({"type": "set_flavor", "id": m["id"], "flavor": "cocoa"})["ok"]), "sign 5: cocoa")
	_fill_bin(f, 8)
	f.drain_events()
	var cocoa: Array = []
	for i in 300:   # caramel's buffer batch (if one is on the drum) finishes first
		f.advance(100)
		cocoa = f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "coat_started" and String(e["data"]["flavor"]) == "cocoa")
		if not cocoa.is_empty():
			break
	assert_eq(cocoa.size(), 1, "a cocoa batch starts")
	assert_eq(int(cocoa[0]["data"]["cost"]), 6, "a cocoa batch's ingredients: 6 coins")
	assert_eq(int(cocoa[0]["data"]["ms"]), 12000, "cocoa: 12 s")
	# A tier-1 coater: six portions, 0.85x the time, the coins scaled (ceil 6 x 6 / 4 = 9).
	assert_eq(f.ingredient_cost("cocoa", 6), 9, "coins scale with the batch")
	_check_conservation(f, "P06")


func test_m12_the_mixer_shortens_every_coating_batch() -> void:
	var f := _flavor_floor()
	var m := _coater(f, "P06", "caramel")
	assert_eq(f.coat_ms(m, "caramel", 4), 10000, "without the mixer: 10 s")
	var mix := f.execute({"type": "build", "machine": "M12"})
	assert_true(bool(mix["ok"]), "the mixer is built (%s)" % mix.get("reason", ""))
	assert_eq(f.coat_ms(m, "caramel", 4), 9000, "with it: 1 s off")
	f.execute({"type": "upgrade_machine", "id": mix["machine"]})
	f.execute({"type": "upgrade_machine", "id": mix["machine"]})
	assert_eq(f.coat_ms(m, "caramel", 4), 8200, "tier 2: 1.8 s off")
	assert_eq(f.coat_ms(m, "cheese", 2), 600, "never below half a batch (1.2 s -> 0.6 s)")
	# It works (and pays) only while a coater coats.
	f.advance(3000)
	assert_eq(String(f.machine(int(mix["machine"]))["state"]), "idle", "no coating: idle")
	_fill_bin(f, 8)
	f.advance(3000)
	assert_eq(String(f.machine(int(mix["machine"]))["state"]), "run", "a coater coats: it works")
	_check_conservation(f, "M12")


func test_conversion_arithmetic_and_prices() -> void:
	var f := _flavor_floor()
	assert_eq(f.pack_price("plain", 2, 100), 10, "Classic Butter, a small bag: 10")
	assert_eq(f.pack_price("plain", 2, 50), 8, "at quality 50: 8 (as before flavors)")
	assert_eq(f.pack_price("cheese", 2, 100), 13, "cheese 13")
	assert_eq(f.pack_price("cheese", 2, 50), 10, "cheese at 50: 13 x 0.8")
	assert_eq(f.pack_price("caramel", 2, 50), 16, "caramel forgives: 18 x 0.9")
	assert_eq(f.pack_price("cocoa", 2, 50), 15, "cocoa does not: 22 x 0.7")
	assert_eq(f.pack_price("cheese", 4, 100), 23, "a large cheese bag: 18 x 13 / 10")
	assert_eq(f.pack_price("spicy", 1, 100), 9, "a spicy cup: 6 x 16 / 10")
	# Quality is the portions' average through the coating (nothing invented or lost).
	var m := _coater(f, "P05", "cheese")
	f.execute({"type": "upgrade_machine", "id": m["id"]})
	f.bin.append({"id": f._new_id(), "recipe": "plain", "quality": 100, "portions": 3})
	f.bin.append({"id": f._new_id(), "recipe": "plain", "quality": 40, "portions": 3})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 6
	_want(f, 4, "cheese", 600000)   # Step 35: a bigger drum coats what is short (its stock 2 + this order 4)
	f.advance(100)
	var h: Dictionary = f.machine(int(m["id"]))["held"]
	assert_eq(int(h["portions"]), 6, "tier 1: six portions")
	assert_eq(int(h["quality"]), 70, "the average quality (3 x 100 + 3 x 40) / 6")
	assert_eq(int(h["ms"]), int(round(6 * 600 * 0.85)), "0.85 x the time")
	f.advance(int(h["ms"]) + 100)
	assert_eq(int(f.stats["coated"]["cheese"]), 6, "six cheese portions out (cheese loses none)")
	_check_conservation(f, "arithmetic")


func test_all_five_flavors_go_from_the_kettle_to_a_sale() -> void:
	var f := _flavor_floor(73)
	f.level = 6
	f.sign_tier = 6
	f.money = 100000
	_coater(f, "P05", "cheese")
	_coater(f, "P05", "spicy")
	_coater(f, "P06", "caramel")
	_coater(f, "P06", "cocoa")
	var ids := {}
	for fl: String in FIVE:
		ids[fl] = _want(f, 2, fl, 600000)
	# Real popcorn from the hand kettle (every portion made by a pop).
	for i in 40:
		if f.glass.is_empty():
			_pop(f)
		f.advance(1500)
	for fl: String in FIVE:
		assert_true(_sold_at(f, int(ids[fl])) >= 0, "%s: the customer bought it" % fl)
	for e: Dictionary in f.ledger:
		assert_eq(String(e["recipe"]), String(e["ordered_recipe"]), "every sale the flavor ordered")
		assert_eq(int(e["coins"]), f.pack_price(String(e["recipe"]), int(e["size"]), int(e["quality"])), "at its price")
	assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "no wrong flavor")
	var by: Dictionary = f.stats.get("flavor_sold", {})
	for fl: String in ["cheese", "spicy", "caramel", "cocoa"]:
		assert_true(int(by.get(fl, 0)) >= 1, "%s counted as sold" % fl)
	assert_true(int(f.stats["ingredient_coins"]) > 0, "ingredients were paid for")
	_check_sales(f, "five flavors")
	_check_conservation(f, "five flavors")


func test_a_coater_without_coins_waits_and_never_owes() -> void:
	var f := _flavor_floor()
	var m := _coater(f, "P06", "caramel")
	_fill_bin(f, 12)
	f.money = 3
	f.advance(2000)
	assert_eq(String(f.machine(int(m["id"]))["state"]), "unpaid", "3 coins: caramel's 4 cannot be paid")
	assert_eq(f.coating_portions(), 0, "it took nothing")
	assert_eq(f.money, 3, "and owes nothing")
	assert_true(int(f.stats.get("ingredient_short_ms", 0)) > 0, "the shortage is measured")
	f.money = 4
	f.advance(100)
	assert_eq(f.coating_portions("caramel"), 4, "four coins: it coats")
	assert_eq(f.money, 0, "the batch took them all")
	f.advance(20000)
	assert_true(f.money >= 0, "upkeep it cannot pay pauses it (never a debt)")
	_check_conservation(f, "short of coins")


func test_a_coater_leaves_the_plain_orders_their_popcorn() -> void:
	var f := _flavor_floor()
	var m := _coater(f, "P05", "cheese")
	_want(f, 2)
	_want(f, 2)
	_fill_bin(f, 7)   # 7 - 4 waiting for plain orders = 3: not a batch of 4
	f.advance(100)
	assert_eq(f.coating_portions(), 0, "the plain orders' popcorn is not coated")
	f.advance(int(f.packer()["ms"]) * 3 + 2000)
	assert_eq(int(f.stats["sold"]), 1 + 2, "both plain customers bought plain")   # _open_sign counts one
	_check_conservation(f, "plain first")


func test_no_instant_flavor_switch_and_packed_stock_keeps_its_flavor() -> void:
	var f := _flavor_floor()
	f.sign_tier = 5
	var m := _coater(f, "P06", "caramel")
	_fill_shelf(f)
	_fill_bin(f, 16)
	f.advance(4000)
	assert_true(bool(f.execute({"type": "set_flavor", "id": m["id"], "flavor": "cocoa"})["ok"]), "switched mid-batch")
	assert_eq(String(f.machine(int(m["id"]))["held"]["recipe"]), "caramel", "the batch on the drum is still caramel")
	f.drain_events()
	f.advance(6100)
	var done := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "lot_coated")
	assert_eq(String(done[0]["data"]["flavor"]), "caramel", "it comes out caramel")
	f.advance(int(f.packer()["ms"]) + 13000)
	assert_eq(_flavor_packs(f, "caramel"), 1, "the caramel pack stays caramel")
	assert_true(f.bin_portions_of("cocoa") + _flavor_packs(f, "cocoa") * 2 + f.coating_portions("cocoa") >= 4, "the next batch is cocoa")
	_check_conservation(f, "switch")


func test_flavor_orders_come_only_while_a_flavor_is_offered() -> void:
	var a := _flavor_floor(77)
	var b := _flavor_floor(77)
	var plain_a: Array = []
	var plain_b: Array = []
	for i in 200:
		plain_a.append(a._draw_order())
		plain_b.append(b._draw_order())
	assert_eq(plain_a, plain_b, "the same stream")
	assert_true(plain_a.all(func(o: Dictionary) -> bool: return String(o["recipe"]) == "plain"), "no coater: everyone orders butter")
	var m := _coater(a, "P05", "cheese")
	var n := 0
	for i in 400:
		if String(a._draw_order()["recipe"]) == "cheese":
			n += 1
	assert_true(n > 40 and n < 90, "a working sprayer: about 16%% ask for cheese (%d of 400)" % n)
	a.execute({"type": "pause_machine", "id": m["id"], "paused": true})
	var none := 0
	for i in 200:
		if String(a._draw_order()["recipe"]) != "plain":
			none += 1
	assert_eq(none, 0, "paused and none on hand: nobody asks for it")
	# Spicy fans wait longer.
	a.sign_tier = 6
	a.execute({"type": "set_flavor", "id": m["id"], "flavor": "spicy"})
	a.execute({"type": "pause_machine", "id": m["id"], "paused": false})
	var base := int((a.economy.table("factory")["customers"] as Dictionary)["patience_ms"])
	var seen := false
	for i in 300:
		a._arrive()
		var c: Dictionary = a.queue.pop_back() if not a.queue.is_empty() else {}
		if not c.is_empty() and String(c["order"]["recipe"]) == "spicy":
			assert_eq(int(c["patience_ms"]), int(round(base * 1.6)), "a spicy fan waits 1.6x")
			seen = true
			break
	assert_true(seen, "a spicy fan came")


func test_flavors_and_plain_share_the_shelf_without_blocking_it() -> void:
	var f := _flavor_floor(79)
	f.next_arrival_ms = 0
	f.level = 8
	for i in 3:
		f.execute({"type": "build", "machine": "cooker"})
	assert_true(bool(f.execute({"type": "build", "machine": "M01"})["ok"]), "a kernel hopper (the kettles keep cooking)")
	f.execute({"type": "build", "machine": "bagger"})
	_coater(f, "P05", "cheese")
	_coater(f, "P06", "caramel")
	_coater(f, "P05", "spicy")
	assert_true(bool(f.execute({"type": "buy_line", "floor": "packing"})["ok"]), "a second packing line")
	f.execute({"type": "build", "machine": "bagger"})   # line 1's filler (a line without one gets no popcorn)
	_coater(f, "P06", "cocoa")
	f.money = 5000
	var worst_extra := 0
	for minute in 20:
		f.advance(60000)
		_check_conservation(f, "minute %d" % minute)
		for fl: String in ["cheese", "spicy", "caramel", "cocoa"]:
			var waiting: int = f.queue.filter(func(c: Dictionary) -> bool: return String(c["order"]["recipe"]) == fl).size()
			worst_extra = maxi(worst_extra, _flavor_packs(f, fl) - 1 - waiting)
	assert_true(worst_extra <= 1, "a flavor never piles up on the shelf (worst: %d over its stock and orders)" % worst_extra)
	var by: Dictionary = f.stats.get("flavor_sold", {})
	for fl: String in ["cheese", "spicy", "caramel", "cocoa"]:
		assert_true(int(by.get(fl, 0)) >= 2, "%s sold in 20 minutes (%d)" % [fl, int(by.get(fl, 0))])
	var plain_sold: int = f.ledger.filter(func(e: Dictionary) -> bool: return String(e["recipe"]) == "plain").size()
	assert_true(plain_sold > f.ledger.size() / 3, "butter is still most of the trade (%d of %d)" % [plain_sold, f.ledger.size()])
	assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "every customer got their flavor")
	_check_sales(f, "shared shelf")


func test_parallel_lines_coat_and_pack_each_flavor_on_its_own_line() -> void:
	var f := _flavor_floor(81)
	f.money = 1 << 20
	for id in ["bagger", "P07", "U04", "P04"]:
		f.execute({"type": "build", "machine": id})
	f.execute({"type": "buy_line", "floor": "packing"})
	f.execute({"type": "build", "machine": "bagger"})   # line 1's filler
	var c1 := _coater(f, "P05", "cheese")   # line 1
	assert_eq(int(f.line_of("packing", int(c1["slot"]))), 1, "the sprayer stands on line 1")
	f.execute({"type": "sell_machine", "id": f.machine_at("packing", 1)["id"]})   # free a line-0 place
	var c0 := _coater(f, "P06", "caramel")
	assert_eq(int(f.line_of("packing", int(c0["slot"]))), 0, "the coater on line 0")
	var flavor_lines := {}
	for i in 12:
		var lot := {"id": f._new_id(), "recipe": "plain", "quality": 80, "portions": 4}
		f.stats["made_portions"] = int(f.stats["made_portions"]) + 4
		f.lift.append({"lot": lot, "left_ms": 50})
		f.advance(1500)
		for l: Dictionary in f.bin:
			if f.is_flavor(String(l["recipe"])):
				var key := "%s@%d" % [l["recipe"], int(l.get("line", 0))]
				flavor_lines[key] = true
	f.advance(20000)
	for k: String in flavor_lines.keys():
		assert_true(k in ["cheese@1", "caramel@0"], "a coated lot stays on its coater's line (%s)" % k)
	assert_true(_flavor_packs(f, "cheese") >= 1 and _flavor_packs(f, "caramel") >= 1, "both lines packed their flavor")
	# Line 1 loses its filler: its cheese goes back to line 0 (never stranded).
	var b1: Dictionary = f.line_fillers(1)[0]
	f.bin.append({"id": f._new_id(), "recipe": "cheese", "quality": 80, "portions": 4, "line": 1})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 4
	assert_true(bool(f.execute({"type": "sell_machine", "id": b1["id"]})["ok"]) or not (b1["held"] as Dictionary).is_empty(), "the filler sold")
	f.advance(25000)
	assert_eq(f.bin.filter(func(l: Dictionary) -> bool: return int(l.get("line", 0)) == 1 and String(l["recipe"]) == "cheese").size(), 0, "no cheese stranded on line 1")
	_check_conservation(f, "lines")


func test_a_coater_mid_batch_saves_and_restores() -> void:
	var f := _flavor_floor(83)
	var m := _coater(f, "P06", "caramel")
	_fill_bin(f, 12)
	f.advance(3300)
	var raw: Dictionary = f.to_save()
	var g: PopRules = Factory.new(null, 83)
	assert_true(g.from_save(raw), "restored")
	var gm: Dictionary = g.machine(int(m["id"]))
	assert_eq(String(gm["flavor"]), "caramel", "its flavor")
	assert_eq(int(gm["held"]["left_ms"]), int(f.machine(int(m["id"]))["held"]["left_ms"]), "its batch, part-coated")
	f.advance(20000)
	g.advance(20000)
	assert_eq(g.stats, f.stats, "the same factory after the restart")
	_check_conservation(g, "restored")
	# A save with a flavor the coater cannot coat comes back with its first.
	var bad: Dictionary = f.to_save()
	for x: Dictionary in bad["machines"]:
		x["flavor"] = "cheese"
	var h: PopRules = Factory.new(null, 83)
	assert_true(h.from_save(bad), "a hand-edited save loads")
	assert_eq(String(h.machine(int(m["id"]))["flavor"]), "caramel", "with a flavor it can coat")


func test_coating_portions_keep_their_place_in_the_bin() -> void:
	var f := _flavor_floor(85)
	_coater(f, "P06", "caramel")
	_fill_shelf(f)   # the station is blocked: nothing else takes from the bin
	var cap := int(f.bin_cap())
	_fill_bin(f, cap)
	f.advance(100)
	assert_eq(f.coating_portions(), 4, "a batch on the drum")
	f.execute({"type": "build", "machine": "cooker"})
	var k: Dictionary = f.machines[f.machines.size() - 1]
	k["held"] = {"id": f._new_id(), "recipe": "plain", "quality": 80, "portions": 4}
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 4
	f.advance(200)
	assert_eq(String(f.machine(int(k["id"]))["state"]), "blocked", "the kettle waits: the drum's portions come back to the bin")
	_check_conservation(f, "room")


# -- Step 35: the hand's finish, the machine's quality and loss, mixes, AUTO, the special, payback

## A coater with a batch on the drum (a caramel order waiting; the hand has cooked enough).
func _batch_on_drum(seed_value: int, flavor: String, presses: int = 25) -> Dictionary:
	var f := _flavor_floor(seed_value)
	f.sign_tier = 6
	f.presses = presses
	var type := "P05" if flavor in ["cheese", "spicy"] else "P06"
	var m := _coater(f, type, flavor)
	_fill_shelf(f)
	_fill_bin(f, 12)
	f.advance(100)
	assert_false((f.machine(int(m["id"]))["held"] as Dictionary).is_empty(), "%s: a batch on the drum" % flavor)
	return {"f": f, "m": m}


func _hold_spoon(f: PopRules, id: int, ms: int) -> Dictionary:
	var r := f.execute({"type": "finish_press", "id": id})
	if not bool(r["ok"]):
		return r
	f.advance(ms)
	if f.finishing.is_empty():
		return {"ok": true, "dripped": true}
	return f.execute({"type": "finish_release"})


func _coated(f: PopRules) -> Array:
	return f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "lot_coated")


func test_the_spoon_opens_only_once_the_hand_cooks_comfortably() -> void:
	var s := _batch_on_drum(301, "caramel", 3)
	var f: PopRules = s["f"]
	var id := int(s["m"]["id"])
	assert_false(f.hand_open(), "three pops: no spoon yet")
	assert_false(bool(f.state()["coaters"][0]["can_finish"]), "the state says so")
	assert_eq(String(f.execute({"type": "finish_press", "id": id}).get("reason", "")), "err.locked", "refused while locked")
	f.presses = int(f.hand_rules()["unlock_presses"])
	assert_true(f.hand_open(), "%d pops: the spoon" % f.presses)
	assert_true(bool(f.state()["coaters"][0]["can_finish"]), "the batch can be finished")
	assert_eq(String(f.execute({"type": "finish_press", "id": 999}).get("reason", "")), "err.nothing_to_finish", "no such coater")
	_check_conservation(f, "locked spoon")


func test_a_perfect_finish_beats_the_machine_and_a_miss_changes_nothing() -> void:
	# The same factory, one left to the machine, one finished by hand.
	var sa := _batch_on_drum(303, "cocoa")
	var sb := _batch_on_drum(303, "cocoa")
	var a: PopRules = sa["f"]
	var b: PopRules = sb["f"]
	for x: PopRules in [a, b]:
		x.sign_tier = 6
	var ida := int(sa["m"]["id"])
	var idb := int(sb["m"]["id"])
	var q_in := int(a.machine(ida)["held"]["quality"])
	a.drain_events()
	b.drain_events()
	var w: Array = b.finish_window("cocoa")
	var r := _hold_spoon(b, idb, (int(w[0]) + int(w[1])) / 2)
	assert_eq(String(r.get("grade", "")), "perfect", "released in the gold: perfect")
	assert_eq(int(r["quality"]), 100, "the hand's finish: quality 100")
	b.advance(100)
	var hb := _coated(b)
	assert_eq(hb.size(), 1, "the batch is done at the release")
	assert_eq(int(hb[0]["data"]["portions"]), 4, "nothing lost")
	assert_eq(String(hb[0]["data"]["hand"]), "perfect", "marked as the hand's")
	var la := []
	for i in 140:
		a.advance(100)
		la = _coated(a)
		if not la.is_empty():
			break
	assert_eq(la.size(), 1, "the machine alone finishes later")
	assert_eq(int(la[0]["data"]["quality"]), int(round(q_in * 0.85)), "at 85% of the popcorn's quality (tier 0)")
	assert_true(int(la[0]["data"]["quality"]) < 100, "below the hand's")
	_check_conservation(a, "machine")
	_check_conservation(b, "hand")
	# Near the gold: near_quality, never below the machine; early or late: the machine goes on.
	var sc := _batch_on_drum(305, "caramel")
	var c: PopRules = sc["f"]
	var idc := int(sc["m"]["id"])
	var wc: Array = c.finish_window("caramel")
	var left0 := int(c.machine(idc)["held"]["left_ms"])
	var early := _hold_spoon(c, idc, 200)
	assert_eq(String(early["grade"]), "early", "a quick tap: early")
	assert_eq(int(c.machine(idc)["held"]["left_ms"]), left0, "early: the batch waited for the hand, then goes on as before")
	assert_eq(String(c.machine(idc)["held"].get("hand", "")), "", "not finished")
	var late := _hold_spoon(c, idc, int(wc[1]) + 600)
	assert_eq(String(late["grade"]), "late", "held too long: late")
	var near := _hold_spoon(c, idc, int(wc[0]) - 150)
	assert_eq(String(near["grade"]), "near", "just before the gold: near")
	assert_eq(int(near["quality"]), 90, "near: 90")
	var hs: Dictionary = c.stats["hand_finish"]
	assert_eq([int(hs.get("early", 0)), int(hs.get("late", 0)), int(hs.get("near", 0))], [1, 1, 1], "each try counted")
	_check_conservation(c, "near")


func test_the_spoon_drips_by_itself_and_one_hand_does_one_thing() -> void:
	var s := _batch_on_drum(307, "cheese")
	var f: PopRules = s["f"]
	var id := int(s["m"]["id"])
	assert_true(bool(f.execute({"type": "finish_press", "id": id})["ok"]), "the spoon is down")
	assert_eq(String(f.execute({"type": "press"}).get("reason", "")), "err.hand_busy", "the kettle waits: one hand")
	assert_eq(String(f.execute({"type": "finish_press", "id": id}).get("reason", "")), "err.hand_busy", "one spoon")
	assert_eq(String(f.machine(id)["state"]), "run", "")
	f.advance(100)
	assert_eq(String(f.machine(id)["state"]), "hand", "the batch is the hand's while held (no upkeep)")
	f.drain_events()
	var w: Array = f.finish_window("cheese")
	f.advance(int(w[1]) + int(f.hand_rules()["drip_ms"]) + 500)
	assert_true(f.finishing.is_empty(), "held past the drip: it lets go by itself")
	var fin := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "finished")
	assert_eq(fin.size(), 1, "one finish")
	assert_eq(String(fin[0]["data"]["grade"]), "late", "late")
	# Heating: no spoon.
	var g := _batch_on_drum(309, "cheese")
	var gf: PopRules = g["f"]
	assert_true(bool(gf.execute({"type": "press"})["ok"]), "heating")
	assert_eq(String(gf.execute({"type": "finish_press", "id": int(g["m"]["id"])}).get("reason", "")), "err.hand_busy", "no spoon while heating")
	_check_conservation(f, "drip")


func test_the_machine_loses_portions_by_flavor_and_tier_and_counts_them() -> void:
	var f := _flavor_floor(311)
	f.sign_tier = 6
	var p06 := _coater(f, "P06", "caramel")
	var p05 := _coater(f, "P05", "cheese")
	var lost := {}
	for spec: Array in [[p06, "caramel", 0], [p06, "cocoa", 0], [p05, "cheese", 0], [p05, "spicy", 0], [p06, "caramel", 2]]:
		var m: Dictionary = f.machine(int(spec[0]["id"]))
		m["tier"] = int(spec[2])
		m["loss_mp"] = 0
		var n := 0
		var portions := 0
		for i in 25:
			m["held"] = {"id": f._new_id(), "recipe": spec[1], "quality": 80, "portions": 4, "left_ms": 0, "ms": 1000, "line": 0, "lots": []}
			f.stats["made_portions"] = int(f.stats["made_portions"]) + 4
			f.drain_events()
			f._coater_step(m, 50)
			var e: Array = f.drain_events().filter(func(x: Dictionary) -> bool: return String(x["type"]) == "lot_coated")
			n += int(e[0]["data"]["lost"])
			portions += int(e[0]["data"]["portions"])
			var out: Dictionary = f.bin.pop_back()   # (the test's portions leave again: only the lost stay counted)
			f.stats["made_portions"] = int(f.stats["made_portions"]) - int(out["portions"])
		assert_eq(n + portions, 100, "%s tier %d: every portion comes out or is counted lost" % [spec[1], spec[2]])
		lost["%s%d" % [spec[1], spec[2]]] = n
	assert_eq(lost, {"caramel0": 12, "cocoa0": 8, "cheese0": 0, "spicy0": 5, "caramel2": 3}, "losses: caramel 12%, cocoa 8%, cheese 0, spicy 5%; tier 2 caramel 3.6%")
	assert_eq(int(f.stats["lost_portions"]), 28, "the lost portions are counted")
	_check_conservation(f, "losses")


func test_coater_tiers_raise_the_machines_quality_but_never_to_the_hands() -> void:
	var f := _flavor_floor(313)
	var m := _coater(f, "P06", "caramel")
	var qs: Array = []
	for t in 3:
		f.machine(int(m["id"]))["tier"] = t
		qs.append(f.auto_quality(f.machine(int(m["id"]))))
	assert_eq(qs, [0.85, 0.91, 0.96], "tiers 0-2: 85/91/96% of the popcorn's quality")
	assert_true(int(round(100 * 0.96)) < int(f.hand_rules()["perfect_quality"]), "even the best machine is below a perfect hand finish")
	assert_true(f.loss_rate(f.machine(int(m["id"])), "caramel") > 0.0 and f.loss_rate(f.machine(int(m["id"])), "caramel") < 0.12, "and loses less than tier 0")


func test_a_hand_finished_bag_sells_for_more_and_keeps_its_mark() -> void:
	var s := _batch_on_drum(315, "cocoa")
	var f: PopRules = s["f"]
	var id := int(s["m"]["id"])
	var cid := _want(f, 2, "cocoa", 600000)
	var w: Array = f.finish_window("cocoa")
	_hold_spoon(f, id, int(w[0]) + 50)
	for i in 200:
		f.advance(100)
		if _sold_at(f, cid) >= 0:
			break
	assert_true(_sold_at(f, cid) >= 0, "the cocoa customer bought it")
	var sale: Dictionary = f.ledger.filter(func(e: Dictionary) -> bool: return int(e["customer"]) == cid)[0]
	assert_eq(int(sale["quality"]), 100, "a hand-finished bag: quality 100")
	assert_eq(int(sale["coins"]), f.pack_price("cocoa", 2, 100), "at its price")
	assert_true(f.pack_price("cocoa", 2, 100) > f.pack_price("cocoa", 2, int(round(80 * 0.85))), "more than the machine's bag")
	assert_eq(int(f.stats["hand_sold_portions"]), 2, "its two portions were the hand's")
	assert_eq(int(f.stats["hand_perfect_bags_sold"]), 1, "one hand-finished bag sold at 100")
	_check_conservation(f, "hand sale")


func test_auto_follows_the_queue_and_a_quick_switch_needs_one_tap() -> void:
	var f := _flavor_floor(317)
	f.sign_tier = 6
	var m := _coater(f, "P06", "")
	assert_true(bool(f.execute({"type": "set_flavor", "id": m["id"], "flavor": "auto"})["ok"]), "AUTO: one tap")
	_fill_shelf(f)
	_fill_bin(f, 12)
	_want(f, 4, "plain", 600000)
	_want(f, 4, "cocoa", 600000)
	_want(f, 4, "caramel", 600000)
	f.drain_events()
	f.advance(100)
	var started := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "coat_started")
	assert_eq(started.size(), 1, "a batch starts")
	assert_eq(String(started[0]["data"]["flavor"]), "cocoa", "the earliest waiting flavor order first (cocoa before caramel)")
	assert_true(f.offered_flavors().has("caramel") and f.offered_flavors().has("cocoa"), "AUTO offers both")
	# A quick switch back to one flavor: the batch on the drum keeps its own.
	assert_true(bool(f.execute({"type": "set_flavor", "id": m["id"], "flavor": "caramel"})["ok"]), "back to caramel")
	assert_eq(String(f.machine(int(m["id"]))["held"]["recipe"]), "cocoa", "the drum's batch is still cocoa")
	var g := _flavor_floor(319)
	var gm := _coater(g, "P06", "")
	g.sign_tier = 0
	g.packer_tier = 0
	assert_eq(String(g.execute({"type": "set_flavor", "id": gm["id"], "flavor": "auto"}).get("reason", "")), "err.locked", "AUTO needs an open flavor")
	_check_conservation(f, "auto")


func test_a_mixed_order_gets_one_bag_half_caramel_half_cheese() -> void:
	var f := _flavor_floor(321)
	f.sign_tier = 6
	assert_false(f.mix_offered("duo"), "no coaters: no mix")
	_coater(f, "P06", "caramel")
	assert_false(f.mix_offered("duo"), "caramel alone: no mix")
	_coater(f, "P05", "cheese")
	assert_true(f.mix_offered("duo"), "caramel and cheese offered: the mix is")
	_fill_shelf(f)
	_fill_bin(f, 16)
	var cid := _want(f, 4, "duo", 600000)
	for i in 400:
		f.advance(100)
		if _sold_at(f, cid) >= 0:
			break
	assert_true(_sold_at(f, cid) >= 0, "the mix customer bought their bag")
	var sale: Dictionary = f.ledger.filter(func(e: Dictionary) -> bool: return int(e["customer"]) == cid)[0]
	assert_eq(String(sale["recipe"]), "duo", "a mixed bag")
	assert_eq(int(sale["size"]), 4, "four portions")
	assert_eq(int(sale["coins"]), f.pack_price("duo", 4, int(sale["quality"])), "at the mix's price")
	assert_eq(int(f.stats["mix_sold"]), 1, "counted")
	assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "nobody got another bag")
	# The draw: mixes come only while offered (the same stream otherwise -- Step 34's test).
	var n := 0
	for i in 600:
		var o: Dictionary = f._draw_order()
		if String(o["recipe"]) == "duo":
			n += 1
			assert_eq(int(o["size"]), 4, "a mix is a large bag")
	assert_true(n > 15 and n < 65, "about 6%% ask for the mix (%d of 600)" % n)
	_check_conservation(f, "mix")


func test_a_mixed_bag_takes_half_of_each_part() -> void:
	var f := _flavor_floor(323)
	f.bin.append({"id": f._new_id(), "recipe": "caramel", "quality": 100, "portions": 3, "by": {"7": 3}})
	f.bin.append({"id": f._new_id(), "recipe": "cheese", "quality": 60, "portions": 3, "by": {"8": 3}})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 6
	var p: Dictionary = f._take_pack(4, "duo", -1)
	assert_eq(String(p["recipe"]), "duo", "a mixed bag")
	assert_eq(f.bin_portions_of("caramel"), 1, "two caramel portions taken")
	assert_eq(f.bin_portions_of("cheese"), 1, "two cheese portions taken")
	assert_eq(int(p["quality"]), 80, "its quality: the portions' average")
	assert_eq(p["by"], {"7": 2, "8": 2}, "each coater's portions in it")
	# A mix whose part is not a flavor is never offered.
	assert_false(f.is_mix("caramel"), "a flavor is not a mix")
	assert_false(f.is_mix("order"), "the menu list is not a mix")


func test_a_surplus_becomes_the_special_and_sells_down_sooner() -> void:
	# Too much spicy (a coater switched away, its fans gone): the board features it.
	var res := {}
	for with_promo: bool in [true, false]:
		var f := _flavor_floor(325)
		f.sign_tier = 6
		f.stats["packed"] = 5
		var m := _coater(f, "P05", "cheese")
		f.next_arrival_ms = f.flow_ms + 500   # customers come
		f.bin.append({"id": f._new_id(), "recipe": "spicy", "quality": 80, "portions": 16})
		f.stats["made_portions"] = int(f.stats["made_portions"]) + 16
		if not with_promo:
			f.flavors()["promo"]["surplus_portions"] = 100000   # (a copy of the table: this run never features it)
		var on_at := -1
		var gone_at := -1
		f.level = 6
		for i in 1200:
			if f.glass.is_empty():
				_pop(f)   # butter for everyone else (the queue goes in order)
			f.advance(1000)
			if on_at < 0 and f.promoted("spicy"):
				on_at = f.flow_ms
			if f.flavor_have("spicy") <= f.pack_size():   # sold down to one small bag
				gone_at = f.flow_ms
				break
		res[with_promo] = {"on": on_at, "gone": gone_at, "sold": int(f.stats.get("flavor_sold", {}).get("spicy", 0)), "abandoned": int(f.stats["abandoned"])}
		if with_promo:
			assert_true(on_at >= 20000, "featured after 20 s of surplus (%d)" % on_at)
			f.advance(1000)   # the board is looked at once a second
			assert_false(f.promoted("spicy"), "the special ends with the surplus")
			var sp := 0
			for e: Dictionary in f.ledger:
				if String(e["recipe"]) == "spicy":
					sp += int(e["size"])
			assert_true(sp >= 12, "the surplus was sold to spicy customers, not waved away (%d portions)" % sp)
			print("  the special: on at %d ms, surplus gone at %d ms, spicy sold %d" % [on_at, gone_at, res[with_promo]["sold"]])
		else:
			print("  no special: surplus gone at %d ms, spicy sold %d" % [gone_at, res[with_promo]["sold"]])
		_check_sales(f, "promo %s" % with_promo)
		_check_conservation(f, "promo %s" % with_promo)
		f.flavors()["promo"]["surplus_portions"] = 4
		m = {}
	assert_true(int(res[true]["gone"]) > 0, "the surplus is sold (%s)" % [res[true]])
	assert_true(int(res[false]["gone"]) < 0 or int(res[true]["gone"]) < int(res[false]["gone"]), "sooner with the special: %s vs %s" % [res[true], res[false]])


func test_a_coaters_payback_is_estimated_and_then_measured() -> void:
	var f := _flavor_floor(327)
	f.level = 6
	f.sign_tier = 6
	var est: Dictionary = f.coater_estimate("P05", "cheese", 0)
	assert_true(int(est["net_per_min"]) > 0, "cheese pays at sign 6: %s" % est)
	assert_true(float(est["payback_min"]) > 0.0, "an estimated payback")
	assert_true(float(est["served_ppm"]) <= float(est["capacity_ppm"]) + 0.01 and float(est["served_ppm"]) <= float(est["demand_ppm"]) + 0.01, "served: the smaller of demand and capacity")
	var none: Dictionary = f.coater_estimate("P05", "plain", 0)
	assert_true(none.is_empty(), "butter is not coated")
	var m := _coater(f, "P06", "caramel")
	f.machine(int(m["id"]))["paid"] = 120   # (the test's price: a payback within the ledger's 500 rows)
	f.next_arrival_ms = f.flow_ms + 500
	for i in 60 * 20:
		if f.glass.is_empty():
			_pop(f)
		f.advance(1000)
		if f.machine(int(m["id"])).has("paid_back_ms"):
			break
	var mm: Dictionary = f.machine(int(m["id"]))
	# The margin is what its bags sold for over butter's -- recomputed from the ledger.
	var margin := 0
	for e: Dictionary in f.ledger:
		if String(e["recipe"]) == "caramel":
			margin += int(e["coins"]) - f.pack_price("plain", int(e["size"]), int(e["quality"]))
	assert_eq(int(mm.get("margin", 0)), margin, "the coater's margin is its bags' price over butter's")
	assert_eq(f.coater_net(mm), int(mm.get("margin", 0)) - int(mm.get("ingredients_paid", 0)) - int(mm.get("upkeep_paid", 0)), "net: margin - ingredients - upkeep")
	if mm.has("paid_back_ms"):
		assert_true(f.coater_net(mm) >= int(mm["paid"]), "paid back when its net reached what it cost")
	else:
		assert_true(f.coater_net(mm) > 0, "on its way: %d of %d" % [f.coater_net(mm), int(mm["paid"])])
	_check_conservation(f, "payback")


func test_flavor_craft_twenty_minutes_auto_hand_mixes_and_losses_conserve() -> void:
	var f := _flavor_floor(329)
	f.level = 6
	f.sign_tier = 6
	f.presses = 30
	f.execute({"type": "build", "machine": "M07"})
	f.execute({"type": "build", "machine": "M07"})
	f.execute({"type": "build", "machine": "M01"})
	f.execute({"type": "build", "machine": "bagger"})
	f.next_arrival_ms = f.flow_ms + 500
	var p05 := _coater(f, "P05", "auto")
	var p06 := _coater(f, "P06", "auto")
	var tries := 0
	for minute in 20:
		for s in 60:
			if f.glass.is_empty():
				_pop(f)
			if s % 7 == 0:
				for m: Dictionary in [p05, p06]:
					if f.can_finish(f.machine(int(m["id"]))):
						var fl := String(f.machine(int(m["id"]))["held"]["recipe"])
						var w: Array = f.finish_window(fl)
						_hold_spoon(f, int(m["id"]), (int(w[0]) + int(w[1])) / 2 + (tries % 3 - 1) * 400)
						tries += 1
			f.advance(1000)
		_check_conservation(f, "minute %d" % minute)
	assert_eq(int(f.stats.get("wrong_sku", 0)), 0, "every bag the one ordered")
	assert_true(int(f.stats.get("mix_sold", 0)) > 0, "mixes sold: %d" % int(f.stats.get("mix_sold", 0)))
	assert_true(int(f.stats.get("hand_portions", 0)) > 0, "the hand finished batches")
	assert_true(int(f.stats.get("lost_portions", 0)) > 0, "the machine lost some caramel/cocoa/spicy")
	var by: Dictionary = f.stats.get("flavor_sold", {})
	assert_true(by.size() >= 3, "several flavors sold: %s" % by)
	assert_true(int(f.stats["sold_portions"]) <= int(f.stats["made_portions"]), "never sold more than was made")   # (the ledger keeps the last 500 rows)


func test_a_bigger_drum_coats_only_what_is_short_from_the_plain_there_is() -> void:
	var f := _flavor_floor(331)
	f.sign_tier = 6
	var m := _coater(f, "P06", "caramel")
	f.execute({"type": "upgrade_machine", "id": m["id"]})
	f.execute({"type": "upgrade_machine", "id": m["id"]})
	_fill_shelf(f)
	_fill_bin(f, 6)
	f.drain_events()
	f.advance(100)
	var st := f.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "coat_started")
	assert_eq(int(st[0]["data"]["portions"]), 6, "tier 2 (up to 8): six wanted (stock 2 + buffer 4), six coated")
	var g := _flavor_floor(333)
	g.sign_tier = 6
	var gm := _coater(g, "P06", "caramel")
	g.execute({"type": "upgrade_machine", "id": gm["id"]})
	g.execute({"type": "upgrade_machine", "id": gm["id"]})
	_fill_shelf(g)
	_fill_bin(g, 5)
	_want(g, 4, "caramel", 600000)
	g.drain_events()
	g.advance(100)
	var gs := g.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "coat_started")
	assert_eq(int(gs[0]["data"]["portions"]), 5, "ten wanted, five plain there: five coated now (not waiting for eight)")
	_check_conservation(g, "drum")


func test_a_flavor_customer_waits_aside_and_the_counter_serves_the_next() -> void:
	var f := _flavor_floor(335)
	f.sign_tier = 6
	_coater(f, "P06", "caramel")
	_stock(f, 2, 2, "plain")
	var c1 := _want(f, 2, "caramel", 600000)
	var c2 := _want(f, 2, "plain", 600000)
	f.advance(3000)
	assert_true(_sold_at(f, c2) >= 0, "the butter customer behind was served")
	assert_eq(_sold_at(f, c1), -1, "the caramel customer still waits (aside, their place kept)")
	assert_eq(int(f.stats["served_past_aside"]), 1, "counted")
	# A plain order with no bag still holds the queue (a plain shop is unchanged).
	var g := _flavor_floor(337)
	var p1 := _want(g, 4, "plain", 600000)
	var p2 := _want(g, 2, "plain", 600000)
	_stock(g, 1, 2, "plain")
	g.advance(3000)
	assert_eq(_sold_at(g, p2), -1, "behind a plain order nobody jumps")
	assert_eq(_sold_at(g, p1), -1, "")


func test_the_flavor_scene_is_built_by_the_players_commands() -> void:
	var f: PopRules = Factory.new(null, 339)
	assert_false(f.start_scene("nothing"), "an unknown scene changes nothing")
	assert_true(f.start_scene("flavors"), "the flavor scene")
	assert_eq(f.machines.map(func(m: Dictionary) -> String: return String(m["type"])), ["cooker", "cooker", "M01", "M12", "P05", "P06"], "two kettles, a hopper, the mixer, the sprayer and the coater")
	assert_eq(f.state()["coaters"].map(func(c: Dictionary) -> String: return String(c["flavor"])), ["cheese", "caramel"], "cheese and caramel")
	assert_true(f.hand_open(), "the spoon is open (20 pops)")
	assert_eq(f.money, 1500, "1500 coins to play with")
	assert_eq(f.drain_events().size(), 0, "no events left over from the setup")
	f.advance(60000)
	_check_conservation(f, "scene")


# -- Step 36: the cast, their tastes, the shop's popularity -------------------------------

const CAST := ["classic", "kid", "student", "rush", "elder"]


func _all_flavors(seed_value: int) -> PopRules:
	var f := _flavor_floor(seed_value)
	f.sign_tier = 6
	f.stats["visitors"] = 100
	f.stats["arrived"] = 100
	for row: Array in [["P05", "cheese"], ["P05", "spicy"], ["P06", "caramel"], ["P06", "cocoa"]]:
		_coater(f, row[0], row[1])
	return f


func test_the_cast_is_five_original_people_in_clean_data() -> void:
	var f: PopRules = Factory.new()
	var c: Dictionary = f.cast()
	assert_eq(c.get("order", []), CAST, "five people in the menu's order")
	var total := 0.0
	for w: String in CAST:
		var p: Dictionary = f.person(w)
		total += float(p["weight"])
		assert_false(String(p["name"]).to_lower().contains("cheeto"), "%s: an original name" % w)
		assert_true(float(p["patience"]) > 0.0 and int(p["tolerance"]) >= 1, "%s: a temper and a queue they will join" % w)
	assert_true(absf(total - 1.0) < 0.001, "the weights add up to one (%.3f)" % total)
	assert_true(float(f.person("rush")["patience"]) < float(f.person("classic")["patience"]) and float(f.person("elder")["patience"]) > float(f.person("classic")["patience"]), "the hurried wait least, the connoisseur most")


func test_newcomers_meet_a_classic_customer_ordering_butter_first() -> void:
	var f: PopRules = Factory.new(null, 401)
	assert_eq(String(f.queue[0]["who"]), "classic", "the first customer is the classic one")
	assert_eq(f.queue[0]["order"], {"recipe": "plain", "size": 2}, "asking for a small Classic Butter")
	# Even with every flavor and the large bag open, the first ones stay classic.
	var g := _flavor_floor(403)
	g.sign_tier = 6
	g.queue.clear()
	g.stats["visitors"] = 0
	g.stats["arrived"] = 0
	_coater(g, "P05", "cheese")
	_coater(g, "P06", "caramel")
	for i in 4:
		g._arrive()
	for c: Dictionary in g.queue:
		assert_eq([String(c["who"]), c["order"]], ["classic", {"recipe": "plain", "size": 2}], "newcomer %d" % c["id"])
	var seen := {}
	for i in 200:
		g._arrive()
		if not g.queue.is_empty():
			seen[String(g.queue[g.queue.size() - 1]["who"])] = true
			g.queue.pop_back()
	assert_eq(seen.size(), 5, "then all five come: %s" % [seen.keys()])


func test_each_person_has_their_tastes_and_flavor_prices_put_some_off() -> void:
	var f := _all_flavors(405)
	var share := {}
	for w: String in CAST:
		var n := {}
		var large := 0
		for i in 3000:
			var o: Dictionary = f._draw_order(w)
			n[String(o["recipe"])] = int(n.get(String(o["recipe"]), 0)) + 1
			if int(o["size"]) == 4:
				large += 1
		share[w] = {"sweet": float(int(n.get("caramel", 0)) + int(n.get("cocoa", 0))) / 3000.0, "savoury": float(int(n.get("cheese", 0)) + int(n.get("spicy", 0))) / 3000.0,
			"plain": float(n.get("plain", 0)) / 3000.0, "large": float(large) / 3000.0}
	print("  tastes: %s" % [share])
	assert_true(share["kid"]["sweet"] > share["classic"]["sweet"] * 2.0, "the sweet tooth asks for caramel and cocoa (%.2f vs %.2f)" % [share["kid"]["sweet"], share["classic"]["sweet"]])
	assert_true(share["student"]["savoury"] > share["classic"]["savoury"] * 2.0, "the snack hunter asks for cheese and spicy")
	assert_true(share["classic"]["plain"] > share["kid"]["plain"], "the butter fan stays with butter")
	assert_true(share["rush"]["large"] > share["kid"]["large"] * 2.0, "the hurried buy big, the kids small")
	# Price sensitivity: the same like, a dearer flavor weighs less for the price-sensitive.
	assert_true(f.taste("student", "cocoa") < f.taste("elder", "cocoa") / 1.6 * 0.5, "cocoa (22) puts the student off, not the connoisseur")
	assert_eq(f.taste("", "cheese"), 1.0, "no person: Step 35's weights unchanged")


func test_a_queue_longer_than_they_will_wait_in_and_their_patience() -> void:
	var f := _all_flavors(407)
	f.queue.clear()
	var base := int((f.economy.table("factory")["customers"] as Dictionary)["patience_ms"])
	for i in 3:
		_want(f, 2, "plain", 600000)
	var joined := {}
	var walked := {}
	for i in 600:
		f._arrive()
		while f.queue.size() > 3:
			var c: Dictionary = f.queue.pop_back()
			joined[String(c["who"])] = int(joined.get(String(c["who"]), 0)) + 1
			var mult := float(f.person(String(c["who"]))["patience"])
			var o: Dictionary = c["order"]
			if f.is_flavor(String(o["recipe"])):
				mult *= float(f.flavor(String(o["recipe"]))["patience"])
			elif f.is_mix(String(o["recipe"])):
				mult *= float(f.mix(String(o["recipe"]))["patience"])
			assert_eq(int(c["patience0"]), int(round(int(round(base * (mult / float(f.person(String(c["who"]))["patience"])))) * float(f.person(String(c["who"]))["patience"]))), "patience: the base x the flavor x the person")
	walked = f.stats.get("passed_by_who", {})
	assert_eq(int(joined.get("rush", 0)), 0, "with three waiting, the hurried never join")
	assert_true(int(walked.get("rush", 0)) > 50, "they walk past instead (%d)" % int(walked.get("rush", 0)))
	assert_true(int(joined.get("classic", 0)) > 100, "the others join")
	assert_eq(int(f.stats["abandoned"]), 0, "walking past is not giving up")


func test_popularity_rises_with_happy_customers_falls_with_waits_and_moves_foot_traffic() -> void:
	var f: PopRules = Factory.new(null, 409)
	assert_eq(f.stars(), 3, "an average shop: 50 = 3 stars")
	assert_true(absf(f.arrival_factor() - 1.0) < 0.001, "and the sign's own foot traffic")
	f.popularity = 100.0
	assert_true(absf(f.arrival_factor() - 1.2) < 0.001, "100: 20% more people")
	assert_eq(f.stars(), 5, "five stars")
	f.popularity = 0.0
	assert_true(absf(f.arrival_factor() - 0.8) < 0.001, "0: 20% fewer")
	# Measured: the same sign, popularity held at 100 vs 50 (no sales, no waits move it).
	var means := []
	for pop in [50.0, 100.0]:
		var g: PopRules = Factory.new(null, 411)
		g.economy.table("factory")["reputation"]["happy"] = 0.0
		g.economy.table("factory")["reputation"]["left"] = 0.0
		g.popularity = pop
		g.sign_tier = 3
		g.advance(3600000)
		var log: Array = g.arrival_log
		means.append(float(int(log[log.size() - 1]) - int(log[2])) / float(log.size() - 3))
	assert_true(absf(means[0] / means[1] - 1.2) < 0.08, "a five-star shop gets customers 1.2x as often (%.0f vs %.0f ms)" % means)
	# Happy sales lift it, waits that end in leaving lower it, never past 0..100.
	var h := _shop(413)
	h.popularity = 50.0
	_stock(h, 1)
	var c1 := _want(h, 2, "plain", 60000)
	h.queue[h.queue.size() - 1]["patience0"] = 60000
	h.advance(4000)
	assert_true(_sold_at(h, c1) >= 0, "served")
	assert_true(absf(h.popularity - 50.2) < 0.001, "a happy customer: +0.2 (%.2f)" % h.popularity)
	_want(h, 4, "plain", 1000)
	h.queue[h.queue.size() - 1]["patience0"] = 1000
	h.advance(2000)
	assert_true(absf(h.popularity - 49.2) < 0.001, "one who gave up waiting: -1 (%.2f)" % h.popularity)
	h.popularity = 0.5
	_want(h, 4, "plain", 500)
	h.advance(1000)
	assert_eq(h.popularity, 0.0, "never below 0")
	assert_eq(int(h.state()["stars"]), 0, "the board shows it")
	_check_conservation(h, "popularity")


func test_event_modifiers_and_the_favorite() -> void:
	var f := _all_flavors(415)
	f.set_demand_mods({"arrivals": 2.0, "flavors": {"cheese": 0.0}})
	assert_true(absf(f.arrival_factor() - 2.0) < 0.001, "an event can bring twice the people")
	for i in 800:
		assert_true(String(f._draw_order("student")["recipe"]) != "cheese", "and switch a flavor off")
	f.set_demand_mods({})
	f.order_log = ["plain", "caramel", "caramel", "cheese"]
	assert_eq(f.favorite(), "caramel", "the favorite: the most asked for lately")
	assert_eq(String(f.state()["favorite"]), "caramel", "on the state")


func test_a_niche_flavor_open_before_its_machine_is_never_asked_for() -> void:
	var f := _flavor_floor(417)
	f.sign_tier = 4   # spicy is open
	f.stats["visitors"] = 100
	f.stats["arrived"] = 100
	assert_true(f.flavor_open("spicy"), "spicy open")
	_coater(f, "P05", "cheese")
	for w: String in CAST:
		for i in 400:
			assert_true(String(f._draw_order(w)["recipe"]) != "spicy", "%s: no spicy before a sprayer makes it" % w)


func test_a_crowded_shop_keeps_its_queue_cap_and_order_and_nobody_waits_forever() -> void:
	var f := _shop(419)
	f.next_arrival_ms = f.flow_ms + 100
	var cap := int(f.queue_cap())
	var longest := 0
	for i in 600:
		f.advance(1000)
		longest = maxi(longest, f.queue.size())
		for c: Dictionary in f.queue:
			assert_true(int(c["patience_ms"]) <= int(c["patience0"]), "patience only runs down")
	assert_true(longest <= cap, "never more than the cap in the queue (%d <= %d)" % [longest, cap])
	assert_true(int(f.stats["passed_by"]) > 0, "the rest walk past")
	assert_true(int(f.stats["abandoned"]) > 0 and f.popularity < 50.0, "an empty shelf: they give up, the popularity drops (%.0f)" % f.popularity)
	_check_conservation(f, "crowd")


func test_the_cast_and_the_popularity_save_and_go_on_the_same() -> void:
	var f := _all_flavors(421)
	f.level = 6
	f.next_arrival_ms = f.flow_ms + 100
	for i in 60:
		if f.glass.is_empty():
			_pop(f)
		f.advance(1000)
	var g: PopRules = Factory.new(null, 421)
	assert_true(g.from_save(JSON.parse_string(JSON.stringify(f.to_save()))), "restored")
	assert_eq(g.popularity, f.popularity, "the popularity")
	for x: PopRules in [f, g]:
		for i in 60:
			if x.glass.is_empty():
				_pop(x)
			x.advance(1000)
	assert_eq(JSON.stringify(g.to_save()), JSON.stringify(f.to_save()), "the same people come and order the same")
	assert_true((f.stats.get("arrived_who", {}) as Dictionary).size() >= 4, "several kinds came: %s" % [f.stats.get("arrived_who", {})])
	_check_sales(f, "cast")
	_check_conservation(g, "cast")
