extends "res://tests/framework/test_case.gd"

## Forestry and mining: their cycles and waits, costs in money and materials,
## mastery, Momo who work them, ore tiers opened by prospecting research at
## exact fractional rates, and the economy around them.

var sim: Simulation
var bs: BuildingSystem
var inv: InventorySystem
var economy: EconomySystem
var research: ResearchSystem


func before_each() -> void:
	sim = Simulation.new_game()
	bs = sim.system(&"buildings")
	inv = sim.system(&"inventory")
	economy = sim.system(&"economy")
	research = sim.system(&"research")


func _by_hand(id: int, times: int) -> void:
	for i in times:
		var b := bs.get_building(id)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(maxi(bs.remaining_ms(b), 0) + 1)
		sim.execute({"type": "building.tap", "id": id})
		sim.advance_ms(maxi(bs.remaining_ms(bs.get_building(id)), 0) + 1)


func test_forestry_fells_then_replants_and_waits() -> void:
	var yard := bs.place_instant("lumberyard", Vector2i(1, 0))
	var b := bs.get_building(yard)
	assert_eq(bs.stages(b).map(func(st: Dictionary) -> String: return st["action"]), ["chop", "replant"], "fell one, plant one")
	sim.execute({"type": "building.tap", "id": yard})
	sim.advance_ms(6000)
	assert_eq(inv.count("wood"), 2, "a felled tree gives two wood")
	sim.execute({"type": "building.tap", "id": yard})
	sim.advance_ms(4000)
	assert_eq(b["state"], BuildingSystem.COOLDOWN, "then the sapling grows")
	assert_eq(bs.remaining_ms(b), 40000, "for 40 s")
	assert_eq(sim.execute({"type": "building.tap", "id": yard})["reason"], "err.cooldown", "no felling a sapling")


func test_the_mine_digs_stone_and_waits_for_the_props() -> void:
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	sim.execute({"type": "building.tap", "id": mine})
	sim.advance_ms(8000)
	assert_eq(inv.count("stone"), 1, "a load of stone")
	assert_eq(bs.remaining_ms(bs.get_building(mine)), 12000, "then 12 s to shore up and clear")
	assert_eq(inv.count("copper_ore"), 0, "no ore without prospecting")


func test_ore_tiers_come_at_exact_rates() -> void:
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	research.completed["copper_prospecting"] = 0
	research.completed["iron_prospecting"] = 0
	research.completed["deep_shaft"] = 0
	var got: Array = []
	for i in 40:
		var before := [inv.count("copper_ore"), inv.count("iron_ore"), inv.count("gold_ore")]
		_by_hand(mine, 1)
		got.append([inv.count("copper_ore") - before[0], inv.count("iron_ore") - before[1], inv.count("gold_ore") - before[2]])
	assert_eq(inv.count("stone"), 40, "stone every dig")
	assert_eq(inv.count("copper_ore"), 10, "copper 0.25 a dig: exactly 10 in 40")
	assert_eq(inv.count("iron_ore"), 8, "iron 0.2: exactly 8")
	assert_eq(inv.count("gold_ore"), 2, "gold 0.05: exactly 2")
	assert_eq(got.slice(0, 4).map(func(g: Array) -> int: return g[0]), [0, 0, 0, 1], "copper on the 4th dig, not by chance")
	assert_eq(int(bs.get_building(mine)["carry"].get("gold_ore", 0)), 0, "nothing left over after 40")


func test_fractions_carry_across_a_save() -> void:
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	research.completed["copper_prospecting"] = 0
	_by_hand(mine, 3)
	assert_eq(int(bs.get_building(mine)["carry"]["copper_ore"]), 750, "three quarters carried")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var cbs: BuildingSystem = copy.system(&"buildings")
	assert_eq(typeof(cbs.get_building(mine)["carry"]["copper_ore"]), TYPE_INT, "kept as whole thousandths")
	copy.advance_ms(13000)
	copy.execute({"type": "building.tap", "id": mine})
	copy.advance_ms(9000)
	assert_eq((copy.system(&"inventory") as InventorySystem).count("copper_ore"), 1, "the fourth dig after loading brings the copper")


