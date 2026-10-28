extends "res://tests/framework/test_case.gd"

## Step 71: every research tab is a discipline at least eight tiers deep -- a
## real chain of prerequisites, not eight icons side by side -- and the
## screen shows it a little at a time: two or three topics at the start,
## more with every level, the eighth tier for a late player. What was
## discovered stays across Prestige, as do the research points; an old save
## keeps all it had. Every new topic is named in every language, drawn with
## an existing icon, described from its data, and affordable from the store.

var sim: Simulation
var research: ResearchSystem
var prog: ProgressionSystem


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	research = sim.system(&"research")
	prog = sim.system(&"progression")


func _to_level(n: int) -> void:
	while prog.level < n:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")


## The chain behind a node's tier, deepest first: each the parent of the one before.
func _chain(id: String) -> Array[String]:
	var out: Array[String] = [id]
	var cur := id
	while research.tier_of(cur) > 1:
		var ind := String(research.node(cur)["industry"])
		var next := ""
		for r: String in research.node(cur).get("requires", []):
			if String(research.node(r)["industry"]) == ind and research.tier_of(r) == research.tier_of(cur) - 1:
				next = r
				break
		if next == "":
			break
		out.append(next)
		cur = next
	return out


func _shown_all() -> Array[String]:
	return research.shown()


func test_every_tab_is_eight_tiers_deep_along_one_chain() -> void:
	for ind: String in research.industries():
		assert_true(research.depth_of(ind) >= 8, "%s: %d tiers" % [ind, research.depth_of(ind)])
		var deepest := ""
		for n: Dictionary in research.nodes(ind):
			if deepest == "" or research.tier_of(String(n["id"])) > research.tier_of(deepest):
				deepest = String(n["id"])
		var chain := _chain(deepest)
		assert_eq(chain.size(), research.depth_of(ind), "%s: a real chain of %d (%s)" % [ind, chain.size(), " <- ".join(chain)])
		for i in range(chain.size() - 1):
			assert_true((research.node(chain[i])["requires"] as Array).has(chain[i + 1]), "%s requires %s" % [chain[i], chain[i + 1]])
			assert_eq(String(research.node(chain[i + 1])["industry"]), ind, "%s is in %s" % [chain[i + 1], ind])


func test_the_tree_has_no_holes_or_loops() -> void:
	var data := GameData.load_default()
	assert_eq(data.errors, [] as Array[String], "the data validates (unknown prerequisites, loops, effects)")
	var ids := {}
	for n: Dictionary in research.nodes():
		assert_false(ids.has(n["id"]), "%s once" % n["id"])
		ids[n["id"]] = true
	for n: Dictionary in research.nodes():
		for r: String in n.get("requires", []):
			assert_true(ids.has(r), "%s requires a node that exists (%s)" % [n["id"], r])
			assert_false(r == n["id"], "%s does not require itself" % n["id"])
	assert_eq(research.nodes().size(), 72, "37 from before + 35 new")


func test_gates_rise_along_every_chain() -> void:
	# A child never opens at a lower level than its parent: what shows next is
	# always reachable from what is shown.
	for n: Dictionary in research.nodes():
		if n.has("special"):
			continue
		for r: String in n.get("requires", []):
			var parent := research.node(r)
			if parent.has("special"):
				continue
			assert_true(int(n["unlock"]["level"]) >= int(parent["unlock"]["level"]), "%s (Lv %d) after %s (Lv %d)" % [n["id"], int(n["unlock"]["level"]), r, int(parent["unlock"]["level"])])


