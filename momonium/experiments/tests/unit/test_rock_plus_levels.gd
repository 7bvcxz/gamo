extends "res://tests/framework/test_case.gd"

## C+'s thirty minutes (RockPlusLevels, Step 96): a steady shape with no wall
## -- a rock always takes a few dozen hits at the matching level, a level
## comes about every three rocks -- eighteen kinds with a big one each, and
## the pace the issue asks for at plausible tapping rates, from the same
## simulation the experiment's rules make (the breaking moment and the rise,
## a reaction before each purchase). Objective pacing only: whether thirty
## minutes of it is fun, or tiring, is the owner's to say.


static func _count(a: Array, until: float) -> int:
	return a.filter(func(x: float) -> bool: return x <= until).size()


## The longest wait for the next upgrade between `lo` and `hi` seconds, the
## one still open at `hi` included.
static func _longest_wait(ups: Array, lo: float, hi: float) -> float:
	var out := 0.0
	var prev := 0.0
	for u: float in ups:
		if u > hi:
			break
		if u > lo:
			out = maxf(out, u - prev)
		prev = u
	return maxf(out, hi - prev)


func test_damage_and_prices_always_rise() -> void:
	for p in range(1, 90):
		assert_true(RockPlusLevels.damage(p) > RockPlusLevels.damage(p - 1), "level %d hits harder" % p)
		assert_true(RockPlusLevels.cost(p + 1) > RockPlusLevels.cost(p), "level %d costs more than %d" % [p + 1, p])
	assert_near(pow(RockPlusLevels.growth(), RockPlusLevels.ROCKS_PER_LEVEL), RockPlusLevels.DAMAGE_GROWTH, 0.0001, "three rocks of growth are one level")


func test_a_rock_takes_a_few_dozen_hits_at_its_level_all_the_way() -> void:
	# The level the long run keeps pace with: one every ROCKS_PER_LEVEL rocks.
	for n in range(0, 300):
		var r := RockPlusLevels.rock(n)
		var hits := float(r["hp"]) / float(RockPlusLevels.damage(int(n / RockPlusLevels.ROCKS_PER_LEVEL)))
		if bool(r["big"]):
			assert_between(hits, 40.0, 130.0, "big rock %d: %.0f hits" % [n, hits])
		else:
			assert_between(hits, 20.0, 60.0, "rock %d: %.0f hits" % [n, hits])
		if n > 0 and not bool(r["big"]) and not bool(RockPlusLevels.rock(n - 1)["big"]):
			assert_true(float(r["hp"]) / float(RockPlusLevels.rock(n - 1)["hp"]) < 1.1, "no wall at rock %d" % n)


func test_eighteen_kinds_six_rocks_each_the_sixth_big() -> void:
	var names := {}
	for k in RockPlusLevels.KINDS.size():
		var first := RockPlusLevels.rock(k * RockPlusLevels.KIND_SIZE)
		names[String(first["kind"])] = true
		assert_has(["round", "slab", "tall", "layered", "spiky", "geode", "crystal"], String(first["shape"]), "%s has a known shape" % first["kind"])
		assert_has(["stone", "metal", "glass"], String(first["sound"]), "%s has a voice" % first["kind"])
		var big := RockPlusLevels.rock(k * RockPlusLevels.KIND_SIZE + 5)
		assert_true(bool(big["big"]) and String(big["name"]).begins_with("Great "), "the sixth %s is the great one" % first["kind"])
		assert_true(int(big["reward"]) > int(first["reward"]) * 2, "and pays far more")
	assert_eq(names.size(), 18, "eighteen kinds")
	var again := RockPlusLevels.rock(18 * RockPlusLevels.KIND_SIZE)
	assert_eq(String(again["name"]), "Deep Pebble Boulder", "after the last, the kinds come round again, deeper")
	for n in 40:
		var r := RockPlusLevels.rock(n)
		assert_true(2 * RockPlusLevels.chunk_pay(r) < int(r["reward"]), "rock %d: the chunks pay part, the break the rest" % n)


func test_the_pace_at_a_natural_tapping_speed() -> void:
	var s := RockPlusLevels.simulate(2.5, 1800.0)
	var ups: Array = s["upgrades"]
	var breaks: Array = s["breaks"]
	assert_between(float(breaks[0]), 10.0, 20.0, "the first break")
	assert_true(float(ups[0]) <= 30.0, "the first upgrade within 30 s (%.1f)" % float(ups[0]))
	assert_between(_count(ups, 180.0), 5, 7, "five to seven upgrades in three minutes")
	assert_true(_longest_wait(ups, 180.0, 900.0) <= 80.0, "minutes 3-15: never more than 80 s without an upgrade (%.1f)" % _longest_wait(ups, 180.0, 900.0))
	assert_true(_longest_wait(ups, 900.0, 1800.0) <= 80.0, "minutes 15-30: the same (%.1f)" % _longest_wait(ups, 900.0, 1800.0))
	assert_true(_longest_wait(breaks, 0.0, 1800.0) <= 45.0, "never more than 45 s without a break (%.1f)" % _longest_wait(breaks, 0.0, 1800.0))
	assert_true(ups.size() >= 30, "thirty minutes: %d upgrades" % ups.size())
	assert_true(int(s["rock"]) >= 100, "past a hundred rocks (%d): the last kinds in sight" % int(s["rock"]))
	assert_true(float(s["waited"]) / float(s["taps"]) < 0.06, "few taps fall into a break's wait (%d of %d)" % [int(s["waited"]), int(s["taps"])])


func test_a_tired_player_still_moves_and_a_quick_one_does_not_run_away() -> void:
	var slow := RockPlusLevels.simulate(1.5, 1800.0)
	var ups: Array = slow["upgrades"]
	assert_true(_longest_wait(ups, 180.0, 1800.0) <= 130.0, "at 1.5 taps a second an upgrade still comes every 130 s or less (%.1f)" % _longest_wait(ups, 180.0, 1800.0))
	assert_true(ups.size() >= 20, "and twenty in thirty minutes (%d)" % ups.size())
	var quick := RockPlusLevels.simulate(4.0, 1800.0)
	assert_true((quick["upgrades"] as Array).size() > ups.size(), "tapping more buys more")
	assert_true(_longest_wait(quick["upgrades"], 180.0, 1800.0) >= 30.0, "but even at 4 a second a level is not a blur (%.1f s apart at most)" % _longest_wait(quick["upgrades"], 180.0, 1800.0))


func test_the_light_experiment_is_a_slower_hand_at_the_natural_pace() -> void:
	var light := RockPlusLevels.simulate(1.5, 1800.0, 1.5, 0.6)
	var natural := RockPlusLevels.simulate(2.5, 1800.0)
	assert_true(absi((light["upgrades"] as Array).size() - (natural["upgrades"] as Array).size()) <= 3,
		"light at 1.5 taps a second keeps the natural pace (%d vs %d upgrades)" % [(light["upgrades"] as Array).size(), (natural["upgrades"] as Array).size()])
	assert_true(int(light["taps"]) < int(natural["taps"]) * 0.7, "with 40%% fewer taps (%d vs %d)" % [int(light["taps"]), int(natural["taps"])])
