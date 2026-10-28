extends "res://tests/framework/test_case.gd"

## Smelting: recipes take their inputs (fuel included) when a batch starts and
## give their outputs when it ends -- nothing from nothing, nothing half-
## charged, nothing thrown away -- at the time, wait and batch size the data
## and research say.

var sim: Simulation
var bs: BuildingSystem
var inv: InventorySystem
var research: ResearchSystem
var smelter := 0


func before_each() -> void:
	# The industry's own rules at the data's pace (Step 58: test_pace checks
	# the work and travel scales).
	sim = with_starter_momo(Simulation.new_game(unit_pace()))
	bs = sim.system(&"buildings")
	inv = sim.system(&"inventory")
	research = sim.system(&"research")
	smelter = bs.place_instant("smelter", Vector2i(1, 0))


func test_a_batch_takes_inputs_at_the_start_and_gives_at_the_end() -> void:
	inv.add("copper_ore", 5, "test")
	inv.add("wood", 3, "test")
	var r := sim.execute({"type": "building.tap", "id": smelter})
	assert_true(r["ok"], "charged")
	assert_eq([inv.count("copper_ore"), inv.count("wood")], [3, 2], "two ore and one wood went in at once")
	assert_eq(inv.count("copper_ingot"), 0, "nothing out yet")
	sim.advance_ms(10000)
	assert_eq(inv.count("copper_ingot"), 1, "one ingot after 10 s")
	assert_eq(bs.remaining_ms(bs.get_building(smelter)), 5000, "then 5 s for the crucible to cool")


func test_without_inputs_nothing_starts_and_nothing_is_taken() -> void:
	inv.add("copper_ore", 1, "test")
	var r := sim.execute({"type": "building.tap", "id": smelter})
	assert_eq(r["reason"], "err.missing_inputs", "not enough to charge")
	assert_eq(r["missing"], {"copper_ore": 1, "wood": 1}, "short by one ore and the fuel")
	assert_eq(inv.count("copper_ore"), 1, "the one ore is still there")
	assert_eq(bs.blocked(bs.get_building(smelter)), {"missing": {"copper_ore": 1, "wood": 1}}, "and the building says why")


func test_a_full_store_sells_the_ingot() -> void:
	# Ingots have a surplus price (Step 50): what the store has no room for
	# is sold at once instead of stopping the furnace -- never thrown away.
	inv.add("copper_ore", 2, "test")
	inv.add("wood", 1, "test")
	inv.add("copper_ingot", inv.capacity("copper_ingot"), "test")
	var economy: EconomySystem = sim.system(&"economy")
	assert_eq(bs.blocked(bs.get_building(smelter)), {}, "a full store of ingots does not block the smelter")
	assert_true(sim.execute({"type": "building.tap", "id": smelter})["ok"], "it charges")
	var money := economy.money
	var b := bs.get_building(smelter)
	sim.advance_ms(bs.remaining_ms(b) + 1)
	assert_eq(inv.count("copper_ingot"), inv.capacity("copper_ingot"), "the store stays full")
	assert_eq(economy.money - money, economy.unit_price("copper_ingot"), "and the ingot that did not fit was sold")


func test_recipes_open_through_research_and_change_when_empty() -> void:
	assert_eq(bs.recipes("smelter"), ["copper_ingot", "iron_ingot", "gold_ingot"] as Array[String], "three recipes")
	assert_eq(sim.execute({"type": "building.recipe", "id": smelter, "recipe": "iron_ingot"})["reason"], "err.recipe_locked", "iron needs the bloomery")
	research.completed["bloomery"] = 0
	inv.add("copper_ore", 2, "test")
	inv.add("wood", 1, "test")
	sim.execute({"type": "building.tap", "id": smelter})
	assert_eq(sim.execute({"type": "building.recipe", "id": smelter, "recipe": "iron_ingot"})["reason"], "err.recipe_busy", "not with copper in the crucible")
	sim.advance_ms(15000)
	assert_true(sim.execute({"type": "building.recipe", "id": smelter, "recipe": "iron_ingot"})["ok"], "empty: iron")
	var st := bs.current_stage(bs.get_building(smelter))
	assert_eq(st["consumes"], {"iron_ore": 2, "wood": 2}, "iron takes more fuel")
	assert_eq(st["seconds"], 14.0, "and longer")
	assert_eq(sim.execute({"type": "building.recipe", "id": smelter, "recipe": "tin"})["reason"], "err.no_recipe", "unknown")


