extends "res://tests/framework/test_case.gd"

## Experiment C's numbers (RockLevels): every rock harder and richer, every
## pickaxe level stronger and dearer, and the pace the issue asks for at a
## natural 2.5 taps a second -- the first break in 15-30 s paying the first
## upgrade, several breaks and upgrades in three minutes, the Giant Crystal
## still ahead.


func test_rocks_and_pickaxe_rise() -> void:
	for n in range(1, RockLevels.rock_count() + 3):
		assert_true(int(RockLevels.rock(n)["hp"]) > int(RockLevels.rock(n - 1)["hp"]), "rock %d is harder" % n)
		assert_true(int(RockLevels.rock(n)["reward"]) > int(RockLevels.rock(n - 1)["reward"]), "rock %d pays more" % n)
	for p in range(1, RockLevels.max_pick() + 1):
		assert_true(RockLevels.damage(p) > RockLevels.damage(p - 1), "pickaxe %d hits harder" % p)
		assert_true(p == 1 or RockLevels.cost(p) > RockLevels.cost(p - 1), "pickaxe %d costs more" % p)
	assert_eq(RockLevels.cost(RockLevels.max_pick() + 1), -1, "nothing past the last")
	assert_true(bool(RockLevels.rock(RockLevels.GOAL)["goal"]), "the tenth rock is the goal")


func test_the_first_break_pays_the_first_upgrade() -> void:
	assert_true(int(RockLevels.rock(0)["reward"]) >= RockLevels.cost(1), "break one rock, buy one level")


func test_the_pace_at_a_natural_tapping_speed() -> void:
	var s := RockLevels.simulate(2.5, 180.0)
	var breaks: Array = s["breaks"]
	var ups: Array = s["upgrades"]
	assert_between(float(breaks[0]), 15.0, 30.0, "the first break")
	assert_true(breaks.size() >= 5, "several rocks in three minutes (%d)" % breaks.size())
	assert_true(ups.size() >= 3, "several upgrades in three minutes (%d)" % ups.size())
	assert_true(int(s["rock"]) < RockLevels.GOAL, "the Giant Crystal is still ahead (rock %d)" % int(s["rock"]))
	for i in range(1, breaks.size()):
		assert_true(float(breaks[i]) - float(breaks[i - 1]) <= 40.0, "never more than 40 s on one rock")


func test_slow_and_fast_tappers() -> void:
	var slow := RockLevels.simulate(1.5, 180.0)
	assert_true(float((slow["breaks"] as Array)[0]) <= 40.0, "a slow tapper breaks the first rock within 40 s")
	assert_true((slow["breaks"] as Array).size() >= 3, "and a few rocks in three minutes")
	var fast := RockLevels.simulate(5.0, 180.0)
	assert_true(int(fast["rock"]) <= RockLevels.GOAL + 1, "even a frantic tapper (5 a second) at most just breaks the crystal")
	var natural := RockLevels.simulate(3.5, 180.0)
	assert_true(int(natural["rock"]) <= RockLevels.GOAL, "a quick tapper reaches the crystal but has not broken it")
	assert_true((fast["upgrades"] as Array).size() > (slow["upgrades"] as Array).size(), "tapping more buys more")
