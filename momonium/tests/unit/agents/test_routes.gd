extends "res://tests/framework/test_case.gd"

## Momo routes: the order a Momo visits its watched buildings in -- nearest,
## row by row, zigzag, its own zone, and (researched) the smart route that
## sets off for what will be ready -- deterministic, saved, and only a better
## use of walking and waiting (nothing extra is made).

var sim: Simulation
var bs: BuildingSystem
var momos: MomoSystem
var jobs: JobSystem
var rs: ResearchSystem


func before_each() -> void:
	sim = Simulation.new_game()
	bs = sim.system(&"buildings")
	momos = sim.system(&"momo")
	jobs = sim.system(&"jobs")
	rs = sim.system(&"research")
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 4:
			world.add_land(Vector2i(x, y))


func _watch(momo: int, cells: Array) -> void:
	sim.execute({"type": "momo.watch", "momo": momo, "cells": cells, "op": "add"})


func _yards(cells: Array[Vector2i]) -> Array[int]:
	var out: Array[int] = []
	for c: Vector2i in cells:
		out.append(bs.place_instant("lumberyard", c))
	return out


func test_row_and_zigzag_orders() -> void:
	(sim.system(&"research") as ResearchSystem).completed["momo_reach"] = 0
	var ids := _yards([Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)])
	_watch(1, [[0, 0], [2, 0], [0, 1], [2, 1]])
	sim.execute({"type": "momo.route", "momo": 1, "route": "rows"})
	momos.get_momo(1)["assigned"] = 0
	assert_eq(jobs.route_order(1), [ids[0], ids[1], ids[2], ids[3]], "row by row: left to right, top row first")
	sim.execute({"type": "momo.route", "momo": 1, "route": "zigzag"})
	momos.get_momo(1)["assigned"] = 0
	assert_eq(jobs.route_order(1), [ids[0], ids[1], ids[3], ids[2]], "zigzag: the second row right to left")
	momos.get_momo(1)["assigned"] = ids[1]
	assert_eq(jobs.route_order(1), [ids[3], ids[2], ids[0], ids[1]], "it goes on from where it is: that one last")


func test_zones_split_shared_tiles() -> void:
	var ids := _yards([Vector2i(0, 0), Vector2i(3, 3)])
	var two := momos.add_momo(Vector2(3.5, 3.5))
	_watch(1, [[0, 0], [0, 1], [3, 3]])
	_watch(two, [[3, 3], [3, 2], [0, 0]])
	assert_eq(jobs.zone_owner(ids[0]), 1, "the corner nearer Momo 1's tiles is its")
	assert_eq(jobs.zone_owner(ids[1]), two, "the other is Momo 2's")
	sim.execute({"type": "momo.route", "momo": 1, "route": "zone"})
	assert_eq(jobs.route_order(1), [ids[0]], "in its zone, it only goes to its own")


func test_the_smart_route_needs_research_and_falls_back() -> void:
	assert_eq(sim.execute({"type": "momo.route", "momo": 1, "route": "auto"})["reason"], "err.needs_research", "not yet researched")
	rs.completed["smart_schedule"] = 0
	assert_true(sim.execute({"type": "momo.route", "momo": 1, "route": "auto"})["ok"], "researched: chosen")
	assert_eq(momos.route_of(1), "auto", "")
	rs.completed.erase("smart_schedule")
	assert_eq(momos.route_of(1), "nearest", "points placed elsewhere: back to nearest, the choice kept")
	assert_eq(String(momos.get_momo(1)["route"]), "auto", "")


