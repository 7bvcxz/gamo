extends "res://tests/framework/test_case.gd"

## Four building families on land -- farm, mine, lumberyard, lab -- and
## everything else a facility one of them is refitted into, in place;
## demolition with half of what was paid back; old islands kept whole.

var sim: Simulation
var bs: BuildingSystem
var economy: EconomySystem
var inv: InventorySystem


func before_each() -> void:
	sim = Simulation.new_game()
	bs = sim.system(&"buildings")
	economy = sim.system(&"economy")
	inv = sim.system(&"inventory")
	economy.earn(5000, "test")
	(sim.system(&"progression") as ProgressionSystem).add_exp(20000, "test")


func test_exactly_four_families_are_placed() -> void:
	var placeable := bs.catalog().map(func(e: Dictionary) -> String: return e["type"])
	assert_eq(placeable, ["farm", "research", "lumberyard", "mine"], "farm, lab, lumberyard, mine")
	for type: String in GameData.load_default().table("buildings")["types"]:
		assert_true(["farm", "mine", "lumberyard", "research"].has(bs.family_of(type)), "%s belongs to one of the four" % type)
	assert_eq(sim.execute({"type": "building.place", "building": "office", "anchor": [0, 0]})["reason"], "err.not_placeable", "an office is not placed on land")


func test_refit_in_place() -> void:
	inv.add("stone", 20, "test")
	inv.add("wood", 10, "test")
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": mine})
	var money := economy.money
	var r := sim.execute({"type": "building.refit", "id": mine, "building": "smelter"})
	assert_true(r["ok"], "a mine becomes a smelter")
	var b := bs.get_building(mine)
	assert_eq([b["id"], b["type"], b["anchor"]], [mine, "smelter", [1, 0]], "same building, same tile, new facility")
	assert_eq(b["state"], BuildingSystem.CONSTRUCTING, "the refit takes the facility's build time")
	assert_eq(economy.money, money - 200, "paid the facility's price")
	assert_eq(int((sim.system(&"momo") as MomoSystem).get_momo(1)["assigned"]), 0, "its worker was let go (a new job)")
	sim.advance_ms(20000)
	assert_eq(b["state"], BuildingSystem.IDLE, "and it is ready")
	assert_eq(sim.execute({"type": "building.refit", "id": mine, "building": "solar_panel"})["reason"], "err.wrong_family", "a mine cannot become a lab facility")


func test_a_busy_building_stops_and_gets_its_inputs_back() -> void:
	inv.add("stone", 40, "test")
	inv.add("wood", 30, "test")
	inv.add("copper_ore", 10, "test")
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	sim.execute({"type": "building.refit", "id": mine, "building": "smelter"})
	sim.advance_ms(30000)
	var ore := inv.count("copper_ore")
	var r := sim.execute({"type": "building.tap", "id": mine})
	assert_true(r["ok"], "the smelter starts a charge")
	assert_true(inv.count("copper_ore") < ore, "taking its ore")
	assert_eq(bs.get_building(mine)["state"], BuildingSystem.WORKING, "working")
	var d := sim.execute({"type": "building.demolish", "id": mine})
	assert_true(d["ok"], "a working building can still be pulled down")
	assert_eq(inv.count("copper_ore"), ore, "the charge's ore is back")
	sim.advance_ms(60000)
	assert_eq(inv.count("copper_ingot"), 0, "and nothing comes out of a building that is gone")


func test_refits_list_the_family() -> void:
	var lab := bs.place_instant("research", Vector2i(1, 0))
	var kinds := bs.refits(lab).map(func(e: Dictionary) -> String: return e["type"])
	for t: String in ["solar_panel", "office", "apartment", "community_center", "game_studio"]:
		assert_true(kinds.has(t), "a lab can become a %s" % t)
	assert_false(kinds.has("research"), "not itself")
	assert_false(kinds.has("smelter"), "nor another family's facility")


func test_demolish_refunds_half_of_what_was_paid() -> void:
	inv.add("wood", 25, "test")
	inv.add("stone", 25, "test")
	var r := sim.execute({"type": "building.place", "building": "mine", "anchor": [1, 0]})
	assert_true(r["ok"], "a mine: $120 + wood 10")
	var id := int(r["id"])
	sim.advance_ms(16000)
	sim.execute({"type": "building.refit", "id": id, "building": "smelter"})
	sim.advance_ms(21000)
	var money := economy.money
	var wood := inv.count("wood")
	var stone := inv.count("stone")
	var d := sim.execute({"type": "building.demolish", "id": id})
	assert_true(d["ok"], "pulled down")
	assert_eq(economy.money - money, 160, "half of $120 + $200")
	assert_eq(inv.count("wood") - wood, 10, "half of 10 + 10 wood")
	assert_eq(inv.count("stone") - stone, 10, "half of 20 stone")
	assert_true(bs.get_building(id).is_empty(), "gone")
	assert_false((sim.system(&"world") as WorldSystem).is_occupied(Vector2i(1, 0)), "the tile is free")


func test_half_is_rounded_down() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	bs.get_building(farm)["paid"] = {"money": 15, "items": {"wood": 3}}
	var money := economy.money
	sim.execute({"type": "building.demolish", "id": farm})
	assert_eq(economy.money - money, 7, "$15 -> $7")
	assert_eq(inv.count("wood"), 1, "3 wood -> 1")


func test_demolish_lets_workers_go_and_cancel_stays_full() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.execute({"type": "building.demolish", "id": farm})
	assert_eq(int((sim.system(&"momo") as MomoSystem).get_momo(1)["assigned"]), 0, "the Momo is free again")
	var money := economy.money
	var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})
	sim.execute({"type": "building.demolish", "id": r["id"]})
	assert_eq(economy.money, money, "under construction: cancelled with everything back")


func test_an_old_island_keeps_its_facilities() -> void:
	var smelter := bs.place_instant("smelter", Vector2i(1, 0))
	var solar := bs.place_instant("solar_panel", Vector2i(0, 1))
	var state := sim.save_state()
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	var cbs: BuildingSystem = copy.system(&"buildings")
	assert_eq(cbs.get_building(smelter)["type"], "smelter", "a smelter stays a smelter")
	assert_eq(cbs.family_of("smelter"), "mine", "now counted as a mine's facility")
	assert_eq(cbs.get_building(solar)["type"], "solar_panel", "the solar array stays, as the lab's roof")
	assert_true((copy.system(&"power") as PowerSystem).capacity() > 0.0, "and still generates")


func test_bad_families_are_refused() -> void:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["office"]["placeable"] = true
	b["types"]["pub"]["family"] = "tavern"
	var text := "\n".join(GameData.from_tables({"buildings": b}).errors)
	assert_true(text.contains("exactly farm, mine, lumberyard and research are placeable"), "a fifth placeable family")
	assert_true(text.contains("family tavern"), "a facility of no family")
