extends "res://tests/framework/test_case.gd"

## The pacing of Step 50, played on the real data through the real commands
## by the optimizer's player profiles (tools/balance_optimizer/: "blind" --
## a first-time player taking ten seconds a decision, as the blind AI
## playtests did -- and "human", a decision a second): the first harvest is
## money within seconds, a Momo earns by itself within 90 s, income never
## pauses for more than 30 s once automation runs, something meaningful at
## least every 40 s on average, automation does most of the work by 10
## minutes -- the pass/fail targets frozen in targets.json -- and an island
## worth selling in the 20-30 minute stretch, a second island that gets there
## faster, no dead ends, the same game across a save, and no loop that makes
## money from nothing. The longer two-day calendar is optimize.gd --schedule 48h.

const AutoPlayer := preload("res://tools/playtest/autoplayer.gd")
const Optimizer := preload("res://tools/balance_optimizer/optimize.gd")


func _played(minutes: float, sell_at: int = 99) -> Object:
	var bot := AutoPlayer.new(Simulation.new_island())
	bot.sell_at_points = sell_at
	bot.play(minutes * 60.0)
	return bot


func _profile(name: String) -> Dictionary:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/balance_optimizer/profiles.json"))
	return profiles["profiles"][name]


func _targets() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tools/balance_optimizer/targets.json"))


func test_the_first_minutes_meet_the_pass_fail_targets() -> void:
	# The reference player of the targets: every pass/fail target.
	var r := Optimizer.run(GameData.load_default(), _profile("blind"), {}, 10.0)
	for row: Dictionary in Optimizer.score(r, _targets(), "sim")["rows"]:
		if String(row["kind"]) != "exact" and String(row["id"]).begins_with("P"):
			assert_true(bool(row["pass"]), "%s %s %s (%s)" % [row["id"], row["metric"], row["target"], str(row["observed"])])
	# A quicker hand: money and a Momo's earnings at least as soon. (It taps
	# more itself, so its Momo share is lower -- that is not a target for it.)
	var h := Optimizer.run(GameData.load_default(), _profile("human"), {}, 10.0)
	for row: Dictionary in Optimizer.score(h, _targets(), "sim")["rows"]:
		if String(row["id"]) in ["P1", "P2", "P3", "P4"]:
			assert_true(bool(row["pass"]), "human: %s %s %s (%s)" % [row["id"], row["metric"], row["target"], str(row["observed"])])
	# A slower one still earns all the way: no stall.
	var slow := Optimizer.run(GameData.load_default(), _profile("blind_slow"), {}, 10.0)
	var rows: Array = slow["series"]
	for i in range(4, rows.size()):
		assert_true(int(rows[i]["income_all"]) > int(rows[i - 1]["income_all"]), "slow player: income grows every minute (%d s)" % int(rows[i]["checkpoint_s"]))


func test_a_sale_in_the_20_to_30_minute_stretch() -> void:
	var r := Optimizer.run(GameData.load_default(), _profile("blind"), {}, 35.0)
	var ready := int(r["prestige_ready_ms"])
	assert_between(ready / 60000.0, 18.0, 32.0, "the island can first be sold for a point after %.1f min" % (ready / 60000.0))
	var bot := _played(30.0)
	for k: String in ["first Momo work", "first research", "first hire", "first land", "built research"]:
		assert_true(bot.first(k) >= 0 and bot.first(k) <= 10 * 60000, "attentive player: %s within 10 minutes (%d ms)" % [k, bot.first(k)])


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
	var straight := AutoPlayer.new(Simulation.new_island())
	straight.play(12 * 60.0)
	var saved := AutoPlayer.new(Simulation.new_island())
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
	# Build and pull down, again and again (the moment it is finished, before
	# the island's Momo, which takes new buildings by itself, works it).
	var cost := int(sim.data.building_type("farm")["cost"]["money"])
	var build_ms := int(float(sim.data.building_type("farm")["build_seconds"]) * 1000.0)
	for i in 10:
		var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
		sim.advance_ms(build_ms)
		sim.execute({"type": "building.demolish", "id": r["id"]})
	var lost := 10 * (cost - int(floor(cost * sim.data.get_float("balance", "construction.demolish_refund", 0.5))))
	assert_eq(economy.money, 1000 - lost, "every build and pull-down costs half the price")
	var exp_per_dollar := float(gained[0]) / lost
	# Cancelling one still rising: the money back, and no EXP for a building never finished.
	var before_exp := int(gained[0])
	var before := economy.money
	var c := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	sim.execute({"type": "building.cancel", "id": c["id"]})
	assert_eq(economy.money, before, "a cancelled build is refunded, no more")
	assert_eq(int(gained[0]), before_exp, "and pays no EXP")
	# Farming pays EXP and money besides; the pull-down loop only spends.
	var stage: Dictionary = sim.data.get_value("balance", "progression.rewards.stage", {})
	var cycle_exp := 0
	for k: String in ["farm.sow", "farm.water", "farm.harvest"]:
		cycle_exp += int(stage[k]["player"])
	assert_true(exp_per_dollar <= 1.0, "the pull-down loop buys at most 1 EXP per $ (%.2f)" % exp_per_dollar)
	assert_true(cycle_exp > 0 and economy.unit_price("crop") > 0, "while a farming cycle pays %d EXP and $%d besides" % [cycle_exp, economy.unit_price("crop")])
