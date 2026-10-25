extends "res://tests/framework/test_case.gd"

## The technology tree: unlocking by prerequisites, mastery and Momo
## proposals; starting at a finished lab with the cost paid; finishing on its
## own; effects that change the farm the way the data says -- and never by
## removing a required stage.

var sim: Simulation
var research: ResearchSystem
var buildings: BuildingSystem
var inv: InventorySystem
var economy: EconomySystem
var mail: MailSystem


func before_each() -> void:
	sim = Simulation.new_game()
	research = sim.system(&"research")
	buildings = sim.system(&"buildings")
	inv = sim.system(&"inventory")
	economy = sim.system(&"economy")
	mail = sim.system(&"mail")


## Momo's first letter, accepted: farm_expansion opens.
func _accept_first_proposal() -> int:
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(250000)
	sim.execute({"type": "mail.claim", "id": 1})
	return farm


func _ready_to_research() -> void:
	buildings.place_instant("research", Vector2i(0, 1))
	economy.earn(500, "test")
	inv.add("notes", 20, "test")


func test_the_tree_and_its_branches() -> void:
	assert_eq(research.industries(), ["farm", "lumberyard", "mine", "global"] as Array[String], "a branch per industry, general last")
	assert_eq(research.nodes("farm").size(), GameData.load_default().table("research")["nodes"].filter(func(n: Dictionary) -> bool: return n["industry"] == "farm").size(), "every farming technology in the data")
	assert_true(research.nodes("farm").size() >= 3, "several of them")
	for n: Dictionary in research.nodes():
		assert_eq(research.state_of(String(n["id"])), "locked", "%s starts locked" % n["id"])


func test_what_each_node_still_needs() -> void:
	assert_eq(research.missing("farm_expansion"), [{"kind": "proposal"}] as Array[Dictionary], "a Momo's proposal")
	assert_eq(research.missing("watering_efficiency"), [{"kind": "requires", "id": "farm_expansion"}, {"kind": "proposal"}] as Array[Dictionary], "field expansion first, and a proposal")
	assert_eq(research.missing("field_notebook"), [{"kind": "mastery", "type": "research", "need": 2, "have": 1}] as Array[Dictionary], "research mastery 2")


func test_an_accepted_proposal_unlocks() -> void:
	_accept_first_proposal()
	assert_eq(research.state_of("farm_expansion"), "available", "accepting Momo's letter opened field expansion")
	assert_eq(research.state_of("watering_efficiency"), "locked", "its children still wait")


func test_mastery_unlocks_the_general_branch() -> void:
	(sim.system(&"progression") as ProgressionSystem).add_mastery("research", 100)
	assert_eq(research.state_of("field_notebook"), "available", "research mastery 2 opens the notebook")


func test_starting_needs_a_finished_lab_and_the_cost() -> void:
	_accept_first_proposal()
	assert_eq(sim.execute({"type": "research.start", "id": "farm_expansion"})["reason"], "err.no_lab", "no lab")
	economy.earn(200, "test")
	assert_eq(sim.execute({"type": "building.place", "building": "research", "anchor": [0, 1]})["reason"], "err.locked", "the lab opens at Lv 2")
	var lab := buildings.place_instant("research", Vector2i(0, 1))
	var b := buildings.get_building(lab)
	b["state"] = BuildingSystem.CONSTRUCTING
	assert_eq(research.can_start("farm_expansion")["reason"], "err.no_lab", "a lab still being built does not count")
	b["state"] = BuildingSystem.IDLE
	assert_eq(research.can_start("farm_expansion")["reason"], "err.not_enough_items", "three research notes needed")
	inv.add("notes", 3, "test")
	var money_before := economy.money
	var r := sim.execute({"type": "research.start", "id": "farm_expansion"})
	assert_true(r["ok"], "started")
	assert_eq(economy.money, money_before - 20, "paid $20")
	assert_eq(inv.count("notes"), 0, "and three notes")
	assert_eq(research.state_of("farm_expansion"), "active", "running")
	assert_eq(r["ends_ms"], sim.now_ms() + 60000, "for 60 s")


