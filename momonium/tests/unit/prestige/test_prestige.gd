extends "res://tests/framework/test_case.gd"

## Selling the settlement: a transparent appraisal, a level to reach first,
## legacy points that never pay twice for the same progress, a head start that
## is not counted as worth -- and research: levels researched in a run become
## research points for good, unlocks stay, levels start again at 0 and are
## allocated freely, and nothing mints points twice.

var sim: Simulation


func before_each() -> void:
	sim = Simulation.new_game()


func _to_level(s: Simulation, lv: int) -> void:
	var prog: ProgressionSystem = s.system(&"progression")
	while prog.level < lv:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")


## The level a sale needs (balance.prestige.min_level).
func _min_level() -> int:
	return int(GameData.load_default().get_value("balance", "prestige.min_level", 5))


func _lab(s: Simulation) -> void:
	(s.system(&"buildings") as BuildingSystem).place_instant("research", Vector2i(1, 1))
	(s.system(&"economy") as EconomySystem).earn(20000, "test")


## Researches `id` up `n` levels the real way: pay, wait, done.
func _research(s: Simulation, id: String, n: int) -> void:
	var rs: ResearchSystem = s.system(&"research")
	var inv: InventorySystem = s.system(&"inventory")
	for i in n:
		var need: Dictionary = rs.cost_of(id)["items"]
		for item: String in need:
			inv.add(item, maxi(int(need[item]) - inv.count(item), 0), "test")
		var r := s.execute({"type": "research.start", "id": id})
		assert_true(r["ok"], "%s level %d starts (%s)" % [id, rs.level(id) + 1, r.get("reason", "")])
		s.advance_ms(rs.duration_ms(id) + 10)


func _sell(s: Simulation) -> Simulation:
	var r := PrestigeSystem.sell(s)
	assert_true(r["ok"], "sold (%s)" % r.get("reason", ""))
	return r["sim"] if r["ok"] else s


func test_appraisal_lines() -> void:
	_to_level(sim, _min_level())
	var bs: BuildingSystem = sim.system(&"buildings")
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})
	sim.execute({"type": "building.place", "building": "lumberyard", "anchor": [0, 1]})
	sim.execute({"type": "land.buy", "cell": [2, 0]})
	var a := (sim.system(&"prestige") as PrestigeSystem).appraise()
	assert_eq(a["families"], {"farm": 6, "mine": 0, "lumberyard": 48, "research": 0, "special": 0}, "60% of what each family cost")
	var tile := (sim.system(&"land") as LandSystem).cost_of(0)
	assert_eq(a["land"], int(floor(tile * 0.8)), "80% of the tile's price")
	assert_eq(a["momo"], 30, "one Momo, no skill yet")
	assert_true(a["experience"] > 0, "the levels climbed")
	assert_eq(a["gross"], a["buildings"] + a["land"] + a["productivity"] + a["momo"] + a["research"] + a["experience"], "the total is the sum of its lines")
	assert_eq(a["net"], a["gross"], "no head start to take off")
	assert_true(bs.ids().size() == 2 and a["can_sell"], "at the selling level it can be sold")


func test_a_level_first() -> void:
	var r := PrestigeSystem.sell(sim)
	assert_eq(r["reason"], "err.prestige_level", "a new island cannot be sold")


func test_a_new_island_with_a_head_start() -> void:
	_to_level(sim, 8)
	var next := _sell(sim)
	var p: PrestigeSystem = next.system(&"prestige")
	assert_true(p.points > 0, "legacy points (%d)" % p.points)
	assert_eq((next.system(&"economy") as EconomySystem).money, 10 + 15 * p.points, "starting money and the head start")
	assert_eq((next.system(&"world") as WorldSystem).owned_count(), 4, "a fresh island")
	assert_eq((next.system(&"progression") as ProgressionSystem).level, 1, "level 1 again")
	assert_eq(p.sales, 1, "one sale on record")
	assert_eq(p.history.size(), 1, "")
	assert_eq(p.seed_money, 15 * p.points + 30 * p.start_momo_bonus(), "the head start is not its worth")
	assert_true(p.welcome, "it opens on the research points")


func test_selling_again_without_progress_pays_nothing() -> void:
	_to_level(sim, 8)
	var next := _sell(sim)
	var p: PrestigeSystem = next.system(&"prestige")
	var points := p.points
	# Spend the head start on buildings and sell: worth less than it was handed.
	_to_level(next, _min_level())
	var gross := p.appraise()
	var bs: BuildingSystem = next.system(&"buildings")
	bs.place_instant("farm", Vector2i(1, 0))
	assert_true(int(p.appraise()["net"]) <= int(gross["net"]), "buildings bought with the head start add no net worth")
	var third := _sell(next)
	var p3: PrestigeSystem = third.system(&"prestige")
	assert_true(p3.points - points <= p.new_points(int(gross["net"])), "only what this island genuinely grew")
	assert_true(p3.points - points < points, "and far less than the first, real sale")