func test_every_topic_is_named_drawn_described_and_affordable() -> void:
	var sprites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	var known: Dictionary = sprites.get("sprites", sprites)
	var inv: InventorySystem = sim.system(&"inventory")
	for code: String in ["en", "ko", "ja", "zh_CN"]:
		LocaleService.apply(code)
		for n: Dictionary in research.nodes():
			for k: String in ["name", "desc"]:
				var key := String(n[k])
				assert_true(TranslationServer.translate(key) != key, "%s: %s in %s" % [n["id"], k, code])
			for e: Dictionary in n.get("effects", []):
				assert_true(ResearchText.effect_line(sim, e) != "", "%s: effect %s described in %s" % [n["id"], e["kind"], code])
	LocaleService.apply("en")
	for n: Dictionary in research.nodes():
		assert_true(known.has(String(n["icon"])), "%s: icon %s exists" % [n["id"], n["icon"]])
		for item: String in n["cost"].get("items", {}):
			assert_true(int(n["cost"]["items"][item]) <= inv.capacity(item), "%s: %d %s fit in the store (%d)" % [n["id"], int(n["cost"]["items"][item]), item, inv.capacity(item)])


func test_ranks_are_five_and_switches_one() -> void:
	for id: String in ["seed_drill", "crosscut_saw", "blasting", "glassware", "transmission_lines", "market_days"]:
		assert_eq(research.max_level(id), 5, "%s: Lv 0-5" % id)
	for id: String in ["combine_harvester", "coppice_woodland", "rock_drill", "recording_instruments"]:
		assert_eq(research.max_level(id), 1, "%s: a switch, one rank" % id)


func test_effects_read_as_they_work() -> void:
	LocaleService.apply("en")
	assert_eq(ResearchText.effect_lines(sim, research.node("log_flume")), ["Lumberyard: Momo work time -15%"] as Array[String], "a Momo bonus names its building")
	assert_eq(ResearchText.effect_lines(sim, research.node("turbine_gearing")), ["Wind turbine power +20%", "Water wheel power +20%"] as Array[String], "power by generator")
	assert_eq(ResearchText.effect_lines(sim, research.node("smart_grid")), ["All power +40%"] as Array[String], "all power")
	assert_eq(ResearchText.effect_lines(sim, research.node("rock_drill")), ["Dig by itself"] as Array[String], "the capstone")


func test_a_beginner_sees_two_or_three_topics() -> void:
	assert_eq(prog.level, 1, "Lv 1")
	var shown := _shown_all()
	assert_between(shown.size(), 2, 3, "two or three topics at the start (%s)" % [shown])
	var tabs: Array[String] = []
	for ind: String in research.industries():
		if not research.shown(ind).is_empty():
			tabs.append(ind)
	assert_true(tabs.size() <= 2, "in at most two tabs (%s)" % [tabs])


func test_the_tree_grows_with_the_level_and_tier_8_comes_late() -> void:
	var counts: Array[int] = []
	var deepest: Array[int] = []
	for lv in range(1, 12):
		_to_level(lv)
		var shown := _shown_all()
		counts.append(shown.size())
		var d := 0
		for id: String in shown:
			d = maxi(d, research.tier_of(id))
		deepest.append(d)
	for i in range(1, counts.size()):
		assert_true(counts[i] >= counts[i - 1], "never fewer at Lv %d (%s)" % [i + 1, counts])
	assert_true(counts[4] > counts[1] and counts[8] > counts[4], "more by the middle and more again later (%s)" % [counts])
	assert_true(deepest[2] <= 3, "Lv 3: no deeper than tier 3 (%s)" % [deepest])
	assert_true(deepest[5] < 8, "Lv 6: tier 8 is still out of sight (%s)" % [deepest])
	for ind: String in research.industries():
		var top := false
		for n: Dictionary in research.nodes(ind):
			if research.tier_of(String(n["id"])) >= 8 and research.is_shown(String(n["id"])) and research.discovered.has(String(n["id"])):
				top = true
		assert_true(top, "Lv 11: %s's eighth tier is discovered" % ind)


func test_prestige_keeps_the_discoveries_and_the_points() -> void:
	_to_level(11)
	research.rp_earned = 12
	var before := _shown_all().size()
	var carry := research.carry_over()
	var next := with_starter_momo(Simulation.new_game())
	var r2: ResearchSystem = next.system(&"research")
	r2.adopt(carry)
	assert_eq((next.system(&"progression") as ProgressionSystem).level, 1, "the new island is Lv 1")
	assert_eq(r2.shown().size(), before, "and shows everything discovered before (%d)" % before)
	assert_eq(r2.rp_earned, 12, "the research points carry over")
	assert_true(r2.is_shown("combine_harvester"), "tier 8 among them")
	assert_eq(r2.level("combine_harvester"), 0, "known, not researched")


