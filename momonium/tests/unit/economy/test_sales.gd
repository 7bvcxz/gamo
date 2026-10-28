extends "res://tests/framework/test_case.gd"

## Finished work is money at once (Step 50): a harvest's crops are sold the
## moment they are picked at their data price, a mine's dig pays its revenue
## as it completes, what the store has no room for is sold instead of stopping
## the work -- and nothing is ever paid twice: the day boundary sells nothing,
## only closes the book. Every dollar is booked; the store has limits.

var sim: Simulation
var economy: EconomySystem
var inv: InventorySystem
var buildings: BuildingSystem


func _start(data: GameData = null) -> void:
	sim = Simulation.new_game(data)
	economy = sim.system(&"economy")
	inv = sim.system(&"inventory")
	buildings = sim.system(&"buildings")


func before_each() -> void:
	_start()


## Runs a farm through one full cycle by tapping whenever it is ready.
func _grow_one_batch(farm: int) -> void:
	for i in buildings.stages(buildings.get_building(farm)).size():
		var b := buildings.get_building(farm)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(buildings.remaining_ms(b))
		sim.execute({"type": "building.tap", "id": farm})
		sim.advance_ms(int(float(buildings.current_stage(b)["seconds"]) * work_scale(sim) * 1000.0))
	var b := buildings.get_building(farm)
	if b["state"] != BuildingSystem.IDLE:
		sim.advance_ms(buildings.remaining_ms(b))


func test_a_harvest_is_money_the_moment_it_is_picked() -> void:
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	var sold: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"sold":
			sold.append(p))
	var before := economy.money
	_grow_one_batch(farm)
	assert_eq(economy.money, before + economy.unit_price("crop"), "paid at once")
	assert_eq(inv.count("crop"), 0, "the crop never waits in the store")
	assert_eq(sold.size(), 1, "one sale")
	assert_eq(int(sold[0]["id"]), farm, "of this farm (the +$ shows over it)")
	assert_eq(int(sold[0]["worker"]), 0, "by the player's hands")
	assert_eq((sold[0]["items"] as Dictionary), {"crop": 1}, "one batch of crops")
	assert_eq(int(inv.produced.get("crop", 0)), 1, "still counted as made")


func test_price_comes_from_data() -> void:
	var items: Dictionary = GameData.load_default().table("items").duplicate(true)
	items["items"]["crop"]["price"] = 12
	_start(GameData.from_tables({"items": items}))
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	_grow_one_batch(farm)
	assert_eq(economy.money, sim.data.get_int("balance", "start.money") + 12, "one batch at $12")


func test_the_day_boundary_sells_nothing() -> void:
	# A crop that is somehow in the store (an old save's leftovers are sold
	# once when it is opened, SaveMigration) is not sold again at dawn.
	inv.add("crop", 2)
	inv.add("wood", 4)
	var sold: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"sold":
			sold.append(p))
	var before := economy.money
	sim.advance_to(sim.clock.next_day_start_ms())
	assert_eq(sold.size(), 0, "no sale at dawn")
	assert_eq(economy.money, before, "no money from nothing")
	assert_eq(inv.count("wood"), 4, "wood is kept for building")


func test_no_payout_twice() -> void:
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	var paid := [0]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"sold":
			paid[0] += int(p["money"]))
	var before := economy.money
	for i in 30:
		_grow_one_batch(farm)
	sim.advance_ms(sim.clock.day_ms * 3)
	var harvests := int(buildings.get_building(farm)["completed"]) / buildings.stages(buildings.get_building(farm)).size()
	assert_eq(harvests, 30, "thirty harvests across several days")
	assert_eq(economy.money - before, harvests * economy.unit_price("crop"), "paid once each, and only once")
	assert_eq(paid[0], economy.money - before, "every dollar from a sale event")
	assert_eq(int(economy.lifetime.get("sale", 0)), paid[0], "booked as sales")


func test_a_mine_pays_as_it_digs_and_keeps_the_stone() -> void:
	var mine := buildings.place_instant("mine", Vector2i(0, 0))
	var dig: Dictionary = buildings.current_stage(buildings.get_building(mine))
	var before := economy.money
	sim.execute({"type": "building.tap", "id": mine})
	sim.advance_ms(int(float(dig["seconds"]) * work_scale(sim) * 1000.0))
	assert_eq(economy.money - before, buildings.revenue_of(buildings.get_building(mine), dig), "the ore at the face is sold as it comes out")
	assert_true(economy.money > before, "money at once")
	assert_eq(inv.count("stone"), int(dig["yield"]["stone"]), "the stone kept for building")
	var cycle := float(dig["seconds"]) * work_scale(sim) + float(dig["cooldown"])
	assert_near(cycle, 31.0, 0.0001, "thirty-one seconds for each unit dug (Step 69: 4 s of digging x6.25 + the 6 s wait; Step 58: 16 s, Step 50: 10 s)")


func test_a_full_store_sells_the_surplus_instead_of_stopping() -> void:
	inv.add("stone", inv.capacity("stone"))
	var mine := buildings.place_instant("mine", Vector2i(0, 0))
	var dig: Dictionary = buildings.current_stage(buildings.get_building(mine))
	var before := economy.money
	assert_true(sim.execute({"type": "building.tap", "id": mine})["ok"], "a full store of stone does not stop the mine")
	sim.advance_ms(int(float(dig["seconds"]) * work_scale(sim) * 1000.0))
	assert_eq(inv.count("stone"), inv.capacity("stone"), "the store stays full")
	assert_eq(economy.money - before, buildings.revenue_of(buildings.get_building(mine), dig) + economy.unit_price("stone"), "the stone that did not fit was sold, not thrown away")