func test_one_at_a_time_and_finishes_by_itself() -> void:
	_accept_first_proposal()
	_ready_to_research()
	(sim.system(&"progression") as ProgressionSystem).add_mastery("research", 100)
	sim.execute({"type": "research.start", "id": "farm_expansion"})
	assert_eq(sim.execute({"type": "research.start", "id": "field_notebook"})["reason"], "err.research_busy", "one at a time")
	var done := [""]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"research_completed":
			done[0] = String(p["id"]))
	sim.advance_ms(59999)
	assert_eq(research.state_of("farm_expansion"), "active", "not a moment early")
	sim.advance_ms(1)
	assert_eq(research.state_of("farm_expansion"), "done", "done after exactly 60 s")
	assert_eq(done[0], "farm_expansion", "announced")
	assert_eq(sim.execute({"type": "research.start", "id": "farm_expansion"})["reason"], "err.research_done", "not twice")


func test_field_expansion_brings_a_bigger_harvest() -> void:
	var farm := _accept_first_proposal()
	_ready_to_research()
	var b := buildings.get_building(farm)
	assert_eq(buildings.cycle_estimate(b)["yield"], {"crop": 1.0}, "one crop a cycle before")
	sim.execute({"type": "research.start", "id": "farm_expansion"})
	sim.advance_ms(60000)
	assert_eq(buildings.cycle_estimate(b)["yield"], {"crop": 2.0}, "two after")
	var made := [0]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"produced":
			made[0] += int((p["items"] as Dictionary).get("crop", 0)))
	sim.advance_ms(400000)
	assert_true(made[0] >= 2 and made[0] % 2 == 0, "real harvests give two crops each (%d)" % made[0])


func test_mulch_shortens_the_wait_but_keeps_three_waterings() -> void:
	var farm := _accept_first_proposal()
	_ready_to_research()
	research.completed["farm_expansion"] = 0
	(sim.system(&"progression") as ProgressionSystem).add_mastery("farm", 100)
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	for l: Dictionary in mail.letters:
		sim.execute({"type": "mail.claim", "id": l["id"]})
	assert_eq(research.state_of("watering_efficiency"), "available", "Momo proposed it and its parent is done")
	sim.execute({"type": "research.start", "id": "watering_efficiency"})
	sim.advance_ms(90000)
	var b := buildings.get_building(farm)
	var stages := buildings.stages(b)
	assert_eq(stages.filter(func(st: Dictionary) -> bool: return st["action"] == "water").size(), 3, "still three waterings")
	assert_eq(stages.size(), 5, "no stage removed")
	assert_eq(buildings.stage_cooldown(b, stages[1]), 22.5, "the wait after watering is 30 s x 0.75")
	assert_eq(buildings.stage_cooldown(b, stages[0]), 0.0, "sowing still has no wait")


func test_floors_hold_whatever_the_research() -> void:
	var r: Dictionary = GameData.load_default().table("research").duplicate(true)
	r["nodes"][1]["effects"][0]["multiply"] = 0.05
	var data := GameData.from_tables({"research": r})
	sim = Simulation.new_game(data)
	research = sim.system(&"research")
	buildings = sim.system(&"buildings")
	research.completed["watering_efficiency"] = 0
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	var b := buildings.get_building(farm)
	assert_eq(buildings.stage_cooldown(b, buildings.stages(b)[1]), 10.0, "the plants' 10 s floor holds")


func test_the_notebook_speeds_up_research() -> void:
	assert_eq(research.duration_ms("harvest_boost"), 120000, "two minutes")
	research.completed["field_notebook"] = 0
	assert_eq(research.duration_ms("harvest_boost"), 96000, "x0.8 with the notebook")