func test_an_old_save_keeps_everything_and_meets_the_new_topics() -> void:
	# A Step 70 save at Lv 6 with field expansion researched twice and the
	# field notebook once: no new ids.
	_to_level(6)
	research.bought["farm_expansion"] = 2
	research.completed["farm_expansion"] = 1
	research.unlocked["farm_expansion"] = true
	research.bought["field_notebook"] = 1
	research.completed["field_notebook"] = 1
	research.unlocked["field_notebook"] = true
	var state := sim.save_state()
	var r: Dictionary = state["systems"]["research"]
	var old_ids := ["farm_expansion", "watering_efficiency", "harvest_boost", "watering_can", "greenhouse", "seed_selection", "drip_irrigation", "sharp_axes", "pickaxes", "copper_prospecting", "iron_prospecting", "bellows", "bloomery", "larger_crucible", "photovoltaics", "wind_power", "steam_power", "hydropower", "electric_drill", "electric_furnace", "lab_lighting", "software", "field_notebook", "momo_training", "momo_paths", "momo_reach", "momo_wide_reach", "smart_schedule", "management", "masonry", "civic_planning"]
	r["discovered"] = (r["discovered"] as Array).filter(func(id: Variant) -> bool: return old_ids.has(String(id)))
	r["seen"] = (r["seen"] as Array).filter(func(id: Variant) -> bool: return old_ids.has(String(id)))
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	var r2: ResearchSystem = copy.system(&"research")
	assert_eq(r2.level("farm_expansion"), 2, "its researched levels stay")
	for id: String in ["drip_irrigation", "software", "lab_lighting", "bellows"]:
		assert_true(r2.discovered.has(id), "%s still discovered (it moved tab, not id)" % id)
	assert_true(r2.discovered.has("index_cards") and r2.discovered.has("timber_props"), "new topics within its level are found on load")
	assert_false(r2.discovered.has("seed_drill"), "a Lv 7 topic is not, at Lv 6")
	assert_true(r2.is_shown("seed_drill"), "but it shows as the next one")
	assert_true(r2.new_topics().has("index_cards"), "and a new one that can start now is news (%s)" % [r2.new_topics()])
	assert_false(r2.new_topics().has("farm_expansion"), "an old one already seen is not")


func test_power_output_raises_what_generators_give() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var power: PowerSystem = sim.system(&"power")
	bs.place_instant("water_wheel", Vector2i(1, 0))
	var base := power.capacity()
	assert_true(base > 0.0, "a water wheel gives power (%.2f kW)" % base)
	research.bought["turbine_gearing"] = 1
	research.completed["turbine_gearing"] = 1
	assert_near(power.capacity(), base * 1.2, 0.001, "gearing: +20%")
	research.bought["smart_grid"] = 1
	research.completed["smart_grid"] = 1
	assert_near(power.capacity(), base * 1.2 * 1.4, 0.001, "and the smart grid on top: +40% of all")
	assert_near(power.supply(), power.capacity(), 0.001, "a water wheel gives all it can, now more")


func test_a_capstone_makes_its_job_run_by_itself() -> void:
	# Combine harvester + drip lines: sown once, the field waters and harvests
	# itself and the crop is sold -- nobody there (a new game's starter Momo
	# is not assigned).
	var bs: BuildingSystem = sim.system(&"buildings")
	var eco: EconomySystem = sim.system(&"economy")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	for id: String in ["drip_irrigation", "combine_harvester"]:
		research.bought[id] = 1
		research.completed[id] = 1
	sim.execute({"type": "building.tap", "id": farm})
	var sold := int(eco.lifetime.get("sale", 0))
	sim.advance_ms(120000)
	assert_true(int(eco.lifetime.get("sale", 0)) > sold, "the field was harvested and sold without anyone ($%d)" % (int(eco.lifetime.get("sale", 0)) - sold))
	assert_eq(String(bs.current_stage(bs.get_building(farm)).get("action", "")), "sow", "and waits to be sown again")
