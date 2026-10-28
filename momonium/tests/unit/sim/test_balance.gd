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
##
## Step 69: the owner slowed the work x2.5 again (and construction x2.5) for a
## slower feel, keeping every reward. The frozen Step 50 targets are history:
## they are checked at the pace they were set for (Step 58's, `_step58_pace`),
## so a change to the rules -- not the pace -- that would break them still
## shows. The game as it is now keeps its own measured baseline
## (baseline_step69.json) and has no dead end.

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


func _baseline() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tools/balance_optimizer/baseline_step69.json"))


## The game at the pace the Step 50 targets were set for: Step 58's work x2.5
## and construction as written (Step 69 made them x6.25 and x2.5).
func _step58_pace() -> GameData:
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	bal["pace"]["work_scale"] = 2.5
	bal["pace"]["build_scale"] = 1.0
	return GameData.from_tables({"balance": bal})


func test_the_step_50_targets_hold_at_the_pace_they_were_set_for() -> void:
	# The reference player of the targets: every pass/fail target, at Step 58's pace.
	var r := Optimizer.run(_step58_pace(), _profile("blind"), {}, 10.0)
	for row: Dictionary in Optimizer.score(r, _targets(), "sim")["rows"]:
		if String(row["kind"]) != "exact" and String(row["id"]).begins_with("P"):
			assert_true(bool(row["pass"]), "%s %s %s (%s)" % [row["id"], row["metric"], row["target"], str(row["observed"])])
	# A quicker hand: money and a Momo's earnings at least as soon. (It taps
	# more itself, so its Momo share is lower -- that is not a target for it.)
	var h := Optimizer.run(_step58_pace(), _profile("human"), {}, 10.0)
	for row: Dictionary in Optimizer.score(h, _targets(), "sim")["rows"]:
		if String(row["id"]) in ["P1", "P2", "P3", "P4"]:
			assert_true(bool(row["pass"]), "human: %s %s %s (%s)" % [row["id"], row["metric"], row["target"], str(row["observed"])])
	# A slower one still earns all the way: no stall.
	var slow := Optimizer.run(_step58_pace(), _profile("blind_slow"), {}, 10.0)
	var rows: Array = slow["series"]
	for i in range(4, rows.size()):
		assert_true(int(rows[i]["income_all"]) > int(rows[i - 1]["income_all"]), "slow player: income grows every minute (%d s)" % int(rows[i]["checkpoint_s"]))


func test_a_sale_in_the_20_to_30_minute_stretch_at_step_58s_pace() -> void:
	var r := Optimizer.run(_step58_pace(), _profile("blind"), {}, 35.0)
	var ready := int(r["prestige_ready_ms"])
	assert_between(ready / 60000.0, 18.0, 32.0, "the island can first be sold for a point after %.1f min" % (ready / 60000.0))


## Step 69: the game as it is -- each journey mark, the money by 10 and 60
## minutes and the first sale within the baseline's tolerance (it moved: a
## change is either deliberate, and the baseline is re-measured, or a bug),
## money coming in every five minutes, the island sellable, the attentive
## player's firsts within the quarter hour.
func test_the_step_69_game_keeps_its_baseline_and_has_no_dead_end() -> void:
	var base := _baseline()
	var tol := float(base["tolerance"])
	assert_near(sim_scale("work_scale"), float(base["data"]["work_scale"]), 0.0001, "measured on this pace")
	var r := Optimizer.run(GameData.load_default(), _profile(String(base["profile"])), {}, 75.0)
	var journey: Dictionary = r["journey"]
	for k: String in base["journey_s"]:
		var want := float(base["journey_s"][k])
		var got := float(journey.get(k, -1)) / 1000.0
		if k == "income":
			got = int(r["first_income_ms"]) / 1000.0
		elif k == "momo_income":
			got = int(r["first_momo_income_ms"]) / 1000.0
		assert_true(got > 0.0, "%s is reached" % k)
		assert_true(absf(got - want) <= want * tol, "%s at %.0f s (baseline %.0f s, +-%d%%)" % [k, got, want, int(tol * 100)])
	var ready := int(r["prestige_ready_ms"]) / 1000.0
	assert_true(ready > 0.0, "the island can be sold")
	assert_true(absf(ready - float(base["prestige_ready_s"])) <= float(base["prestige_ready_s"]) * tol, "first sellable at %.1f min (baseline %.1f)" % [ready / 60.0, float(base["prestige_ready_s"]) / 60.0])
	var by: Dictionary = {}
	for row: Dictionary in r["series"]:
		by[int(row["checkpoint_s"])] = int(row["income_all"])
	for at: int in [600, 3600]:
		var want := float(base["income_at_%d" % at])
		assert_true(absf(by[at] - want) <= want * tol, "money by %d min: $%d (baseline $%d)" % [at / 60, by[at], int(want)])
	var last := 0
	for at: int in [300, 600, 900, 1200, 1800, 3600]:
		assert_true(int(by[at]) > last, "money still coming in by %d min ($%d)" % [at / 60, by[at]])
		last = int(by[at])
	assert_true(int(r["stuck_s"]) <= 120, "nothing to do and nothing working: %d s" % int(r["stuck_s"]))
	var bot := _played(30.0)
	for k: String in ["first Momo work", "first research", "first hire", "first land", "built research"]:
		assert_true(bot.first(k) >= 0 and bot.first(k) <= 15 * 60000, "attentive player: %s within 15 minutes (%d ms; Step 58: 10)" % [k, bot.first(k)])


func sim_scale(key: String) -> float:
	return GameData.load_default().get_float("balance", "pace." + key, 0.0)


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
	var build_ms := build_ms(sim, "farm")
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