func test_the_smart_route_sets_off_early() -> void:
	rs.completed["smart_schedule"] = 0
	var near := bs.place_instant("lumberyard", Vector2i(0, 0))
	var far := bs.place_instant("lumberyard", Vector2i(3, 3))
	_watch(1, [[0, 0], [3, 3]])
	sim.execute({"type": "momo.route", "momo": 1, "route": "auto"})
	# The far one is about to be ready; the near one waits much longer.
	bs.get_building(near)["state"] = BuildingSystem.COOLDOWN
	bs.get_building(near)["ready_at"] = sim.now_ms() + 60000
	bs.get_building(far)["state"] = BuildingSystem.COOLDOWN
	bs.get_building(far)["ready_at"] = sim.now_ms() + 3000
	momos.get_momo(1)["assigned"] = 0
	assert_eq(jobs.dispatch(1), far, "it walks to what will be ready first, while it cools")
	sim.execute({"type": "momo.route", "momo": 1, "route": "nearest"})
	momos.get_momo(1)["assigned"] = 0
	assert_eq(jobs.dispatch(1), 0, "nearest only goes to what is ready now: it waits")


func test_routes_change_nothing_but_order() -> void:
	var made := {}
	for route: String in ["nearest", "rows", "zigzag", "zone"]:
		var s := Simulation.new_game()
		var w: WorldSystem = s.system(&"world")
		for x in 4:
			for y in 4:
				w.add_land(Vector2i(x, y))
		var b: BuildingSystem = s.system(&"buildings")
		for c: Vector2i in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]:
			b.place_instant("lumberyard", c)
		s.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0], [3, 0], [0, 3], [3, 3]], "op": "add"})
		s.execute({"type": "momo.route", "momo": 1, "route": route})
		s.advance_ms(s.clock.day_ms * 4)
		made[route] = (s.system(&"inventory") as InventorySystem).count("wood")
		assert_true(made[route] > 0, "%s: the yards are worked (%d wood)" % [route, made[route]])
	assert_eq(made, _again(), "the same days give the same wood: deterministic")


func _again() -> Dictionary:
	var made := {}
	for route: String in ["nearest", "rows", "zigzag", "zone"]:
		var s := Simulation.new_game()
		var w: WorldSystem = s.system(&"world")
		for x in 4:
			for y in 4:
				w.add_land(Vector2i(x, y))
		var b: BuildingSystem = s.system(&"buildings")
		for c: Vector2i in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]:
			b.place_instant("lumberyard", c)
		s.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0], [3, 0], [0, 3], [3, 3]], "op": "add"})
		s.execute({"type": "momo.route", "momo": 1, "route": route})
		s.advance_ms(s.clock.day_ms * 4)
		made[route] = (s.system(&"inventory") as InventorySystem).count("wood")
	return made


func test_saved_and_old_saves() -> void:
	sim.execute({"type": "momo.route", "momo": 1, "route": "zigzag"})
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_eq((copy.system(&"momo") as MomoSystem).route_of(1), "zigzag", "kept")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	for m: Dictionary in raw["systems"]["momo"]["momos"]:
		m.erase("route")
	assert_eq((Simulation.from_save(raw).system(&"momo") as MomoSystem).route_of(1), "nearest", "older saves: nearest")
	raw["systems"]["momo"]["momos"][0]["route"] = "teleport"
	assert_eq((Simulation.from_save(raw).system(&"momo") as MomoSystem).route_of(1), "nearest", "nonsense: nearest")


func test_before_and_after_a_change() -> void:
	var yard := bs.place_instant("lumberyard", Vector2i(0, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": yard})
	sim.advance_ms(sim.clock.day_ms * 3)
	sim.execute({"type": "momo.route", "momo": 1, "route": "rows"})
	sim.advance_ms(sim.clock.day_ms * 3)
	var ba := (sim.system(&"analytics") as AnalyticsSystem).momo_before_after(1, int(momos.get_momo(1)["route_since"]))
	assert_true(int(ba["days_before"]) >= 1 and int(ba["days_after"]) >= 1, "days on both sides (%s)" % [ba])
	assert_true(float(ba["before"]) > 0.0 and float(ba["after"]) > 0.0, "jobs a day, before and after")