func test_a_larger_crucible_holds_two_batches() -> void:
	research.completed["larger_crucible"] = 0
	var st := bs.current_stage(bs.get_building(smelter))
	assert_eq(st["consumes"], {"copper_ore": 4, "wood": 2}, "twice the charge")
	assert_eq(st["yield"], {"copper_ingot": 2}, "twice the ingots")
	assert_eq(st["seconds"], 20.0, "twice the smelting")
	assert_eq(st["cooldown"], 5.0, "one cooling")


func test_bellows_speed_the_work() -> void:
	research.completed["bellows"] = 0
	var b := bs.get_building(smelter)
	assert_eq(bs.stage_seconds(b, bs.current_stage(b)), 7.5, "10 s x 0.75")


func test_a_momo_waits_for_ore_and_starts_when_it_comes() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": smelter})
	sim.advance_ms(10000)
	assert_eq(bs.get_building(smelter)["state"], BuildingSystem.IDLE, "nothing to smelt: Momo waits")
	inv.add("copper_ore", 2, "test")
	assert_eq(bs.get_building(smelter)["state"], BuildingSystem.IDLE, "ore without fuel is not enough")
	inv.add("wood", 1, "test")
	assert_eq(bs.get_building(smelter)["state"], BuildingSystem.WORKING, "with fuel the furnace is charged at once")
	assert_eq(int(bs.get_building(smelter)["worker"]), 1, "by Momo")


func test_nothing_appears_without_work_or_is_lost() -> void:
	# A whole chain run by Momo: mine -> ore, lumberyard -> wood, smelter -> ingots.
	var p := sim.system(&"progression") as ProgressionSystem
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	for i in 2:
		sim.execute({"type": "momo.hire"})
	var mine := bs.place_instant("mine", Vector2i(0, 1))
	var yard := bs.place_instant("lumberyard", Vector2i(1, 1))
	research.completed["copper_prospecting"] = 0
	sim.execute({"type": "momo.assign", "momo": 1, "building": smelter})
	sim.execute({"type": "momo.assign", "momo": 2, "building": mine})
	sim.execute({"type": "momo.assign", "momo": 3, "building": yard})
	var gained := {}
	var spent := {}
	var odd: Array = []
	sim.bus.emitted.connect(func(t: StringName, pl: Dictionary) -> void:
		if t != &"inventory_changed":
			return
		var d := int(pl["delta"])
		var item := String(pl["item"])
		var why := String(pl.get("reason", ""))
		if d > 0:
			gained[item] = int(gained.get(item, 0)) + d
			if not why.begins_with("yield:"):
				odd.append(why)
		else:
			spent[item] = int(spent.get(item, 0)) - d
			if not why.begins_with("consume:"):
				odd.append(why))
	sim.advance_ms(30000 * 40)
	assert_eq(odd, [], "every gain came from work, every loss into a furnace")
	assert_true(int(gained.get("copper_ingot", 0)) > 0, "ingots were made (%s)" % [gained])
	assert_eq(int(spent.get("copper_ore", 0)), 2 * int(gained.get("copper_ingot", 0)) + 2 * int(bs.get_building(smelter)["state"] == BuildingSystem.WORKING), "two ore per ingot, exactly")
	for item: String in ["copper_ore", "wood", "copper_ingot", "stone"]:
		assert_eq(inv.count(item), int(gained.get(item, 0)) - int(spent.get(item, 0)), "%s: store = made - used" % item)
	assert_true(p != null, "")


