extends "res://tests/framework/test_case.gd"

## Step 53: every new island -- a new game or the one after a sale -- begins
## with no Momo. The player works alone, earns at once, and chooses to hire;
## a hire arrives idle and is never put to work by anyone but the player. The
## island's own automation (new buildings taken into a Momo's rounds, the
## manager) touches only a Momo the player has placed (`opted_in`). Saves
## made before keep their Momo and allocations.


func _island() -> Simulation:
	return Simulation.new_island()


func test_a_new_island_has_no_momo_and_pays_for_work_by_hand() -> void:
	var sim := _island()
	var momos: MomoSystem = sim.system(&"momo")
	var eco: EconomySystem = sim.system(&"economy")
	assert_eq(momos.ids().size(), 0, "nobody but the player")
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm: int = bs.ids()[0]
	var money := eco.money
	assert_true(sim.execute({"type": "building.tap", "id": farm})["ok"], "the ripe crop, by hand")
	sim.advance_to(int(bs.get_building(farm)["task_end"]))
	assert_true(eco.money > money, "pays at once (Step 50 kept)")


func test_the_first_hire_is_reached_by_ordinary_work() -> void:
	var sim := _island()
	var momos: MomoSystem = sim.system(&"momo")
	var eco: EconomySystem = sim.system(&"economy")
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm: int = bs.ids()[0]
	assert_eq(momos.hire_cost(), sim.data.get_int("balance", "momo.hire.first", 0), "the first Momo has its own price")
	# The farm by hand, as fast as its stages allow, until the hire is affordable.
	var t := 0
	while not eco.can_afford(momos.hire_cost()) and t < 10 * 60000:
		if bs.get_building(farm)["state"] == BuildingSystem.IDLE:
			sim.execute({"type": "building.tap", "id": farm})
		sim.advance_ms(500)
		t += 500
	assert_true(eco.can_afford(momos.hire_cost()), "affordable by hand")
	assert_true(t <= 90000, "within a minute and a half of farming (%d s): no paywall" % (t / 1000))


func test_hires_arrive_idle_and_stay_the_players_to_place() -> void:
	var sim := _island()
	var momos: MomoSystem = sim.system(&"momo")
	var bs: BuildingSystem = sim.system(&"buildings")
	(sim.system(&"economy") as EconomySystem).earn(5000, "test")
	bs.place_instant("mine", Vector2i(1, 0))
	bs.place_instant("lumberyard", Vector2i(0, 1))
	var first := momos.hire_cost()
	var a := sim.execute({"type": "momo.hire"})
	var second := momos.hire_cost()
	var b := sim.execute({"type": "momo.hire"})
	var third := momos.hire_cost()
	assert_true(a["ok"] and b["ok"], "two hires")
	assert_eq([first, second, third], [15, 90, 145], "the first at its price, then the old ladder (90 x 1.6)")
	sim.advance_ms(3 * 60000)
	for id: int in momos.ids():
		var m := momos.get_momo(id)
		assert_eq(int(m["assigned"]), 0, "Momo %d works nowhere" % id)
		assert_true(momos.watched(id).is_empty(), "and watches nothing")
		assert_false(m["opted_in"], "nobody has placed it")
	for id: int in bs.ids():
		assert_true(momos.watchers_of(id).is_empty(), "every building still the player's to staff")


func test_the_players_first_placement_opts_in_and_new_work_follows() -> void:
	var sim := _island()
	var momos: MomoSystem = sim.system(&"momo")
	var bs: BuildingSystem = sim.system(&"buildings")
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	var farm: int = bs.ids()[0]
	var id := int(sim.execute({"type": "momo.hire"})["id"])
	assert_true(sim.execute({"type": "momo.assign", "momo": id, "building": farm})["ok"], "the player places it")
	assert_true(momos.get_momo(id)["opted_in"], "now it is in")
	var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})
	sim.advance_ms(build_ms(sim, "farm"))
	assert_eq(momos.watchers_of(int(r["id"])), [id] as Array[int], "a Momo the player put to work takes new work into its rounds")