func test_what_cannot_be_sold_still_needs_room() -> void:
	inv.add("notes", inv.capacity("notes"))
	var lab := buildings.place_instant("research", Vector2i(0, 0))
	var r := sim.execute({"type": "building.tap", "id": lab})
	assert_eq(r["reason"], "err.storage_full", "research notes are never sold: a full store stops the lab")
	assert_eq(buildings.get_building(lab)["state"], BuildingSystem.IDLE, "and it has not started")


func test_every_dollar_is_booked_by_day() -> void:
	economy.earn(200, "test")
	sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	sim.execute({"type": "land.buy", "cell": [2, 0]})
	var farm := buildings.building_at(Vector2i(0, 0))
	sim.advance_ms(build_ms(sim, "farm"))
	# The island's Momo took the new farm by itself (Step 50); here the
	# player farms it, so the day holds exactly one harvest.
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0]], "op": "remove"})
	_grow_one_batch(farm)
	sim.advance_to(sim.clock.next_day_start_ms())
	var day1: Dictionary = economy.history[-1]
	assert_eq(day1["day"], 1, "Day 1 closed")
	var farm_cost := int(sim.data.building_type("farm")["cost"]["money"])
	assert_eq(day1["by"]["build"], -farm_cost, "farm")
	var plot := (sim.system(&"land") as LandSystem).cost_of(0)
	assert_eq(day1["by"]["land"], -plot, "land")
	assert_eq(day1["by"]["sale"], economy.unit_price("crop"), "the harvest's sale on the day it was picked")
	assert_eq(day1["expense"], farm_cost + plot, "farm and land out")
	assert_eq(day1["close"], sim.data.get_int("balance", "start.money") + 200 - farm_cost - plot + economy.unit_price("crop"), "closing balance")
	sim.advance_to(sim.clock.next_day_start_ms())
	assert_eq(economy.history.size(), 2, "an empty day is still a day")
	assert_eq(economy.history[-1]["income"], 0, "with nothing in it")


func test_history_is_bounded() -> void:
	sim.advance_ms(sim.clock.day_ms * 45)
	assert_eq(economy.history.size(), 30, "thirty days kept")
	assert_eq(economy.history[-1]["day"], 45, "the newest last")


func test_ledger_and_store_survive_a_save() -> void:
	inv.add("wood", 3)
	economy.spend(4, "build:farm")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var e2: EconomySystem = copy.system(&"economy")
	assert_eq((copy.system(&"inventory") as InventorySystem).count("wood"), 3, "wood in store")
	assert_eq(e2.today["build"], -4, "today's ledger")
	copy.advance_to(copy.clock.next_day_start_ms())
	assert_eq(e2.money, sim.data.get_int("balance", "start.money") - 4, "and nothing is sold at dawn after a load either")


func test_the_income_rate_is_the_last_minute() -> void:
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	assert_eq(economy.income_per_minute(), 0, "nothing earned yet")
	_grow_one_batch(farm)
	_grow_one_batch(farm)
	assert_eq(economy.income_per_minute(), 2 * economy.unit_price("crop"), "two harvests in the last minute")
	sim.advance_ms(60000)
	assert_eq(economy.income_per_minute(), 0, "a minute later, gone from the rate (not from the money)")


func test_no_dead_end_from_the_start() -> void:
	# Whatever a player does, they always either own a farm or can afford one.
	var farm_cost := int(sim.data.building_type("farm")["cost"]["money"])
	var rng := RandomNumberGenerator.new()
	for run in 25:
		rng.seed = 1000 + run
		_start()
		for step in 120:
			match rng.randi_range(0, 4):
				0:
					sim.execute({"type": "building.place", "building": "farm", "anchor": [rng.randi_range(-1, 2), rng.randi_range(-1, 2)]})
				1:
					var ids := buildings.ids()
					if not ids.is_empty():
						sim.execute({"type": "building.cancel", "id": ids[rng.randi_range(0, ids.size() - 1)]})
				2:
					var land: LandSystem = sim.system(&"land")
					var c := land.candidates()
					sim.execute({"type": "land.buy", "cell": c[rng.randi_range(0, c.size() - 1)]})
				_:
					for id: int in buildings.ids():
						sim.execute({"type": "building.tap", "id": id})
			sim.advance_ms(rng.randi_range(500, 20000))
			assert_true(buildings.ids().size() > 0 or economy.money >= farm_cost, "run %d step %d: has a farm or can buy one" % [run, step])
	# And steady play grows money: one farm earns its first land within minutes.
	_start()
	var f: int = sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})["id"]
	sim.advance_ms(build_ms(sim, "farm"))
	var land_cost := (sim.system(&"land") as LandSystem).next_cost()
	var start := sim.now_ms()
	while economy.money < land_cost and sim.now_ms() - start < 600000:
		_grow_one_batch(f)
	assert_true(economy.money >= land_cost, "one farm by hand pays for the first land (after %d s)" % ((sim.now_ms() - start) / 1000))
	assert_true(sim.now_ms() - start <= 120000, "within two minutes of tapping")
