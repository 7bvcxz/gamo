extends "res://tests/framework/test_case.gd"

## C+'s feel numbers (RockPlusFeel, Step 95): heavier rocks are heavier,
## harder hits land harder, the pickaxe's milestones are where it looks and
## sounds new, the sound stays restrained, and nothing here is economy.


func test_rocks_get_heavier_and_the_crystal_is_heaviest() -> void:
	var last := 0.0
	for n in RockLevels.rock_count():
		var w := RockPlusFeel.weight(RockLevels.rock(n))
		assert_true(w > last, "rock %d is heavier than the one before (%.2f)" % [n, w])
		last = w
	assert_near(RockPlusFeel.weight(RockLevels.rock(0)), 1.0, 0.001, "the first boulder weighs 1")
	assert_true(RockPlusFeel.shatter_pieces(RockLevels.rock(RockLevels.GOAL)) > RockPlusFeel.shatter_pieces(RockLevels.rock(0)), "the crystal breaks into more pieces")
	assert_true(RockPlusFeel.break_hold(RockLevels.rock(RockLevels.GOAL)) > RockPlusFeel.break_hold(RockLevels.rock(0)), "and holds its breaking moment longer")


func test_impact_is_the_share_one_hit_takes() -> void:
	assert_between(RockPlusFeel.impact(1, 50), 0.4, 0.6, "a first hit on the first rock is a middling one")
	assert_eq(RockPlusFeel.impact(90, 50), 1.0, "a huge pickaxe on a pebble lands as hard as it gets")
	assert_eq(RockPlusFeel.impact(1, 3600), 0.25, "a twig on the crystal still lands a little")
	assert_true(RockPlusFeel.number_size(1.0) > RockPlusFeel.number_size(0.25), "harder hits, bigger numbers")


func test_milestones_are_new_pickaxes() -> void:
	var milestones: Array[int] = []
	for p in range(1, RockLevels.max_pick() + 1):
		if RockPlusFeel.is_milestone(p):
			milestones.append(p)
	assert_eq(milestones, [3, 5, 7, 9] as Array[int], "Copper, Steel, Golden, Crystal")
	var last_head := 0.0
	for t: Dictionary in RockPlusFeel.TIERS:
		assert_true(float(t["head"]) > last_head, "%s has a bigger head" % t["name"])
		last_head = float(t["head"])
	assert_eq(String(RockPlusFeel.tier(10)["name"]), "Crystal Pickaxe", "the last level is still the Crystal tier")


func test_the_sound_is_heavier_for_heavier_rocks_and_tools_and_restrained() -> void:
	var small := RockPlusFeel.hit_sound(RockLevels.rock(0), 0, 0.5)
	var big := RockPlusFeel.hit_sound(RockLevels.rock(8), 0, 0.5)
	assert_eq(String(small["name"]), "pick", "stone knocks")
	assert_eq(String(big["name"]), "metal", "ore rings")
	assert_true(float(big["pitch"]) < float(small["pitch"]), "a bigger rock sounds lower")
	assert_true(float(RockPlusFeel.hit_sound(RockLevels.rock(0), 7, 0.5)["pitch"]) < float(small["pitch"]), "a golden pickaxe sounds lower than a wooden one")
	assert_eq(String(RockPlusFeel.hit_sound(RockLevels.rock(0), 0, 1.0)["layer"]), "", "a wooden pickaxe has no heavy layer")
	assert_eq(String(RockPlusFeel.hit_sound(RockLevels.rock(0), 5, 0.6)["layer"]), "thunk", "a steel one, hitting hard, has")
	assert_eq(String(RockPlusFeel.hit_sound(RockLevels.rock(0), 5, 0.3)["layer"]), "", "but not on a light hit")
	for n in RockLevels.rock_count():
		for p in RockLevels.max_pick() + 1:
			var s := RockPlusFeel.hit_sound(RockLevels.rock(n), p, 1.0)
			assert_true(float(s["db"]) <= -2.0 and float(s["layer_db"]) <= -8.0, "rock %d, pickaxe %d: restrained" % [n, p])


func test_the_hold_experiment_is_never_the_better_deal() -> void:
	assert_true(1.0 / RockPlusFeel.HOLD_PERIOD < 2.5, "holding hits less often than natural tapping (2.5 a second)")
	assert_true(RockPlusFeel.NUMBER_LIFT_TOUCH > RockPlusFeel.NUMBER_LIFT_MOUSE, "a finger's number rises higher")
