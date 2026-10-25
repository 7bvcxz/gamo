extends "res://tests/framework/test_case.gd"

## Special structures: landmarks, not a fifth production family -- one of
## each type at a time within the settlement's slots, built ones not offered,
## pulled down for half back and then a wait before that type can rise again
## (kept in the save: no reload clears it).

var sim: Simulation
var bs: BuildingSystem
var inv: InventorySystem
var economy: EconomySystem


func before_each() -> void:
	sim = Simulation.new_game()
	bs = sim.system(&"buildings")
	inv = sim.system(&"inventory")
	economy = sim.system(&"economy")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	economy.earn(5000, "test")
	for item: String in ["stone", "wood", "copper_ingot"]:
		inv.add(item, 50, "test")


func _place(type: String, cell: Vector2i) -> Dictionary:
	return sim.execute({"type": "building.place", "building": type, "anchor": [cell.x, cell.y]})


func test_three_landmarks_beside_the_four() -> void:
	assert_eq(bs.special_types(), ["clock_tower", "school", "momo_monument"] as Array[String], "Clock Tower, School, Momo Monument")
	assert_eq(bs.catalog().size(), 4, "the four families stay as they are")
	for t: String in bs.special_types():
		assert_false(bs.is_placeable(t), "%s is not a plain building" % t)
		assert_eq(bs.refits(bs.place_instant("farm", Vector2i(0, 0))).filter(func(e: Dictionary) -> bool: return e["type"] == t).size(), 0, "nor a refit")
		bs.demolish(bs.building_at(Vector2i(0, 0)))
	assert_eq(bs.special_slots(), 1, "a village has one special slot")


func test_one_of_each_within_the_slots() -> void:
	assert_true(_place("school", Vector2i(1, 1))["ok"], "a school")
	assert_eq(_place("school", Vector2i(2, 2))["reason"], "err.special_built", "never two")
	assert_eq(_place("clock_tower", Vector2i(2, 2))["reason"], "err.special_slots", "one slot, taken")
	assert_eq(bs.special_catalog().map(func(e: Dictionary) -> String: return e["type"]), ["clock_tower", "momo_monument"], "the school is no longer offered")
	assert_false(bs.special_catalog()[0]["slot_free"], "and the others say there is no slot")


func test_pulled_down_half_back_and_a_wait() -> void:
	var money := economy.money
	var stone := inv.count("stone")
	var r := _place("school", Vector2i(1, 1))
	sim.advance_ms(30000)
	var d := sim.execute({"type": "building.demolish", "id": r["id"]})
	assert_true(d["ok"], "pulled down")
	assert_eq(money - economy.money, 200, "half of $400 back")
	assert_eq(stone - inv.count("stone"), 10, "half of the stone back")
	assert_true(bs.special_catalog().map(func(e: Dictionary) -> String: return e["type"]).has("school"), "offered again")
	assert_eq(_place("school", Vector2i(1, 1))["reason"], "err.special_cooldown", "but not straight away")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	(copy.system(&"progression") as ProgressionSystem).level = 6
	assert_eq(copy.execute({"type": "building.place", "building": "school", "anchor": [1, 1]})["reason"], "err.special_cooldown", "a reload does not clear the wait")
	sim.advance_ms(180000)
	assert_true(_place("school", Vector2i(1, 1))["ok"], "after it, the school can rise again")


func test_no_momo_work_and_locks_shown() -> void:
	var r := _place("school", Vector2i(1, 1))
	var w := sim.execute({"type": "momo.watch", "momo": 1, "cells": [[1, 1]], "op": "add"})
	assert_eq(w["refused"], {"1,1": "err.no_work_here"}, "no Momo works a landmark")
	assert_true(bs.stages(bs.get_building(r["id"])).is_empty(), "no work cycle")
	(sim.system(&"progression") as ProgressionSystem).level = 4
	var entry: Dictionary = bs.special_catalog().filter(func(e: Dictionary) -> bool: return e["type"] == "momo_monument")[0]
	assert_eq([entry["unlocked"], entry["level"]], [false, 6], "the monument says it opens at Lv 6")


func test_a_special_may_not_be_a_family() -> void:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["school"]["family"] = "farm"
	b["types"]["clock_tower"]["workers"] = 2
	var text := "\n".join(GameData.from_tables({"buildings": b}).errors)
	assert_true(text.contains("special school must have no family"), "a landmark joined to a family is refused")
	assert_true(text.contains("special clock_tower must have no family, workers"), "one with workers too")