func test_the_choice_survives_a_save() -> void:
	var sim := _island()
	var momos: MomoSystem = sim.system(&"momo")
	var bs: BuildingSystem = sim.system(&"buildings")
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	var placed := int(sim.execute({"type": "momo.hire"})["id"])
	var idle := int(sim.execute({"type": "momo.hire"})["id"])
	sim.execute({"type": "momo.assign", "momo": placed, "building": bs.ids()[0]})
	sim.execute({"type": "momo.watch", "momo": placed, "cells": [[1, 1]], "op": "add"})
	momos.free_hires = 2
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var m2: MomoSystem = copy.system(&"momo")
	assert_eq(m2.ids(), momos.ids(), "both Momo")
	assert_eq(m2.watched(placed), momos.watched(placed), "the tiles the player chose")
	assert_eq(int(m2.get_momo(placed)["assigned"]), bs.ids()[0], "and where it works")
	assert_true(m2.get_momo(placed)["opted_in"], "still the player's placed Momo")
	assert_false(m2.get_momo(idle)["opted_in"], "the idle one still idle")
	assert_eq(m2.free_hires, 2, "free hires kept")
	assert_eq(m2.bought_first, momos.bought_first, "and the first price used")
	copy.advance_ms(3 * 60000)
	assert_eq(int(m2.get_momo(idle)["assigned"]), 0, "nothing places it after a load either")


func test_a_save_from_before_keeps_its_momo_working() -> void:
	# A Step 52 save: the starting Momo at work, a hire standing idle, and no
	# `opted_in` written anywhere.
	var sim := with_starter_momo(Simulation.new_game())
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	sim.execute({"type": "momo.hire"})
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var state: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	var raw: Dictionary = state["systems"]["momo"]
	raw.erase("free_hires")
	raw.erase("bought_first")
	for m: Dictionary in raw["momos"]:
		m.erase("opted_in")
	var copy := Simulation.from_save(state)
	var m2: MomoSystem = copy.system(&"momo")
	assert_eq(m2.ids().size(), 2, "every Momo the player had")
	assert_true(m2.get_momo(1)["opted_in"], "the one at work counts as placed")
	assert_false(m2.get_momo(2)["opted_in"], "the idle one waits for the player")
	assert_eq(int(m2.get_momo(1)["assigned"]), farm, "its work kept")
	copy.advance_ms(60000)
	assert_true(int((copy.system(&"buildings") as BuildingSystem).get_building(farm)["completed"]) > 0, "and it keeps working")


func test_a_sold_island_gives_free_hires_not_momo() -> void:
	var sim := _island()
	var p: PrestigeSystem = sim.system(&"prestige")
	p.adopt({"points": 10})
	var momos: MomoSystem = sim.system(&"momo")
	var eco: EconomySystem = sim.system(&"economy")
	assert_eq(momos.ids().size(), 0, "the new island starts empty")
	assert_eq(momos.free_hires, p.start_momo_bonus(), "the legacy's Momo are free hires (%d)" % momos.free_hires)
	assert_true(momos.free_hires > 0, "10 points give some")
	var money := eco.money
	for i in momos.free_hires:
		assert_eq(momos.hire_cost(), 0, "free")
		assert_true(sim.execute({"type": "momo.hire"})["ok"], "hired when the player chooses")
	assert_eq(eco.money, money, "for nothing")
	assert_eq(momos.hired, 0, "not counted on the price ladder")
	assert_eq(momos.hire_cost(), 90, "after them, the ladder from its start")
	for id: int in momos.ids():
		assert_eq(int(momos.get_momo(id)["assigned"]), 0, "each idle until placed")


func test_an_empty_island_can_still_hire() -> void:
	var sim := Simulation.new_game()
	var momos: MomoSystem = sim.system(&"momo")
	assert_true((sim.system(&"buildings") as BuildingSystem).ids().is_empty(), "nothing built")
	(sim.system(&"economy") as EconomySystem).earn(100, "test")
	var r := sim.execute({"type": "momo.hire"})
	assert_true(r["ok"], "a Momo for an island with no work yet")
	var p := momos.position_of(int(r["id"]))
	assert_true((sim.system(&"world") as WorldSystem).is_owned(Vector2i(floori(p.x), floori(p.y))), "standing on it")