func test_momo_run_industries_unattended_and_deterministically() -> void:
	var out: Array = []
	for chunk: int in [16, 1000, 9999]:
		var s := Simulation.new_game()
		var b2: BuildingSystem = s.system(&"buildings")
		var yard := b2.place_instant("lumberyard", Vector2i(1, 0))
		var mine := b2.place_instant("mine", Vector2i(0, 1))
		(s.system(&"economy") as EconomySystem).earn(100, "test")
		s.execute({"type": "momo.hire"})
		s.execute({"type": "momo.assign", "momo": 1, "building": yard})
		s.execute({"type": "momo.assign", "momo": 2, "building": mine})
		(s.system(&"research") as ResearchSystem).completed["copper_prospecting"] = 0
		var t := 0
		while t < 30000 * 30:
			var step := mini(chunk, 30000 * 30 - t)
			s.advance_ms(step)
			t += step
		var i2: InventorySystem = s.system(&"inventory")
		out.append([i2.count("wood"), i2.count("stone"), i2.count("copper_ore"), JSON.stringify(b2.get_building(mine)["carry"])])
	assert_true(int(out[0][0]) > 0 and int(out[0][1]) > 0 and int(out[0][2]) > 0, "wood, stone and copper came in (%s)" % [out[0]])
	assert_eq(out[1], out[0], "1 s steps: identical, fractions included")
	assert_eq(out[2], out[0], "10 s steps: identical")


func test_costs_in_money_and_materials() -> void:
	var p := sim.system(&"progression") as ProgressionSystem
	p.add_exp(1000, "test")
	economy.earn(500, "test")
	assert_eq(sim.execute({"type": "building.place", "building": "mine", "anchor": [1, 0]})["reason"], "err.not_enough_items", "a mine needs ten wood for its props")
	inv.add("wood", 10, "test")
	var money := economy.money
	var r := sim.execute({"type": "building.place", "building": "mine", "anchor": [1, 0]})
	assert_true(r["ok"], "with wood it is built")
	assert_eq(economy.money, money - 120, "paid $120")
	assert_eq(inv.count("wood"), 0, "and the ten wood")
	sim.execute({"type": "building.cancel", "id": r["id"]})
	assert_eq(inv.count("wood"), 10, "cancelling gives the wood back")


func test_unlock_levels_and_mastery() -> void:
	var catalog := {}
	for e: Dictionary in bs.catalog():
		catalog[e["type"]] = [e["unlocked"], e["level"]]
	assert_eq(catalog["lumberyard"], [false, 2], "the lumberyard opens at Lv 2")
	assert_eq(catalog["mine"], [false, 3], "the mine at Lv 3")
	var prog: ProgressionSystem = sim.system(&"progression")
	var yard := bs.place_instant("lumberyard", Vector2i(1, 0))
	_by_hand(yard, 2)
	assert_eq(int(prog.mastery_of("lumberyard")["exp"]), 10, "felling teaches forestry (replanting does not count twice)")


func test_materials_are_kept_not_sold() -> void:
	inv.add("wood", 20, "test")
	inv.add("stone", 5, "test")
	inv.add("crop", 2, "test")
	var money := economy.money
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	assert_eq(economy.money, money + 10, "only the crops were sold")
	assert_eq(inv.count("wood"), 20, "wood kept for building")
	assert_eq(inv.count("stone"), 5, "stone kept")


func test_research_for_the_new_branches() -> void:
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	var yard := bs.place_instant("lumberyard", Vector2i(0, 1))
	research.completed["pickaxes"] = 0
	research.completed["sharp_axes"] = 0
	research.completed["tree_nursery"] = 0
	var m := bs.get_building(mine)
	var y := bs.get_building(yard)
	assert_eq(bs.stage_seconds(m, bs.stages(m)[0]), 6.0, "steel picks: 8 s x 0.75")
	assert_near(bs.stage_seconds(y, bs.stages(y)[0]), 4.2, 0.0001, "sharp axes: 6 s x 0.7")
	assert_near(bs.stage_cooldown(y, bs.stages(y)[1]), 28.0, 0.0001, "nursery saplings: 40 s x 0.7")
	assert_eq(bs.cycle_estimate(m)["yield"], {"stone": 1.0}, "no ore yet")
	research.completed["copper_prospecting"] = 0
	assert_eq(bs.cycle_estimate(m)["yield"], {"stone": 1.0, "copper_ore": 0.25}, "copper prospecting adds a quarter")


func test_letters_from_the_new_industries() -> void:
	var yard := bs.place_instant("lumberyard", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": yard})
	sim.advance_ms(30000 * 12)
	var mail: MailSystem = sim.system(&"mail")
	assert_true(mail.letters.any(func(l: Dictionary) -> bool: return l["template"] == "lumber_first"), "the forester writes about a tree nursery")
