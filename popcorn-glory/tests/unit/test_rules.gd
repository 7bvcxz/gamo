extends "res://tests/framework/test_case.gd"

## The stub's rules: a press pays pops[level], an upgrade costs exactly its
## price, money never goes below zero, and time cut into any frames gives the
## same run.

const StubRules := preload("res://variants/stub/stub_rules.gd")


func _rules() -> PopRules:
	return StubRules.new()


func test_a_press_pops_and_pays_at_once() -> void:
	var r := _rules()
	var res := r.execute({"type": "press"})
	assert_true(bool(res["ok"]), "press ok")
	assert_eq(r.money, 1, "one pop, one dollar")
	var ev := r.drain_events()
	assert_eq(ev.size(), 2, "pop then earn")
	assert_eq(String(ev[0]["type"]), "pop", "pop first")
	assert_eq(String(ev[1]["type"]), "earn", "then earn")
	assert_eq(int(ev[1]["data"]["amount"]), 1, "earn amount")


func test_buying_costs_exactly_the_price_and_changes_the_yield() -> void:
	var r := _rules()
	for i in 10:
		r.execute({"type": "press"})
	assert_eq(r.cost(), 10, "first price")
	var res := r.execute({"type": "buy"})
	assert_true(bool(res["ok"]), "bought")
	assert_eq(r.money, 0, "10 - 10")
	assert_eq(r.level, 1, "level 1")
	r.execute({"type": "press"})
	assert_eq(r.money, 2, "level 1 pops two")


func test_cannot_buy_without_the_money_and_money_never_goes_negative() -> void:
	var r := _rules()
	var res := r.execute({"type": "buy"})
	assert_false(bool(res["ok"]), "refused")
	assert_eq(String(res["reason"]), "err.not_enough_money", "a key, not a sentence")
	assert_eq(r.money, 0, "still 0")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 2000:
		r.execute({"type": "buy" if rng.randf() < 0.3 else "press"})
		if r.money < 0:
			fail("money %d after step %d" % [r.money, i])
	assert_true(r.money >= 0, "money never negative")
	assert_eq(r.level, r.max_level(), "random play reaches the top")


func test_nothing_to_buy_at_the_top() -> void:
	var r := _rules()
	r.money = 1_000_000
	for i in r.max_level():
		assert_true(bool(r.execute({"type": "buy"})["ok"]), "level %d" % i)
	var res := r.execute({"type": "buy"})
	assert_eq(String(res["reason"]), "err.max_level", "no more")
	assert_eq(r.cost(), -1, "no price")


func test_unknown_commands_change_nothing() -> void:
	var r := _rules()
	var res := r.execute({"type": "release"})
	assert_false(bool(res["ok"]), "the stub has no release")
	assert_eq(r.money, 0, "no money")
	assert_eq(r.drain_events().size(), 0, "no events")


func test_frame_cuts_do_not_change_the_run() -> void:
	var script := [[0, "press"], [400, "press"], [9000, "press"], [9100, "buy"], [30000, "press"], [95000, "press"]]
	var results: Array[String] = []
	for chunk: int in [16, 17, 1000, 95000]:
		var r := _rules()
		var log: Array = []
		var t := 0
		for step: Array in script:
			while t < int(step[0]):
				var d := mini(chunk, int(step[0]) - t)
				r.advance(d)
				t += d
			for i in 6:
				r.execute({"type": String(step[1])})
			log.append_array(r.drain_events())
		results.append(JSON.stringify([r.state(), log]))
	for i in range(1, results.size()):
		assert_eq(results[i], results[0], "chunking %d gives the same run" % i)
