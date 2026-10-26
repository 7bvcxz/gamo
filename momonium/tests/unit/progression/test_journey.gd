extends "res://tests/framework/test_case.gd"

## The island's journey: each first, once, with the time played, the time
## away the island caught up on, and the time since the island began -- the
## same moments the autoplayer saw, dated inside an absence when reached
## while away, kept across a save, and empty (not broken) for older saves.

const AutoPlayer := preload("res://tools/playtest/autoplayer.gd")


func test_the_firsts_are_the_moments_a_player_sees() -> void:
	var bot := AutoPlayer.new(with_starter_momo(Simulation.new_game()))
	bot.sell_at_points = 99
	bot.play(6 * 60.0)
	var j: JourneySystem = bot.sim.system(&"journey")
	for pair: Array in [["built:farm", "built farm"], ["harvest", "first harvest"], ["sale", "first sale"], ["level:2", "level 2"]]:
		var e := j.when(String(pair[0]))
		assert_false(e.is_empty(), "%s is in the journey" % pair[0])
		assert_eq(int(e["played_ms"]), bot.first(String(pair[1])), "%s at the moment the player saw it" % pair[0])
		assert_eq(int(e["wall_ms"]), int(e["played_ms"]), "all of it played, nothing away")
	var keys: Array = j.marks.map(func(m: Dictionary) -> String: return m["key"])
	for k: String in keys:
		assert_eq(keys.count(k), 1, "%s only once" % k)
	assert_false(keys.has("level:1"), "only the levels the data lists")


func test_time_away_is_counted_apart() -> void:
	var sim := with_starter_momo(Simulation.new_game())
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(0, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(2000)
	var j: JourneySystem = sim.system(&"journey")
	assert_true(j.when("harvest").is_empty(), "no harvest yet")
	OfflineProgress.catch_up(sim, 30 * 60000)
	var h := j.when("harvest")
	assert_false(h.is_empty(), "the Momo harvested while the player was away")
	assert_eq(int(h["played_ms"]), 2000, "dated after 2 s of play")
	assert_true(int(h["offline_ms"]) > 0, "and some minutes into the absence (%d ms)" % h["offline_ms"])
	assert_eq(int(h["wall_ms"]), 2000 + int(h["offline_ms"]), "wall time = played + away")
	var t := j.totals()
	assert_eq(int(t["played_ms"]), 2000, "2 s played")
	assert_eq(int(t["offline_ms"]), 30 * 60000, "30 minutes caught up")
	# Away longer than the catch-up counts: the rest is time, not progress.
	var cap := int(sim.data.get_float("balance", "offline.max_hours", 8.0) * 3600000.0)
	OfflineProgress.catch_up(sim, cap + 3600000)
	t = j.totals()
	assert_eq(int(t["offline_ms"]), 30 * 60000 + cap, "only the counted time ran")
	assert_eq(int(t["wall_ms"]) - int(t["played_ms"]) - int(t["offline_ms"]), 3600000, "the hour past the cap is kept as time away")


func test_kept_across_a_save_and_empty_for_older_saves() -> void:
	var bot := AutoPlayer.new(with_starter_momo(Simulation.new_game()))
	bot.play(3 * 60.0)
	OfflineProgress.catch_up(bot.sim, 600000)
	var j: JourneySystem = bot.sim.system(&"journey")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(bot.sim.save_state())))
	var jc: JourneySystem = copy.system(&"journey")
	assert_eq(jc.timeline(), j.timeline(), "the same firsts after a reload")
	assert_eq(jc.totals(), j.totals(), "and the same times")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(bot.sim.save_state()))
	raw["systems"].erase("journey")
	var old := Simulation.from_save(raw)
	var jo: JourneySystem = old.system(&"journey")
	assert_eq(jo.marks.size(), 0, "a save from before the journey starts it empty")
	assert_eq(int(jo.totals()["offline_ms"]), 0, "")
	(old.system(&"economy") as EconomySystem).earn(10000, "test")
	var spot: Vector2i = (old.system(&"land") as LandSystem).suggested()[0]
	old.execute({"type": "land.buy", "cell": [spot.x, spot.y]})
	assert_false(jo.when("land").is_empty(), "and keeps the firsts from then on")