func test_the_lab_makes_notes_and_research_mastery() -> void:
	var lab := buildings.place_instant("research", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": lab})
	sim.advance_ms(30000 * 12)
	assert_true(inv.count("notes") >= 10, "a Momo at the lab writes research notes (%d)" % inv.count("notes"))
	assert_eq(research.state_of("field_notebook"), "available", "and the lab's experience opens the general branch")


func test_research_survives_a_save_mid_way() -> void:
	_accept_first_proposal()
	_ready_to_research()
	sim.execute({"type": "research.start", "id": "farm_expansion"})
	sim.advance_ms(20000)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var r2: ResearchSystem = copy.system(&"research")
	assert_eq(r2.state_of("farm_expansion"), "active", "still running after loading")
	copy.advance_ms(39999)
	assert_eq(r2.state_of("farm_expansion"), "active", "on the same clock")
	copy.advance_ms(1)
	assert_eq(r2.state_of("farm_expansion"), "done", "finishes when it would have")
	var farm2 := (copy.system(&"buildings") as BuildingSystem).building_at(Vector2i(1, 0))
	assert_eq((copy.system(&"buildings") as BuildingSystem).cycle_estimate((copy.system(&"buildings") as BuildingSystem).get_building(farm2))["yield"], {"crop": 2.0}, "and its effect applies in the loaded world")


func test_an_old_save_without_research_loads() -> void:
	var state := sim.save_state()
	(state["systems"] as Dictionary).erase("research")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	assert_eq((copy.system(&"research") as ResearchSystem).completed, {}, "nothing researched")
	assert_eq((copy.system(&"research") as ResearchSystem).active, {}, "nothing running")


func test_bad_trees_are_refused() -> void:
	var cases := {
		"requires itself": [{"id": "a", "industry": "farm", "name": "n", "desc": "d", "requires": ["b"], "seconds": 1, "effects": []},
			{"id": "b", "industry": "farm", "name": "n", "desc": "d", "requires": ["a"], "seconds": 1, "effects": []}],
		"requires unknown": [{"id": "a", "industry": "farm", "name": "n", "desc": "d", "requires": ["zz"], "seconds": 1, "effects": []}],
		"neither a building type nor global": [{"id": "a", "industry": "spaceport", "name": "n", "desc": "d", "seconds": 1, "effects": []}],
		"makes things easier": [{"id": "a", "industry": "farm", "name": "n", "desc": "d", "seconds": 1, "effects": [{"kind": "cooldown", "type": "farm", "action": "water", "multiply": 1.5}]}],
		"unknown effect kind": [{"id": "a", "industry": "farm", "name": "n", "desc": "d", "seconds": 1, "effects": [{"kind": "skip_stage", "type": "farm"}]}],
		"waits for a proposal no letter makes": [{"id": "a", "industry": "farm", "name": "n", "desc": "d", "seconds": 1, "unlock": {"proposal": true}, "effects": []}],
	}
	for expected: String in cases:
		var data := GameData.from_tables({"research": {"nodes": cases[expected]}, "letters": {"letters": []}})
		assert_true("\n".join(data.errors).contains(expected), "refused: %s (%s)" % [expected, data.errors])
	var data := GameData.from_tables({"letters": {"letters": [{"id": "x", "industry": "farm", "trigger": {"work": {"farm": 1}}, "title": "t", "body": "b", "research": "warp_drive"}]}})
	assert_true("\n".join(data.errors).contains("proposes unknown research"), "letters must propose real nodes")


func test_same_outcome_whatever_the_step_size() -> void:
	var out: Array = []
	for chunk: int in [16, 1000, 7777]:
		var s := Simulation.new_game()
		var bs: BuildingSystem = s.system(&"buildings")
		bs.place_instant("research", Vector2i(0, 1))
		var f := bs.place_instant("farm", Vector2i(1, 0))
		s.execute({"type": "momo.assign", "momo": 1, "building": f})
		(s.system(&"economy") as EconomySystem).earn(100, "test")
		(s.system(&"inventory") as InventorySystem).add("notes", 3, "test")
		var started := false
		var t := 0
		while t < 30000 * 20:
			var step := mini(chunk, 30000 * 20 - t)
			s.advance_ms(step)
			t += step
			if not started and not (s.system(&"mail") as MailSystem).letters.is_empty():
				s.execute({"type": "mail.claim", "id": 1})
				started = s.execute({"type": "research.start", "id": "farm_expansion"})["ok"]
		var r: ResearchSystem = s.system(&"research")
		out.append([r.completed, (s.system(&"inventory") as InventorySystem).count("crop"), (s.system(&"economy") as EconomySystem).money])
	assert_true((out[0][0] as Dictionary).has("farm_expansion"), "researched in the run")
	assert_eq(out[1].slice(1), out[0].slice(1), "1 s steps: same crops and money")
