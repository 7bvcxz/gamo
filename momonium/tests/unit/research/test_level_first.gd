extends "res://tests/framework/test_case.gd"

## Step 70: ordinary research opens at the player's level -- one plain gate a
## player can read ("Unlocks at Lv. 5"), spread from the first minutes to the
## late game -- after its prerequisites. A Momo's letter can bring a topic
## early, never hold it back. A few special nodes keep a gate of their own
## (a letter, a building's mastery), each saying why, all of them leaves so
## nothing ordinary waits on them. A gate met once stays met: discovered
## topics survive Prestige, where the level starts again, and an old save
## keeps every topic its old gates had opened. Discovering pays nothing, no
## RP; the ranks are still bought and allocated as before.

var sim: Simulation
var research: ResearchSystem
var prog: ProgressionSystem
var mail: MailSystem


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	research = sim.system(&"research")
	prog = sim.system(&"progression")
	mail = sim.system(&"mail")


func _to_level(n: int) -> void:
	while prog.level < n:
		prog.add_exp(prog.exp_needed_for(prog.level) - prog.experience, "test")


func _letter(template: String) -> void:
	for l: Dictionary in sim.data.table("letters")["letters"]:
		if String(l["id"]) == template:
			mail._write(l, 1)
			return
	fail("no letter %s" % template)


func test_every_ordinary_node_opens_at_one_level() -> void:
	var specials := 0
	for n: Dictionary in research.nodes():
		var unlock: Dictionary = n.get("unlock", {})
		if n.has("special"):
			specials += 1
			assert_true(String(n["special"]).length() > 20, "%s: special, and says why" % n["id"])
			assert_false(unlock.has("level") and unlock.size() == 1, "%s: a special node has a gate of its own" % n["id"])
			continue
		assert_eq(unlock.keys(), ["level"], "%s: one plain gate, the player level" % n["id"])
		assert_between(int(unlock.get("level", 0)), 2, 11, "%s: Lv %d (Step 71: the eighth tiers open up to Lv 11)" % [n["id"], int(unlock.get("level", 0))])
	assert_between(specials, 1, 6, "a few special nodes (%d), the rest ordinary" % specials)


func test_specials_are_leaves_and_off_the_road() -> void:
	var special_ids: Array[String] = []
	for n: Dictionary in research.nodes():
		if n.has("special"):
			special_ids.append(String(n["id"]))
	for n: Dictionary in research.nodes():
		for r: String in n.get("requires", []):
			assert_false(special_ids.has(r), "%s does not wait on the special %s" % [n["id"], r])
	# The Nation's research levels can be met by ordinary nodes alone.
	var ordinary_ranks := 0
	for n: Dictionary in research.nodes():
		if not n.has("special"):
			ordinary_ranks += research.max_level(String(n["id"]))
	var nation: Dictionary = sim.data.table("balance")["tiers"]["levels"][2]["needs"]
	assert_true(ordinary_ranks >= int(nation["research_levels"]), "ordinary ranks %d >= the Nation's %d" % [ordinary_ranks, int(nation["research_levels"])])


func test_the_gates_are_spread_over_the_game() -> void:
	var at := {}
	for n: Dictionary in research.nodes():
		if not n.has("special"):
			var lv := int(n["unlock"]["level"])
			at[lv] = int(at.get(lv, 0)) + 1
	var early := int(at.get(2, 0)) + int(at.get(3, 0))
	var middle := int(at.get(4, 0)) + int(at.get(5, 0))
	var late := 0
	for lv: int in at:
		if lv >= 6:
			late += int(at[lv])
	assert_true(early >= 5, "early (Lv 2-3): %d" % early)
	assert_true(middle >= 8, "middle (Lv 4-5): %d" % middle)
	assert_true(late >= 4, "late (Lv 6+): %d" % late)


func test_below_the_gate_locked_at_it_open() -> void:
	_to_level(2)
	assert_eq(research.state_of("pickaxes"), "locked", "Lv 2: pickaxes (Lv 3) still locked")
	assert_eq(research.missing("pickaxes"), [{"kind": "level", "need": 3, "have": 2}] as Array[Dictionary], "and it says the level")
	_to_level(3)
	assert_eq(research.state_of("pickaxes"), "available", "Lv 3: open")
	assert_eq(research.state_of("harvest_boost"), "locked", "a child still waits for its parent")
	assert_eq(research.missing("harvest_boost"), [{"kind": "requires", "id": "farm_expansion"}] as Array[Dictionary], "only the parent now")


func test_a_letter_brings_a_topic_early() -> void:
	assert_eq(prog.level, 1, "Lv 1")
	assert_eq(research.state_of("copper_prospecting"), "locked", "copper prospecting opens at Lv 4")
	_letter("mine_first")
	assert_eq(research.state_of("copper_prospecting"), "available", "a miner's letter brings it now")
	assert_true(research.discovered.has("copper_prospecting"), "and for good")
	assert_eq(research.state_of("tree_nursery"), "locked", "a special letter node still needs its letter (and its parent)")


func test_a_special_node_keeps_its_own_gate() -> void:
	_to_level(8)
	assert_eq(research.missing("drought_millet").filter(func(m: Dictionary) -> bool: return m["kind"] == "mastery").size(), 1, "Lv 8 is not farm mastery 4")
	prog.add_mastery("farm", 100000)
	assert_eq(research.missing("drought_millet").filter(func(m: Dictionary) -> bool: return m["kind"] == "mastery").size(), 0, "mastery opens it")


