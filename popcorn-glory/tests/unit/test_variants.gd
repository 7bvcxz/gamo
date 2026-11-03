extends "res://tests/framework/test_case.gd"

## The three experiments' rules, each on its own: what one action pays, B's
## four outcomes and its burn that never locks, C's chamber, the show and the
## eruption at the exact millisecond. Frame cuts never change a run.

const Click := preload("res://variants/click/click_rules.gd")
const Perfect := preload("res://variants/perfect/perfect_rules.gd")
const Explosion := preload("res://variants/explosion/explosion_rules.gd")


func test_economy_has_all_three_and_every_upgrade_changes_the_yield() -> void:
	var e := PopEconomy.load_default()
	assert_eq(e.errors.size(), 0, "%s" % [e.errors])
	for v: String in ["click", "perfect", "explosion"]:
		assert_true(e.has(v), v)
		assert_true(e.max_level(v) >= 8, "%s has room for three minutes" % v)


func test_a_press_pays_pops_at_once() -> void:
	var r: PopRules = Click.new()
	r.execute({"type": "press"})
	assert_eq(r.money, 1, "1 at level 0")
	r.money = 30
	assert_true(bool(r.execute({"type": "buy"})["ok"]), "bought for 30")
	r.execute({"type": "press"})
	assert_eq(r.money, 2, "2 at level 1")


func _hold(r: PopRules, ms: int) -> Dictionary:
	assert_true(bool(r.execute({"type": "press"})["ok"]), "press ok")
	r.advance(ms)
	var out := r.execute({"type": "release"})
	r.advance(1000)   # cool down
	return out


func test_b_outcomes_by_how_long_it_was_held() -> void:
	var r: PopRules = Perfect.new()
	# level 0: batch 5; gold 1400..1850, burns at 2450.
	assert_eq(String(_hold(r, 500)["outcome"]), "early", "0.5 s early")
	assert_eq(r.money, 1, "5 * 0.3 = 1")
	assert_eq(String(_hold(r, 1400)["outcome"]), "perfect", "gold opens at 1.4 s")
	assert_eq(String(_hold(r, 1850)["outcome"]), "perfect", "and closes at 1.85 s")
	assert_eq(r.money, 1 + 10 + 10, "5 * 2 twice")
	assert_eq(String(_hold(r, 2000)["outcome"]), "late", "after the gold")
	assert_eq(r.money, 21 + 3, "5 * 0.6 = 3")
	assert_eq(int(r.outcomes["perfect"]), 2, "counted")


func test_b_holding_on_burns_by_itself_at_the_exact_millisecond() -> void:
	var r: PopRules = Perfect.new()
	r.execute({"type": "press"})
	r.drain_events()
	r.advance(2449)
	assert_true(bool(r.state()["heating"]), "still heating at 2449")
	r.advance(5000)
	assert_false(bool(r.state()["heating"]), "burnt, not stuck")
	var ev := r.drain_events()
	assert_eq(String(ev[0]["data"]["kind"]), "burnt", "burnt")
	assert_eq(int(ev[0]["t"]), 2450, "at 2450 ms exactly")
	assert_eq(r.money, 1, "5 * 0.25 -> at least 1")
	assert_false(bool(r.execute({"type": "release"})["ok"]), "the late release does nothing")


func test_b_refuses_a_press_while_cooling() -> void:
	var r: PopRules = Perfect.new()
	r.execute({"type": "press"})
	r.advance(1500)
	r.execute({"type": "release"})
	var res := r.execute({"type": "press"})
	assert_eq(String(res["reason"]), "err.cooling", "cooling")
	r.advance(400)
	assert_true(bool(r.execute({"type": "press"})["ok"]), "after 400 ms")


func test_b_gold_widens_with_level() -> void:
	var r: PopRules = Perfect.new()
	var w0: Array = r.state()["window"]
	r.level = 4
	var w4: Array = r.state()["window"]
	assert_eq(int(w0[1]) - int(w0[0]), 450, "450 ms at level 0")
	assert_eq(int(w4[1]) - int(w4[0]), 650, "650 ms at level 4")
	r.level = 11
	var w11: Array = r.state()["window"]
	assert_eq(int(w11[1]) - int(w11[0]), 800, "capped at 800")


func test_c_eight_presses_erupt() -> void:
	var r: PopRules = Explosion.new()
	for i in 7:
		r.execute({"type": "press"})
	assert_eq(r.money, 0, "nothing before the chamber is full")
	assert_eq(int(r.state()["loaded"]), 7, "seven in")
	r.execute({"type": "press"})
	assert_eq(r.money, 10, "the eighth erupts: 10")
	assert_eq(int(r.state()["loaded"]), 0, "empty again")
	assert_eq(int(r.state()["showing_left"]), 1200, "a 1.2 s show")


func test_c_presses_during_the_show_fill_the_next_chamber_which_erupts_when_it_ends() -> void:
	var r: PopRules = Explosion.new()
	for i in 8:
		r.execute({"type": "press"})
	r.drain_events()
	for i in 10:
		r.execute({"type": "press"})
	assert_eq(int(r.state()["loaded"]), 8, "full, waiting for the show")
	assert_eq(r.money, 10, "no second eruption yet")
	r.advance(1199)
	assert_eq(r.money, 10, "not before the show ends")
	r.advance(1)
	assert_eq(r.money, 20, "erupts the moment it ends")
	var erupt := r.drain_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "erupt")
	assert_eq(int(erupt[0]["t"]), 1200, "at 1200 ms")


func test_frame_cuts_do_not_change_any_run() -> void:
	for script: GDScript in [Click, Perfect, Explosion]:
		var results: Array[String] = []
		for chunk: int in [16, 17, 1000, 95000]:
			var r: PopRules = script.new()
			var log: Array = []
			var t := 0
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			var plan: Array = []
			for i in 300:
				plan.append([i * 600, "press" if i % 3 != 2 else "release"])
				if i % 25 == 0:
					plan.append([i * 600, "buy"])
			for step: Array in plan:
				while t < int(step[0]):
					var d := mini(chunk, int(step[0]) - t)
					r.advance(d)
					t += d
				r.execute({"type": String(step[1])})
				log.append_array(r.drain_events())
			results.append(JSON.stringify([r.state(), log]))
		for i in range(1, results.size()):
			assert_eq(results[i], results[0], "%s: chunking %d gives the same run" % [script.resource_path.get_file(), i])
