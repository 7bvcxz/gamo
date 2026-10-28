extends "res://tests/framework/test_case.gd"

## Research levels and the points that place them: data-driven numbers per
## level (Momo work 0.9 -> 0.6, watched tiles 4 -> 9 -> 16, paths 1.1 -> 1.5),
## the general rule for the rest, effects only when placed and valid,
## unlocked nodes open for good, saved plans that outlive a sale, and a
## ceiling no loop can pass.

var sim: Simulation
var rs: ResearchSystem


func before_each() -> void:
	sim = Simulation.new_game()
	rs = sim.system(&"research")


func test_momo_paths_say_their_numbers() -> void:
	var expect := [0.9, 0.8, 0.72, 0.65, 0.6]
	for l in range(1, 6):
		var e: Dictionary = rs.effects_at("momo_training", l)[0]
		assert_near(float(e["multiply"]), expect[l - 1], 0.0001, "Momo work at Lv %d" % l)
	assert_eq(rs.effects_at("momo_paths", 3)[0]["multiply"], 1.3, "paths Lv 3: walk 1.3 times as fast")
	rs.unlocked["momo_training"] = true
	rs.unlocked["momo_reach"] = true
	rs.unlocked["momo_wide_reach"] = true
	rs.rp_earned = 2
	assert_true(rs.allocate_all({"momo_training": 0, "momo_reach": 1})["ok"] == false, "reach needs training")
	rs.rp_earned = 3
	rs.allocate_all({"momo_training": 1, "momo_reach": 1, "momo_wide_reach": 1})
	assert_eq((sim.system(&"momo") as MomoSystem).watch_capacity(), 16, "4 -> 9 -> 16 tiles")


func test_the_general_rule_for_the_rest() -> void:
	var base := float(rs.node("sharp_axes")["effects"][0]["multiply"])
	var e: Dictionary = rs.effects_at("sharp_axes", 3)[0]
	assert_near(float(e["multiply"]), pow(base, 1.5), 0.0001, "Lv 3: m^(1 + 0.25 x 2)")
	assert_eq(rs.effects_at("sharp_axes", 0), [] as Array[Dictionary], "Lv 0: nothing")
	assert_eq(rs.max_level("bloomery"), 1, "a recipe is a switch: one level")
	assert_eq(rs.max_level("management"), 1, "a node that opens a building: one level")


func test_unlocked_is_not_active() -> void:
	rs.unlocked["momo_training"] = true
	assert_eq((sim.system(&"momo") as MomoSystem).work_multiplier(1, "farm"), sim.data.get_float("balance", "momo.work_time_multiplier", 4.0), "unlocked, no points: no effect")
	assert_eq(rs.state_of("momo_training"), "available", "but shown, ready to research or place")
	assert_true(rs.missing("momo_training").is_empty(), "the Lv 3 it once needed is not asked again")
	rs.unlocked["momo_reach"] = true
	assert_eq(rs.missing("momo_reach").map(func(m: Dictionary) -> String: return m["kind"]), ["requires"], "its prerequisite still is")


func test_saved_plans_outlive_a_sale() -> void:
	rs.unlocked["momo_training"] = true
	rs.unlocked["momo_paths"] = true
	assert_true(sim.execute({"type": "research.profile_save", "slot": 1, "levels": {"momo_training": 3, "momo_paths": 9, "nothing": 2}})["ok"], "saved")
	assert_eq(rs.profiles[1], {"momo_training": 3, "momo_paths": 5}, "known nodes, at most their top")
	var next := Simulation.new_game()
	(next.system(&"research") as ResearchSystem).adopt(rs.carry_over())
	assert_eq((next.system(&"research") as ResearchSystem).profiles[1], {"momo_training": 3, "momo_paths": 5}, "carried to the next island")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	raw["systems"]["research"]["profiles"] = [{"momo_training": "x"}, 7]
	var bad := Simulation.from_save(raw)
	assert_eq((bad.system(&"research") as ResearchSystem).profiles, [{}, {}, {}], "damaged plans read as empty")
	raw["systems"]["research"].erase("profiles")
	assert_eq((Simulation.from_save(raw).system(&"research") as ResearchSystem).profiles, [{}, {}, {}], "an older save has three empty slots")


func test_no_loop_passes_the_ceiling() -> void:
	# However often an island is sold, points come only from levels researched,
	# and a node holds at most its top level: placed plus researched.
	rs.unlocked["momo_training"] = true
	rs.rp_earned = 5
	rs.allocate_all({"momo_training": 5})
	assert_eq(rs.state_of("momo_training"), "done", "placed to the top: nothing more to research")
	assert_eq(rs.can_start("momo_training")["reason"], "err.research_done", "so no level can be bought, and no point earned there")
	var top := 0
	for n: Dictionary in rs.nodes():
		top += rs.max_level(String(n["id"]))
	# Step 71 deepened the tree to 72 nodes: still a fixed sum, read from the data.
	assert_true(top < 400, "the most points there can ever be is a fixed sum (%d)" % top)


func test_levels_must_get_better() -> void:
	var r: Dictionary = GameData.load_default().table("research").duplicate(true)
	for n: Dictionary in r["nodes"]:
		if n["id"] == "momo_training":
			n["effects"][0]["per_level"] = [0.9, 0.95]
	var text := "\n".join(GameData.from_tables({"research": r}).errors)
	assert_true(text.contains("per_level must only get better"), "a level that makes it worse is refused")


func test_the_preview_reads_the_numbers() -> void:
	LocaleService.apply("en")
	assert_eq(ResearchText.at_level(sim, "momo_reach", 1), "Each Momo looks after 5 more tiles", "in words")
	assert_true(ResearchText.at_level(sim, "momo_training", 2).contains("20"), "Lv 2: 20%")
