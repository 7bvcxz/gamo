extends "res://tests/framework/test_case.gd"

## Step 10, the Popcorn Stand's rules (variants/stand/stand_rules.gd): the
## first minutes are B's, the new moments unlock by level, the automation
## ladder takes over one action at a time, the helper pays at its exact
## millisecond however the frames cut time, and every preview is what really
## happens.

const Stand := preload("res://variants/stand/stand_rules.gd")
const Perfect := preload("res://variants/perfect/perfect_rules.gd")


func _hold_mid(r: PopRules, shakes: int = 0) -> Dictionary:
	assert_true(bool(r.execute({"type": "press"})["ok"]), "press")
	var ws: int = r.window_start()
	var we: int = r.window_end()
	for i in shakes:
		r.advance(50)
		r.execute({"type": "shake"})
	r.advance((ws + we) / 2 - shakes * 50)
	var out := r.execute({"type": "release"})
	r.advance(2000)   # cool down (and let a helper run)
	return out


func test_the_first_minutes_are_b() -> void:
	var s: PopRules = Stand.new()
	var b: PopRules = Perfect.new()
	assert_eq(s.variant, "stand", "its own table")
	for lv in 4:
		s.level = lv
		b.level = lv
		assert_eq(s.cost(), b.cost(), "L%d price is B's" % lv)
		assert_eq(s.window_start(), b.window_start(), "L%d gold opens where B's does" % lv)
		assert_eq(s.window_end(), b.window_end(), "L%d gold closes where B's does" % lv)
		assert_eq(s.payout(lv), b.payout(lv), "L%d a perfect batch pays B's" % lv)
	s.level = 0
	var before := s.money
	assert_eq(String(_hold_mid(s)["outcome"]), "perfect", "B's hold and release")
	assert_eq(s.money - before, 10, "$10 at level 0, as in B")


func test_new_moments_are_locked_until_their_level() -> void:
	var s: PopRules = Stand.new()
	s.execute({"type": "press"})
	assert_eq(String(s.execute({"type": "shake"})["reason"]), "err.locked", "no shaking at level 0")
	s.execute({"type": "release"})
	s.advance(1000)
	assert_eq(String(s.execute({"type": "recipe", "id": "caramel"})["reason"]), "err.locked", "no recipes at level 0")
	s.money = 100000
	assert_eq(String(s.execute({"type": "buy_auto"})["reason"]), "err.locked", "no automation at level 0")
	var u: Dictionary = s.economy.table("stand")["unlock"]
	s.level = int(u["shake"])
	assert_true(bool(s.state()["unlocked"]["shake"]), "shake at its level")
	assert_false(bool(s.state()["unlocked"]["auto"]), "automation later")
	s.level = int(u["auto"])
	assert_true(bool(s.execute({"type": "buy_auto"})["ok"]), "automation at its level")
	s.level = int(u["recipes"])
	assert_true(bool(s.execute({"type": "recipe", "id": "caramel"})["ok"]), "recipes at their level")


func test_shaking_three_times_makes_an_even_pop() -> void:
	var s: PopRules = Stand.new()
	s.level = 3
	var t: Dictionary = s.economy.table("stand")
	var plain := s.money
	_hold_mid(s, 2)
	var two := s.money - plain
	var mid := s.money
	_hold_mid(s, int(t["shake"]["turns"]))
	var even := s.money - mid
	assert_eq(two, int(floor(s.economy.at("stand", "batch", 3) * 2.0)), "two shakes: a plain perfect batch")
	assert_eq(even, int(floor(two * float(t["shake"]["mult"]))), "three shakes: x shake.mult")
	assert_eq(int(s.state()["even_pops"]), 1, "counted once")
	assert_eq(String(s.execute({"type": "shake"})["reason"]), "err.not_heating", "shaking needs a heat")


func test_recipes_trade_gold_width_and_speed_for_money() -> void:
	var s: PopRules = Stand.new()
	s.level = 5
	var t: Dictionary = s.economy.table("stand")
	var butter_len: int = s.window_len()
	var mid: int = (s.window_start() + s.window_end()) / 2
	assert_true(bool(s.execute({"type": "recipe", "id": "caramel"})["ok"]), "caramel")
	var cr: Dictionary = t["recipes"]["caramel"]
	assert_eq(s.window_len(), int(round(butter_len * float(cr["window_scale"]))), "caramel's gold is narrower")
	assert_true(absi((s.window_start() + s.window_end()) / 2 - mid) <= 1, "around the same middle")
	var before := s.money
	_hold_mid(s)
	assert_eq(s.money - before, int(floor(int(floor(s.economy.at("stand", "batch", 5) * 2.0)) * float(cr["mult"]))), "caramel pays x mult")
	assert_true(bool(s.execute({"type": "recipe", "id": "cheese"})["ok"]), "cheese")
	_hold_mid(s)
	s.execute({"type": "press"})
	s.advance(1600)
	s.execute({"type": "release"})
	assert_eq(int(s.state()["cooldown_left"]), int(t["cooldown_ms"]) + int(t["recipes"]["cheese"]["cooldown_add_ms"]), "cheese cools longer")
	s.advance(5000)
	s.execute({"type": "press"})
	assert_eq(String(s.execute({"type": "recipe", "id": "butter"})["reason"]), "err.already_heating", "not mid-heat")
	assert_eq(String(s.execute({"type": "recipe", "id": "truffle"})["reason"]), "err.unknown_recipe", "only the table's recipes")


