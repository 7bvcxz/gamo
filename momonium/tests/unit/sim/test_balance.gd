extends "res://tests/framework/test_case.gd"

## The pacing targets of Step 42, played by the autoplayer
## (tools/playtest/autoplayer.gd) on the real data, through the real commands:
## a reward within seconds, something new every few dozen seconds, automation
## and research within 20 minutes, an island worth selling around 20 minutes
## and a second island that gets there faster -- no dead ends, the same game
## across a save, and no loop that makes money from nothing.
## The longer two-day calendar is in tools/playtest/run.gd --schedule 48h.

const AutoPlayer := preload("res://tools/playtest/autoplayer.gd")


func _played(minutes: float, sell_at: int = 99) -> Object:
	var bot := AutoPlayer.new(Simulation.new_game())
	bot.sell_at_points = sell_at
	bot.play(minutes * 60.0)
	return bot


func test_the_first_minutes_answer_every_step() -> void:
	var bot := _played(15.0)
	assert_true(bot.first("first reward") <= 10000, "a reward within 10 s (%d ms)" % bot.first("first reward"))
	assert_true(bot.first("built farm") <= 60000, "a farm built in the first minute")
	assert_true(bot.first("first harvest") <= 90000, "the first harvest within 90 s (%d ms)" % bot.first("first harvest"))
	assert_true(bot.first("first sale") <= 120000, "and its $5 sale within two minutes (%d ms)" % bot.first("first sale"))
	var quiet: Dictionary = bot.longest_quiet(60000, 900000)
	assert_true(int(quiet["gap_ms"]) <= 40000, "minutes 1-15: never 40 s without something to see (%d ms at %d)" % [quiet["gap_ms"], quiet["at_ms"]])
	var news: Dictionary = bot.longest_between_milestones(0, 900000)
	assert_true(int(news["count"]) >= 15, "at least 15 new things in 15 minutes (%d)" % news["count"])
	assert_true(int(news["gap_ms"]) <= 180000, "never three minutes without one (%d ms at %d)" % [news["gap_ms"], news["at_ms"]])


func test_automation_research_and_a_sale_on_time() -> void:
	var bot := _played(30.0)
	for k: String in ["first Momo work", "first research", "first hire", "first land", "built research"]:
		assert_true(bot.first(k) >= 0 and bot.first(k) <= 20 * 60000, "%s within 20 minutes (%d ms)" % [k, bot.first(k)])
	var lv5: int = bot.first("level 5")
	assert_true(lv5 >= 12 * 60000 and lv5 <= 30 * 60000, "the island can be sold (Lv 5) after 12-30 minutes, not before (%d ms)" % lv5)
	assert_true(bot.first("level 2") <= 6 * 60000, "level 2 -- the lab and the lumberyard -- within 6 minutes (%d ms)" % bot.first("level 2"))


func test_a_sold_island_makes_the_next_one_faster() -> void:
	var bot := _played(45.0, 2)
	assert_true(bot.sales.size() >= 1, "the island was sold for legacy points")
	var first: int = bot.first("level 5")
	var sold: int = int(bot.sales[0]["active_ms"])
	var second: int = bot.first("level 5 (island 2)")
	assert_true(second > 0, "the second island reached Lv 5 too")
	assert_true(second - sold < first, "and sooner: %d s against %d s" % [(second - sold) / 1000, first / 1000])
	assert_true(int(bot.sales[0]["rp"]) > 0, "carrying research points")


func test_no_dead_ends() -> void:
	var bot := _played(30.0)
	assert_true(bot.stuck_seconds <= 30, "nothing to do and nothing working: %d s in 30 minutes" % bot.stuck_seconds)
	assert_true(bot.longest_stuck <= 5, "never long (%d s)" % bot.longest_stuck)
	for k: String in bot.counts:
		if k.contains("refused"):
			assert_true(int(bot.counts[k]) <= 3, "a command the screen offered was refused again and again: %s x%d" % [k, bot.counts[k]])


func test_a_save_in_the_middle_plays_the_same() -> void:
	var straight := AutoPlayer.new(Simulation.new_game())
	straight.play(12 * 60.0)
	var saved := AutoPlayer.new(Simulation.new_game())
	saved.play(6 * 60.0)
	saved.attach(Simulation.from_save(JSON.parse_string(JSON.stringify(saved.sim.save_state()))))
	saved.play(6 * 60.0)
	assert_eq(JSON.stringify(saved.sim.snapshot()), JSON.stringify(straight.sim.snapshot()), "saved and reloaded halfway: the same island")
	assert_eq(saved.actions, straight.actions, "after the same decisions")


func test_no_loop_makes_money_or_free_exp() -> void:
	var sim := Simulation.new_game()
	var economy: EconomySystem = sim.system(&"economy")
	var bs: BuildingSystem = sim.system(&"buildings")
	var prog: ProgressionSystem = sim.system(&"progression")
	economy.earn(990, "test")
	var gained := [0]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"exp_gained":
			gained[0] = int(gained[0]) + int(p["amount"]))
	# Build and pull down, again and again.
	for i in 10:
		var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
		sim.advance_ms(6000)
		sim.execute({"type": "building.demolish", "id": r["id"]})
	assert_eq(economy.money, 1000 - 10 * 5, "every build and pull-down costs half the price")
	var exp_per_dollar := float(gained[0]) / 50.0
	# Cancelling one still rising: the money back, and no EXP for a building never finished.
	var before_exp := int(gained[0])
	var before := economy.money
	var c := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	sim.execute({"type": "building.cancel", "id": c["id"]})
	assert_eq(economy.money, before, "a cancelled build is refunded, no more")
	assert_eq(int(gained[0]), before_exp, "and pays no EXP")
	# Farming pays far more EXP per dollar than buying buildings to pull down.
	var harvest := int(sim.data.get_value("balance", "progression.rewards.stage", {})["farm.harvest"]["player"])
	var crop := int(sim.data.get_value("items", "items.crop.price", 5))
	assert_true(exp_per_dollar <= 1.0, "the pull-down loop buys at most 1 EXP per $ (%.2f)" % exp_per_dollar)
	assert_true(harvest > crop, "while a harvest pays %d EXP and its $%d besides" % [harvest, crop])