func test_research_becomes_points_and_is_placed_again() -> void:
	_to_level(sim, 8)
	_lab(sim)
	_research(sim, "momo_training", 3)
	_research(sim, "momo_reach", 1)
	_research(sim, "momo_wide_reach", 1)
	var rs: ResearchSystem = sim.system(&"research")
	assert_eq([rs.level("momo_training"), rs.level("momo_reach"), rs.level("momo_wide_reach")], [3, 1, 1], "3 / 1 / 1")
	assert_eq(rs.rp_pending(), 5, "five levels researched")
	var next := _sell(sim)
	var r2: ResearchSystem = next.system(&"research")
	assert_eq(r2.rp_earned, 5, "five research points")
	assert_eq(r2.rp_unspent(), 5, "all unspent")
	assert_eq([r2.level("momo_training"), r2.level("momo_reach"), r2.level("momo_wide_reach")], [0, 0, 0], "every level back to 0")
	assert_true(r2.is_unlocked_node("momo_wide_reach") and r2.is_unlocked_node("momo_training"), "but unlocked for good")
	assert_eq((next.system(&"momo") as MomoSystem).watch_capacity(), 4, "no effect until placed")
	var r := next.execute({"type": "research.allocate", "levels": {"momo_training": 1, "momo_reach": 2, "momo_wide_reach": 2}})
	assert_true(r["ok"], "1 / 2 / 2 placed (%s)" % r.get("reason", ""))
	assert_eq(r2.rp_unspent(), 0, "every point used")
	assert_eq([r2.level("momo_training"), r2.level("momo_reach"), r2.level("momo_wide_reach")], [1, 2, 2], "")
	assert_eq((next.system(&"momo") as MomoSystem).watch_capacity(), 4 + 6 + 8, "reach Lv 2 (+6) and wide reach Lv 2 (+8)")
	r = next.execute({"type": "research.allocate", "levels": {"momo_training": 3, "momo_reach": 1, "momo_wide_reach": 1}})
	assert_true(r["ok"], "and back to 3 / 1 / 1, freely")


func test_allocation_rules() -> void:
	_to_level(sim, 8)
	_lab(sim)
	_research(sim, "momo_training", 2)
	_research(sim, "momo_reach", 1)
	var next := _sell(sim)
	var plan := func(levels: Dictionary) -> String:
		return String(next.execute({"type": "research.allocate", "levels": levels}).get("reason", ""))
	assert_eq(plan.call({"momo_training": 2, "momo_reach": 2}), "err.rp_short", "4 points asked, 3 earned")
	assert_eq(plan.call({"momo_reach": 1}), "err.research_needs", "reach needs training placed")
	assert_eq(plan.call({"momo_wide_reach": 1}), "err.research_locked", "never researched: locked")
	assert_eq(plan.call({"momo_training": 6}), "err.research_max", "five at most")
	assert_eq(plan.call({"momo_training": 2, "momo_reach": 1}), "", "this one fits")


func test_selling_again_mints_no_research_points() -> void:
	_to_level(sim, 8)
	_lab(sim)
	_research(sim, "momo_training", 3)
	var next := _sell(sim)
	next.execute({"type": "research.allocate", "levels": {"momo_training": 3}})
	_to_level(next, _min_level())
	var third := _sell(next)
	assert_eq((third.system(&"research") as ResearchSystem).rp_earned, 3, "points placed and sold again: still 3")
	_to_level(third, _min_level())
	_lab(third)
	third.execute({"type": "research.allocate", "levels": {"momo_training": 3}})
	_research(third, "momo_training", 1)
	var fourth := _sell(third)
	assert_eq((fourth.system(&"research") as ResearchSystem).rp_earned, 4, "one level genuinely researched: one more point")


func test_saved_and_damaged_saves() -> void:
	_to_level(sim, 8)
	_lab(sim)
	_research(sim, "momo_training", 2)
	var next := _sell(sim)
	next.execute({"type": "research.allocate", "levels": {"momo_training": 2}})
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(next.save_state())))
	var rc: ResearchSystem = copy.system(&"research")
	assert_eq([rc.rp_earned, rc.level("momo_training"), rc.is_unlocked_node("momo_training")], [2, 2, true], "kept across a reload")
	assert_eq((copy.system(&"prestige") as PrestigeSystem).points, (next.system(&"prestige") as PrestigeSystem).points, "legacy too")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(next.save_state()))
	raw["systems"]["research"]["allocated"] = {"momo_training": 5, "no_such_node": 3}
	raw["systems"]["research"]["rp_earned"] = -7
	var bad := Simulation.from_save(raw)
	var rb: ResearchSystem = bad.system(&"research")
	assert_eq(rb.rp_earned, 0, "a negative ledger is read as 0")
	assert_eq(rb.allocated, {}, "allocations that do not add up are dropped")
	assert_eq(rb.level("momo_training"), 0, "so nothing is active that was not paid for")


func test_an_old_save_counts_its_research() -> void:
	var rs: ResearchSystem = sim.system(&"research")
	rs.completed["momo_training"] = 0
	var raw: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	raw["systems"]["research"].erase("bought")
	raw["systems"]["research"].erase("unlocked")
	raw["systems"]["research"].erase("rp_earned")
	raw["systems"].erase("prestige")
	var old := Simulation.from_save(raw)
	var ro: ResearchSystem = old.system(&"research")
	assert_eq([ro.level("momo_training"), ro.rp_pending(), ro.is_unlocked_node("momo_training")], [1, 1, true], "finished research is one level, unlocked")
	assert_eq((old.system(&"prestige") as PrestigeSystem).points, 0, "no legacy yet")


func test_legacy_makes_momo_quicker() -> void:
	var before := (sim.system(&"momo") as MomoSystem).work_multiplier(1, "farm")
	(sim.system(&"prestige") as PrestigeSystem).points = 10
	var after := (sim.system(&"momo") as MomoSystem).work_multiplier(1, "farm")
	assert_true(absf(after / before - 0.8) < 0.001, "10 points: 20%% quicker (%.3f)" % (after / before))
	(sim.system(&"prestige") as PrestigeSystem).points = 100
	assert_true(absf((sim.system(&"momo") as MomoSystem).work_multiplier(1, "farm") / before - 0.7) < 0.001, "capped at 30 percent")