func test_the_ladder_takes_over_one_action_at_a_time() -> void:
	var s: PopRules = Stand.new()
	s.level = 4
	var ladder: Array = s.economy.table("stand")["auto"]
	s.money = 0
	assert_eq(String(s.execute({"type": "buy_auto"})["reason"]), "err.not_enough_money", "costs money")
	s.money = int(ladder[0]["cost"])
	assert_true(bool(s.execute({"type": "buy_auto"})["ok"]), "the motor")
	assert_eq(s.money, 0, "paid exactly")
	assert_true(bool(s.state()["motor"]), "motor on")
	var before := s.money
	_hold_mid(s, 0)
	assert_eq(s.money - before, int(floor(int(floor(s.economy.at("stand", "batch", 4) * 2.0)) * 1.3)), "the motor shakes every batch")
	assert_eq(int(s.state()["helper_level"]), 0, "no helper yet")
	for i in range(1, ladder.size()):
		s.money = int(ladder[i]["cost"])
		assert_true(bool(s.execute({"type": "buy_auto"})["ok"]), "rung %d" % (i + 1))
		assert_eq(int(s.state()["helper_cycle_ms"]), int(ladder[i]["cycle_ms"]), "rung %d's cycle" % (i + 1))
	s.money = 10000000
	assert_eq(String(s.execute({"type": "buy_auto"})["reason"]), "err.max_level", "the ladder ends")
	assert_eq(s.auto_cost(), -1, "no price past the end")


func _helper_run(cuts: Array) -> Dictionary:
	var s: PopRules = Stand.new()
	s.level = 6
	var ladder: Array = s.economy.table("stand")["auto"]
	s.money = int(ladder[0]["cost"]) + int(ladder[1]["cost"])
	s.execute({"type": "buy_auto"})
	s.execute({"type": "buy_auto"})
	var t := 0
	var i := 0
	var stamps: Array = []
	while t < 20000:
		var step := int(cuts[i % cuts.size()])
		i += 1
		s.advance(step)
		t += step
		if t >= 5000 and t - step < 5000:
			s.execute({"type": "press"})
		if t >= 6600 and t - step < 6600:
			s.execute({"type": "release"})
		for e: Dictionary in s.drain_events():
			if String(e["type"]) == "helper_pop":
				stamps.append(int(e["t"]))
	return {"money": s.money, "stamps": stamps, "helper": int(s.state()["helper_earned"])}


func test_the_helper_pays_at_its_exact_millisecond_however_time_is_cut() -> void:
	var a := _helper_run([16])
	var b := _helper_run([17])
	var c := _helper_run([1000])
	assert_eq(a["stamps"], b["stamps"], "16 vs 17 ms frames")
	assert_eq(a["stamps"], c["stamps"], "16 vs 1000 ms frames")
	var cycle: int = int((PopEconomy.load_default().table("stand")["auto"] as Array)[1]["cycle_ms"])
	assert_eq((a["stamps"] as Array)[0], cycle, "the first helper batch at one cycle")
	assert_eq((a["stamps"] as Array).size(), 20000 / cycle, "one per cycle")
	assert_true(int(a["helper"]) > 0, "it earned")


func test_payout_is_what_a_perfect_batch_really_pays() -> void:
	for setup: Array in [[3, "butter", false], [5, "caramel", false], [6, "cheese", true], [9, "caramel", true]]:
		var s: PopRules = Stand.new()
		s.level = int(setup[0])
		if bool(setup[2]):
			s.money = int((s.economy.table("stand")["auto"] as Array)[0]["cost"])
			s.execute({"type": "buy_auto"})
		s.execute({"type": "recipe", "id": String(setup[1])})
		var before := s.money
		_hold_mid(s)
		assert_eq(s.money - before, s.payout(s.level), "%s: payout() == what it paid" % [setup])


func test_economy_table_is_valid() -> void:
	var e := PopEconomy.load_default()
	assert_eq(e.errors.size(), 0, "%s" % [e.errors])
	assert_eq(e.cost("stand", 0), 30, "the explicit list")
	assert_eq(e.cost("stand", e.max_level("stand")), -1, "none past the top")
	var bad := PopEconomy.new()
	bad.load_dict({"x": {"max_level": 2, "costs": [5, 5], "batch": [1, 2, 3]}})
	assert_true(bad.errors.size() > 0, "costs must rise")
