extends "res://tests/framework/test_case.gd"

## Placing buildings from the catalog: checks, payment in money and items,
## construction time, cancellation with refund, level unlocks.

var sim: Simulation
var buildings: BuildingSystem
var economy: EconomySystem
var inv: InventorySystem
var world: WorldSystem


func _data() -> GameData:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["shed"] = {"name": "building.farm", "size": [2, 1], "cost": {"money": 20, "items": {"wood": 3}},
		"build_seconds": 8, "unlock": {"level": 3}, "enabled": true, "refund": 1.0,
		"cycle": {"stages": [{"id": "store", "seconds": 4, "cooldown": 10}]}}
	b["types"]["future"] = {"name": "building.farm", "size": [1, 1], "cost": {"money": 1, "items": {}},
		"build_seconds": 1, "unlock": {"level": 1}, "enabled": false, "cycle": {"stages": [{"id": "x", "seconds": 1}]}}
	# Construction on its own: the island's Momo does not take new buildings
	# by itself here (Step 50's momo.watch.auto has its own tests).
	var balance: Dictionary = GameData.load_default().table("balance").duplicate(true)
	balance["momo"]["watch"]["auto"] = false
	return GameData.from_tables({"buildings": b, "balance": balance})


func _build_ms(type: String) -> int:
	return int(float(sim.data.building_type(type)["build_seconds"]) * 1000.0)


func before_each() -> void:
	sim = Simulation.new_game(_data())
	buildings = sim.system(&"buildings")
	economy = sim.system(&"economy")
	inv = sim.system(&"inventory")
	world = sim.system(&"world")


func test_first_farm_is_affordable_and_quick_to_build() -> void:
	var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	assert_true(r["ok"], "the starting $10 buys a farm")
	assert_eq(economy.money, 0, "and that is all of it")
	var id: int = r["id"]
	var b := buildings.get_building(id)
	assert_eq(b["state"], BuildingSystem.CONSTRUCTING, "under construction")
	assert_eq(world.occupant(Vector2i(0, 0)), id, "occupying its cell at once")
	assert_eq(sim.execute({"type": "building.tap", "id": id})["reason"], "err.constructing", "not usable yet")
	sim.advance_ms(_build_ms("farm") - 1)
	assert_eq(b["state"], BuildingSystem.CONSTRUCTING, "a moment before: still building")
	sim.advance_ms(1)
	assert_eq(b["state"], BuildingSystem.IDLE, "on time: built and ready")
	assert_true(_build_ms("farm") <= 5000, "within five seconds")
	assert_true(sim.execute({"type": "building.tap", "id": id})["ok"], "and it works")


func test_placement_checks_change_nothing_when_they_fail() -> void:
	economy.earn(1000, "test")
	sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	var money := economy.money
	for case: Array in [[[0, 0], "err.occupied"], [[5, 5], "err.not_owned"], [[2, 0], "err.not_owned"]]:
		var r := sim.execute({"type": "building.place", "building": "farm", "anchor": case[0]})
		assert_eq(r["reason"], case[1], "%s -> %s" % case)
	assert_eq(sim.execute({"type": "building.place", "building": "nope", "anchor": [1, 1]})["reason"], "err.unknown_building", "unknown type")
	assert_eq(sim.execute({"type": "building.place", "building": "future", "anchor": [1, 1]})["reason"], "err.unknown_building", "disabled types are not offered")
	assert_eq(economy.money, money, "no money moved")
	assert_eq(world.occupancy.size(), 1, "no cell taken")


func test_not_enough_money_is_refused() -> void:
	economy.spend(5, "test")
	var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	assert_eq(r["reason"], "err.not_enough_money", "$5 cannot pay $10")
	assert_eq(r["cost"], 10, "and says the price")


func test_level_unlock_and_material_costs() -> void:
	economy.earn(1000, "test")
	assert_eq(sim.execute({"type": "building.place", "building": "shed", "anchor": [0, 0]})["reason"], "err.locked", "level 1 cannot build a level-3 shed")
	var listed := {}
	for entry: Dictionary in buildings.catalog():
		listed[entry["type"]] = entry["unlocked"]
	assert_true(listed["farm"], "the farm is open at Lv 1")
	assert_false(listed["shed"], "the Lv 3 shed is listed, locked")
	for t: String in listed:
		if t != "farm":
			assert_false(listed[t], "%s is listed but locked at Lv 1" % t)
	assert_eq(listed.keys(), ["farm", "research", "lumberyard", "mine", "shed"], "only placeable families are on the list -- facilities come by refit (%s)" % [listed.keys()])
	(sim.system(&"progression") as ProgressionSystem).level = 3
	var r := sim.execute({"type": "building.place", "building": "shed", "anchor": [0, 0]})
	assert_eq(r["reason"], "err.not_enough_items", "money is not enough: it needs wood")
	assert_eq(r["missing"], {"wood": 3}, "three wood short")
	inv.add("wood", 5)
	r = sim.execute({"type": "building.place", "building": "shed", "anchor": [0, 0]})
	assert_true(r["ok"], "with wood it builds")
	assert_eq(inv.count("wood"), 2, "three wood used")
	assert_eq(world.footprint(r["id"]), [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], "a 2x1 footprint")


func test_cancel_refunds_and_frees_the_cells() -> void:
	economy.earn(100, "test")
	(sim.system(&"progression") as ProgressionSystem).level = 3
	inv.add("wood", 3)
	var id: int = sim.execute({"type": "building.place", "building": "shed", "anchor": [0, 1]})["id"]
	sim.advance_ms(3000)
	var r := sim.execute({"type": "building.cancel", "id": id})
	assert_true(r["ok"], "cancelled mid-build")
	assert_eq(economy.money, 110, "money back")
	assert_eq(inv.count("wood"), 3, "wood back")
	assert_eq(world.buildable_cells().size(), 4, "cells free again")
	assert_true(buildings.get_building(id).is_empty(), "the building is gone")
	sim.advance_ms(10000)
	assert_true(buildings.get_building(id).is_empty(), "and its stale 'built' event did nothing")


func test_finished_buildings_cannot_be_cancelled() -> void:
	var id: int = sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})["id"]
	sim.advance_ms(5000)
	assert_eq(sim.execute({"type": "building.cancel", "id": id})["reason"], "err.not_constructing", "only constructions cancel")


func test_construction_never_blocks_other_work() -> void:
	economy.earn(100, "test")
	var a := buildings.place_instant("farm", Vector2i(0, 0))
	sim.execute({"type": "building.tap", "id": a})
	var b: int = sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 1]})["id"]
	sim.advance_ms(maxi(_build_ms("farm"), int(float(sim.data.building_type("farm")["cycle"]["stages"][0]["seconds"]) * 1000.0)))
	assert_eq(buildings.get_building(a)["completed"], 1, "the working farm finished on time")
	assert_eq(buildings.get_building(b)["state"], BuildingSystem.IDLE, "while the new one was built")


func test_save_mid_construction() -> void:
	var id: int = sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})["id"]
	sim.advance_ms(1000)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())), _data())
	var cb: BuildingSystem = copy.system(&"buildings")
	assert_eq(cb.get_building(id)["state"], BuildingSystem.CONSTRUCTING, "still building after load")
	copy.advance_ms(_build_ms("farm") - 1000 - 1)
	assert_eq(cb.get_building(id)["state"], BuildingSystem.CONSTRUCTING, "not early")
	copy.advance_ms(1)
	assert_eq(cb.get_building(id)["state"], BuildingSystem.IDLE, "built at the original time")
	assert_eq(cb.get_building(id)["paid"]["money"], 10, "remembers what it cost")
