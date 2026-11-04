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
	var mm := float(s.economy.table("stand")["shake"]["motor_mult"])
	assert_eq(s.money - before, int(floor(int(floor(s.economy.at("stand", "batch", 4) * 2.0)) * mm)), "the motor shakes every batch (x motor_mult)")
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


## A release that looks inside the gold pays as inside: edge_grace_ms past
## either drawn edge is still perfect in the stand, and B is not changed.
func test_gold_edges_forgive_in_the_stand_only() -> void:
	var g := int(PopEconomy.load_default().table("stand")["edge_grace_ms"])
	assert_true(g > 0, "a grace")
	for lv in [0, 6]:
		var s: PopRules = Stand.new()
		s.level = lv
		var ws: int = s.window_start()
		var we: int = s.window_end()
		for at: int in [ws - g, we + g]:
			s.execute({"type": "press"})
			s.advance(at)
			assert_eq(String(s.execute({"type": "release"})["outcome"]), "perfect", "L%d %d ms (edge %+d) is perfect" % [lv, at, at - (ws if at < ws else we)])
			s.advance(2000)
		s.execute({"type": "press"})
		s.advance(ws - g - 1)
		assert_eq(String(s.execute({"type": "release"})["outcome"]), "near", "L%d one ms more is a near miss" % lv)
		s.advance(2000)
	var b: PopRules = Perfect.new()
	b.execute({"type": "press"})
	b.advance(b.window_start() - g)
	assert_eq(String(b.execute({"type": "release"})["outcome"]), "near", "B's edges stay as compared")


# -- Step 11: where the moments meet ------------------------------------------

func test_a_recipe_change_while_cooling_counts_from_the_next_batch() -> void:
	var s: PopRules = Stand.new()
	s.level = 5
	s.execute({"type": "press"})
	s.advance((s.window_start() + s.window_end()) / 2)
	s.execute({"type": "release"})
	var paid_butter := s.money
	assert_true(int(s.state()["cooldown_left"]) > 0, "cooling")
	assert_true(bool(s.execute({"type": "recipe", "id": "caramel"})["ok"]), "a change while cooling is allowed")
	assert_eq(s.money, paid_butter, "the batch already paid is not re-priced")
	s.advance(2000)
	var before := s.money
	_hold_mid(s)
	assert_eq(s.money - before, s.payout(5), "the next batch is caramel's")


func test_the_helper_ignores_the_recipe_and_keeps_going_through_a_heat() -> void:
	var stamps := {}
	for rec: String in ["butter", "caramel", "cheese"]:
		var s: PopRules = Stand.new()
		s.level = 6
		var ladder: Array = s.economy.table("stand")["auto"]
		s.money = int(ladder[0]["cost"]) + int(ladder[1]["cost"])
		s.execute({"type": "buy_auto"})
		s.execute({"type": "buy_auto"})
		s.execute({"type": "recipe", "id": rec})
		s.execute({"type": "press"})          # a long heat across a helper batch
		s.advance(int(s.state()["helper_cycle_ms"]) + 10)
		var helper_events := s.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "helper_pop")
		stamps[rec] = [helper_events.size(), int(s.state()["helper_earned"])]
	assert_eq(stamps["butter"], stamps["caramel"], "same helper with caramel")
	assert_eq(stamps["butter"], stamps["cheese"], "same helper with cheese")
	assert_eq(int((stamps["butter"] as Array)[0]), 1, "it popped while the hand was heating")


func test_buying_a_rung_mid_heat_leaves_the_heat_alone() -> void:
	var s: PopRules = Stand.new()
	s.level = 6
	s.money = 100000
	s.execute({"type": "buy_auto"})
	s.execute({"type": "buy_auto"})
	s.execute({"type": "press"})
	s.advance(700)
	var heat_before := int(s.state()["heat_ms"])
	assert_true(bool(s.execute({"type": "buy_auto"})["ok"]), "a rung while heating")
	assert_eq(int(s.state()["heat_ms"]), heat_before, "the heat is untouched")
	assert_eq(int(s.state()["helper_ms"]), 0, "the helper starts its new, faster cycle from the top (its ring restarts)")
	s.advance((s.window_start() + s.window_end()) / 2 - 700)
	assert_eq(String(s.execute({"type": "release"})["outcome"]), "perfect", "and the release is judged as before")