func test_save_mid_smelt_keeps_what_went_in() -> void:
	inv.add("copper_ore", 2, "test")
	inv.add("wood", 1, "test")
	sim.execute({"type": "building.tap", "id": smelter})
	sim.advance_ms(4000)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())), sim.data)
	var ci: InventorySystem = copy.system(&"inventory")
	assert_eq(ci.count("copper_ore"), 0, "the charge is in the furnace, not back in the store")
	copy.advance_ms(6000)
	assert_eq(ci.count("copper_ingot"), 1, "and comes out as an ingot after loading")


func test_costs_money_and_materials() -> void:
	(sim.system(&"progression") as ProgressionSystem).add_exp(3000, "test")
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	inv.add("wood", 10, "test")
	assert_eq(sim.execute({"type": "building.place", "building": "smelter", "anchor": [0, 1]})["reason"], "err.not_placeable", "a smelter is not placed on land: a mine is refitted")
	var mine := bs.place_instant("mine", Vector2i(0, 1))
	assert_eq(sim.execute({"type": "building.refit", "id": mine, "building": "smelter"})["reason"], "err.not_enough_items", "stone for the furnace walls is missing")
	inv.add("stone", 20, "test")
	assert_true(sim.execute({"type": "building.refit", "id": mine, "building": "smelter"})["ok"], "with stone and wood the mine becomes a smelter")
	assert_eq([inv.count("stone"), inv.count("wood")], [0, 0], "both used")


func test_bad_recipes_are_refused() -> void:
	var data := GameData.from_tables({"recipes": {"recipes": [
		{"id": "copper_ingot", "building": "smelter", "name": "n", "inputs": {}, "outputs": {"copper_ingot": 1}, "seconds": 5, "default": true},
		{"id": "iron_ingot", "building": "smelter", "name": "n", "inputs": {"unobtainium": 1}, "outputs": {"iron_ingot": 1}, "seconds": 5},
		{"id": "gold_ingot", "building": "farm", "name": "n", "inputs": {"gold_ore": 1}, "outputs": {"gold_ingot": 1}, "seconds": 0},
	]}})
	var text := "\n".join(data.errors)
	assert_true(text.contains("nothing from nothing"), "a recipe with no inputs")
	assert_true(text.contains("unknown item"), "an unknown input")
	assert_true(text.contains("does not list it"), "a building that does not run it")
	assert_true(text.contains("seconds must be > 0"), "no time")


func test_same_chain_whatever_the_step() -> void:
	var out: Array = []
	for chunk: int in [16, 1000, 7777]:
		var s := with_starter_momo(Simulation.new_game())
		var b2: BuildingSystem = s.system(&"buildings")
		var sm := b2.place_instant("smelter", Vector2i(1, 0))
		(s.system(&"inventory") as InventorySystem).add("copper_ore", 20, "test")
		(s.system(&"inventory") as InventorySystem).add("wood", 10, "test")
		s.execute({"type": "momo.assign", "momo": 1, "building": sm})
		var t := 0
		# Room for sixteen charges (each a smelt and its cooling, Step 69's pace).
		var total := int(float(b2.cycle_estimate(b2.get_building(sm))["cycle_seconds"]) * 1000.0 * 16.0)
		while t < total:
			var step := mini(chunk, total - t)
			s.advance_ms(step)
			t += step
		var i2: InventorySystem = s.system(&"inventory")
		out.append([i2.count("copper_ore"), i2.count("wood"), i2.count("copper_ingot")])
	assert_eq(out[1], out[0], "1 s steps")
	assert_eq(out[2], out[0], "7.8 s steps")
	assert_eq(out[0][2], 10, "all twenty ore became ten ingots")
