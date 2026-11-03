extends "res://tests/framework/test_case.gd"

## E+'s thirty minutes (TycoonPlusLevels, Step 98): E's ten levels as they
## were, then twenty you can see, each raising what the line can make or what
## a delivery pays; prices that rise every time; an era every fifth level from
## the fifteenth; and on the real line a pace with no stagnation through
## thirty minutes, where E stalls after its tenth level. Objective pacing
## only; whether watching it for thirty minutes is a delight is the owner's.


static func _longest(ups: Array, lo: float, hi: float) -> float:
	var best := 0.0
	var prev := 0.0
	for u: float in ups:
		if u > hi:
			break
		if u > lo:
			best = maxf(best, u - prev)
		prev = u
	return maxf(best, hi - prev)


static func _count(a: Array, until: float) -> int:
	return a.filter(func(x: float) -> bool: return x <= until).size()


func test_es_ten_levels_are_es() -> void:
	for n in TycoonLevels.LEVELS.size():
		var e := TycoonLevels.row(n)
		var p := TycoonPlusLevels.row(n)
		for k: String in e:
			assert_eq(p[k], e[k], "level %d's %s is E's" % [n, k])


func test_every_level_makes_more_and_costs_more() -> void:
	for n in range(1, TycoonPlusLevels.count() + 8):
		assert_true(TycoonPlusLevels.cost(n) > TycoonPlusLevels.cost(n - 1) or n == 1, "level %d costs more than %d" % [n, n - 1])
		var a := TycoonPlusLevels.capacity(n - 1) * float(TycoonPlusLevels.row(n - 1)["value"])
		var b := TycoonPlusLevels.capacity(n) * float(TycoonPlusLevels.row(n)["value"])
		assert_true(b >= a, "level %d earns at least what %d did at full tilt (%.0f >= %.0f)" % [n, n - 1, b, a])
		assert_true(TycoonPlusLevels.capacity(n) >= TycoonPlusLevels.capacity(n - 1), "level %d makes at least as many" % n)


func test_every_new_level_changes_something_you_see() -> void:
	var visual: Array[String] = ["lanes", "arms", "machine", "lit", "paint", "wrap", "branch", "helpers", "speed", "product", "spawn", "value"]
	for n in range(TycoonLevels.LEVELS.size(), TycoonPlusLevels.count() + 8):
		var a := TycoonPlusLevels.row(n - 1)
		var b := TycoonPlusLevels.row(n)
		var changed := (b["decor"] as Array).size() > (a["decor"] as Array).size()
		for k: String in visual:
			if a.get(k) != b.get(k):
				changed = true
		assert_true(changed, "level %d (%s) changes the line" % [n, b["name"]])
		assert_has(["arm", "lane", "paint", "helper", "belt", "machine", "decor", "branch", "wrap"], String(b["show"]), "level %d says what changed" % n)
	assert_eq(int(TycoonPlusLevels.row(30)["lanes"]), 6, "six lanes in the end")
	assert_eq((TycoonPlusLevels.row(30)["decor"] as Array).size(), 5, "five buildings beside it")


func test_an_era_every_fifth_level_from_the_fifteenth() -> void:
	var eras: Array[int] = []
	for n in TycoonPlusLevels.count():
		if TycoonPlusLevels.era(n) != "":
			eras.append(n)
	assert_eq(eras, [15, 20, 25, 30] as Array[int], "Express, Golden, Festival, Grand")


func test_thirty_minutes_on_the_real_line_without_stagnation() -> void:
	var s := TycoonPlusLevels.simulate(1800.0)
	var ups: Array = s["upgrades"]
	assert_true(float(s["first_delivery"]) <= 30.0, "a first delivery within 30 s (%.1f)" % float(s["first_delivery"]))
	assert_between(_count(ups, 180.0), 6, 10, "E's three minutes: several upgrades")
	assert_true(_count(ups, 900.0) >= 18, "many by fifteen minutes (%d)" % _count(ups, 900.0))
	assert_true(int(s["level"]) >= TycoonPlusLevels.count() - 1, "the last era by thirty minutes (Lv%d)" % int(s["level"]))
	assert_true(_longest(ups, 180.0, 900.0) <= 90.0, "minutes 3-15: never more than 90 s without an upgrade (%.0f)" % _longest(ups, 180.0, 900.0))
	assert_true(_longest(ups, 900.0, 1800.0) <= 115.0, "minutes 15-30: never more than 115 s (%.0f)" % _longest(ups, 900.0, 1800.0))
	var seen := {}
	for id: int in s["delivered_ids"]:
		assert_false(seen.has(id), "item %d delivered once" % id)
		seen[id] = true
	assert_true(int(s["spawned"]) >= int(s["delivered"]), "nothing delivered that was not made")


func test_e_stalls_where_e_plus_keeps_going() -> void:
	# E for comparison (TycoonLevels, frozen): after its tenth level only the
	# Golden Line, x1.5 a time -- the stagnation E+'s twenty levels replace.
	var e := TycoonLevels.simulate(1800.0, 1.5)
	assert_true(_longest(e["upgrades"], 900.0, 1800.0) > 300.0, "E waits more than five minutes for an upgrade after fifteen minutes (%.0f)" % _longest(e["upgrades"], 900.0, 1800.0))


func test_the_grand_alternative_is_fewer_bigger_steps_to_the_same_end() -> void:
	var g := TycoonPlusLevels.simulate(1800.0, 1.5, true)
	var ups: Array = g["upgrades"]
	assert_true(ups.size() <= 13, "a dozen big steps or so (%d)" % ups.size())
	assert_true(int(g["level"]) >= 28, "still near the end by thirty minutes (Lv%d)" % int(g["level"]))
	assert_eq(TycoonPlusLevels.next_target(0, true), 3, "the first bundle: hopper, arm and machine")
	assert_eq(TycoonPlusLevels.price_to(0, 3), TycoonPlusLevels.cost(1) + TycoonPlusLevels.cost(2) + TycoonPlusLevels.cost(3), "for the sum of their prices")