## Step 11: the motor shakes every batch a little (x motor_mult) and the hand's
## three swings multiply on top (x mult) -- so the motor is worth buying for a
## player who shakes, and shaking is still worth doing with the motor. (Each
## other way round, a blind player found one of the two worthless.)
func test_the_hand_and_the_motor_stack() -> void:
	var s: PopRules = Stand.new()
	s.level = 4
	var sh: Dictionary = s.economy.table("stand")["shake"]
	var plain := int(floor(s.economy.at("stand", "batch", 4) * 2.0))
	var a0 := s.money
	_hold_mid(s, 3)
	assert_eq(s.money - a0, int(floor(plain * float(sh["mult"]))), "the hand alone: x mult")
	s.money = int((s.economy.table("stand")["auto"] as Array)[0]["cost"])
	s.execute({"type": "buy_auto"})
	var a := s.money
	_hold_mid(s, 0)
	assert_eq(s.money - a, int(floor(plain * float(sh["motor_mult"]))), "the motor alone: x motor_mult")
	var b := s.money
	_hold_mid(s, 3)
	assert_eq(s.money - b, int(floor(plain * float(sh["motor_mult"]) * float(sh["mult"]))), "the hand with the motor: both")
	assert_true(s.money - b > int(floor(plain * float(sh["mult"]))), "so the motor adds something for a player who shakes")
	assert_eq(int(s.state()["hand_even_pops"]), 2, "counted as the hand's")


## run with time cut three ways ends in exactly the same state.
func _session(cut: int) -> Dictionary:
	var s: PopRules = Stand.new()
	var t := 0
	var next := 500
	var holding := false
	var release_at := 0
	var shakes_due: Array = []
	while t < 240000:
		var st := s.state()
		if holding and shakes_due.size() > 0 and t >= int(shakes_due[0]):
			shakes_due.pop_front()
			s.execute({"type": "shake"})
		if holding and t >= release_at:
			s.execute({"type": "release"})
			holding = false
			next = t + 300
		elif not holding and t >= next and not bool(st["heating"]) and int(st["cooldown_left"]) == 0:
			s.execute({"type": "press"})
			holding = true
			var w: Array = s.state()["window"]
			release_at = t + (int(w[0]) + int(w[1])) / 2 + ((t / 997) % 3 - 1) * 260
			shakes_due = [t + 200, t + 320, t + 440] if bool(st["unlocked"]["shake"]) else []
		if bool(st["unlocked"]["recipes"]) and String(st["recipe"]) == "butter":
			s.execute({"type": "recipe", "id": "cheese" if t < 150000 else "caramel"})
		if bool(st["unlocked"]["recipes"]) and t >= 150000 and String(st["recipe"]) == "cheese":
			s.execute({"type": "recipe", "id": "caramel"})
		var c: int = s.cost()
		var ac: int = s.auto_cost() if bool(st["unlocked"]["auto"]) else -1
		if c >= 0 and s.money >= c and (ac < 0 or c <= ac):
			s.execute({"type": "buy"})
		elif ac >= 0 and s.money >= ac:
			s.execute({"type": "buy_auto"})
		# Decisions on a fixed 40 ms grid; only the time between them is cut
		# differently -- so the commands are the same and only the rules' own
		# slicing of time (helper batches, the burn) is under test.
		var left := 40
		while left > 0:
			s.advance(mini(cut, left))
			left -= cut
		t += 40
	var f := s.state()
	return {"money": s.money, "earned": s.earned, "level": s.level, "auto": f["auto_level"], "outcomes": f["outcomes"],
		"helper": f["helper_earned"], "even": f["even_pops"], "recipe": f["recipe"]}


func test_a_whole_session_is_the_same_however_time_is_cut() -> void:
	var a := _session(10)
	assert_true(int(a["level"]) >= 6 and int(a["auto"]) >= 2, "the session got somewhere: %s" % [a])
	assert_eq(_session(20), a, "10 ms vs 20 ms slices")
	assert_eq(_session(40), a, "10 ms vs 40 ms slices")
	assert_eq(_session(7), a, "10 ms vs 7 ms slices (not a divisor of anything)")