func test_discovered_stays_discovered_across_prestige() -> void:
	_to_level(4)
	assert_true(research.discovered.has("copper_prospecting"), "Lv 4 discovered copper prospecting")
	assert_true(research.discovered.has("masonry"), "and masonry")
	var pending_before := research.rp_pending()
	var carry := research.carry_over()
	assert_eq(int(carry["issued"]), pending_before, "discovering issues no RP (only research done does)")
	var next := with_starter_momo(Simulation.new_game())
	var r2: ResearchSystem = next.system(&"research")
	r2.adopt(carry)
	assert_eq((next.system(&"progression") as ProgressionSystem).level, 1, "the new island starts at Lv 1")
	assert_eq(r2.state_of("copper_prospecting"), "available", "but what was discovered is still open")
	assert_eq(r2.state_of("masonry"), "available", "")
	assert_eq(r2.state_of("photovoltaics"), "available", "every Lv 4 topic")
	assert_eq(r2.level("copper_prospecting"), 0, "open, not researched: no rank given")
	assert_eq(r2.state_of("iron_prospecting"), "locked", "a parent at rank 0 still holds its child back")
	assert_eq(r2.state_of("bellows"), "locked", "and Lv 5 was never reached: locked")


func test_an_old_save_keeps_what_its_old_gates_opened() -> void:
	# Before Step 70: Lv 1, farm mastery 3 (watering can was open by mastery),
	# the first farm letter written (field expansion was open by it).
	prog.add_mastery("farm", prog.mastery_needed_for(1) + prog.mastery_needed_for(2) + 1)
	assert_eq(int(prog.mastery_of("farm")["level"]), 3, "farm mastery 3")
	_letter("farm_first_harvest")
	var state := sim.save_state()
	(state["systems"]["research"] as Dictionary).erase("discovered")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	var r2: ResearchSystem = copy.system(&"research")
	assert_true(r2.discovered.has("watering_can"), "watering can: open by its old gate (farm mastery 3), kept")
	assert_true(r2.discovered.has("farm_expansion"), "field expansion: its letter")
	assert_false(r2.discovered.has("masonry"), "masonry (Lv 4 then and now): not reached, not discovered")
	assert_eq(r2.missing("watering_can"), [{"kind": "requires", "id": "watering_efficiency"}] as Array[Dictionary], "only its parent asked, not the new Lv 4")


func test_new_topics_are_only_the_newly_open() -> void:
	assert_eq(research.new_topics(), [] as Array[String], "Lv 1: nothing open, nothing new")
	_to_level(2)
	var two := research.new_topics()
	assert_true(two.has("farm_expansion") and two.has("field_notebook"), "Lv 2 brings its topics (%s)" % [two])
	assert_false(two.has("watering_efficiency"), "not one still waiting for its parent")
	assert_false(two.has("pickaxes"), "nor a Lv 3 one")
	sim.execute({"type": "research.acknowledge", "ids": two})
	assert_eq(research.new_topics(), [] as Array[String], "seen: no longer new")
	_to_level(3)
	assert_true(research.new_topics().has("pickaxes"), "Lv 3: the next ones")
	assert_false(research.new_topics().has("farm_expansion"), "and not the ones already seen")


func test_the_requirement_reads_plainly_in_every_language() -> void:
	var want := {"en": "Unlocks at Lv. 5", "ko": "Lv 5에 열려요", "ja": "Lv5で解放", "zh_CN": "等级5解锁"}
	for code: String in want:
		LocaleService.apply(code)
		assert_eq(TranslationServer.translate("research.req.level").format({"n": 5}), String(want[code]), "%s: the level, plainly" % code)
	LocaleService.apply("en")


func test_a_real_island_sale_keeps_what_was_discovered() -> void:
	var min_level := int(sim.data.get_value("balance", "prestige.min_level", 5))
	_to_level(min_level)
	var bs: BuildingSystem = sim.system(&"buildings")
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	bs.place_instant("farm", Vector2i(1, 0))
	bs.place_instant("lumberyard", Vector2i(0, 1))
	assert_true(research.discovered.has("bellows"), "Lv %d discovered bellows (Lv 5)" % min_level)
	var r := PrestigeSystem.sell(sim)
	assert_true(r["ok"], "sold (%s)" % r.get("reason", ""))
	if not r["ok"]:
		return
	assert_eq(int(r["rp_issued"]), 0, "nothing was researched: discovering issues no RP")
	var next: Simulation = r["sim"]
	var r2: ResearchSystem = next.system(&"research")
	assert_eq((next.system(&"progression") as ProgressionSystem).level, 1, "the new island is Lv 1")
	for id: String in ["farm_expansion", "pickaxes", "masonry", "bellows"]:
		assert_eq(r2.state_of(id), "available", "%s is still open on the new island" % id)
	assert_eq(r2.state_of("drip_irrigation"), "locked", "Lv 6 was never reached")
	var again := Simulation.from_save(JSON.parse_string(JSON.stringify(next.save_state())))
	assert_eq((again.system(&"research") as ResearchSystem).state_of("bellows"), "available", "and after a save and load")


func test_no_topic_opens_before_its_building() -> void:
	for n: Dictionary in research.nodes():
		var t := sim.data.building_type(String(n["industry"]))
		if t.is_empty() or n.has("special"):
			continue
		var built_at := int(t.get("unlock", {}).get("level", 1))
		assert_true(int(n["unlock"]["level"]) >= built_at, "%s (Lv %d) opens no sooner than the %s (Lv %d)" % [n["id"], int(n["unlock"]["level"]), n["industry"], built_at])
