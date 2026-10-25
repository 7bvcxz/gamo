extends "res://tests/framework/test_case.gd"

## Watched tiles: what a Momo looks after, how many it may, which tiles are
## allowed, and the rounds that follow -- free Momo go to the nearest watched
## building that is ready, and an edit takes effect at once.

var sim: Simulation
var bs: BuildingSystem
var momos: MomoSystem
var jobs: JobSystem


func before_each() -> void:
	sim = Simulation.new_game()
	bs = sim.system(&"buildings")
	momos = sim.system(&"momo")
	jobs = sim.system(&"jobs")
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 4:
			world.add_land(Vector2i(x, y))


func _watch(momo: int, cells: Array, op: String) -> Dictionary:
	return sim.execute({"type": "momo.watch", "momo": momo, "cells": cells, "op": op})


func test_assigning_watches_that_building() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	assert_eq(momos.watched(1), [Vector2i(1, 0)] as Array[Vector2i], "the farm's tile, nothing else to set up")
	sim.advance_ms(60000)
	assert_eq(int(momos.get_momo(1)["assigned"]), farm, "and it stays at its farm as before")
	assert_true(int(bs.get_building(farm)["completed"]) > 0, "working it")


func test_capacity_from_research() -> void:
	assert_eq(momos.watch_capacity(1), 4, "4 tiles to begin with")
	var r := _watch(1, [[0, 0], [1, 0], [0, 1], [1, 1], [2, 2]], "add")
	assert_eq(int(r["count"]), 4, "four go in")
	assert_eq(r["refused"], {"2,2": "err.watch_full"}, "the fifth is refused, and says why")
	(sim.system(&"research") as ResearchSystem).completed["momo_reach"] = 0
	assert_eq(momos.watch_capacity(1), 9, "rounds research: 9")
	(sim.system(&"research") as ResearchSystem).completed["momo_wide_reach"] = 0
	assert_eq(momos.watch_capacity(1), 16, "and 16")
	assert_true(_watch(1, [[2, 2]], "add")["changed"].size() == 1, "now it fits")


func test_only_land_with_work() -> void:
	var r := _watch(1, [[9, 9]], "add")
	assert_eq(r["refused"], {"9,9": "err.not_owned"}, "the sea is nobody's job")
	var solar := bs.place_instant("solar_panel", Vector2i(0, 0))
	assert_true(solar > 0, "a solar roof")
	r = _watch(1, [[0, 0]], "add")
	assert_eq(r["refused"], {"0,0": "err.no_work_here"}, "has no Momo work")
	r = _watch(1, [[1, 1]], "add")
	assert_eq(r["changed"], [[1, 1]], "empty land may be watched (whatever is built there gets worked)")


func test_add_and_remove_are_not_toggles() -> void:
	_watch(1, [[1, 0]], "add")
	var r := _watch(1, [[1, 0], [0, 1]], "add")
	assert_eq(r["changed"], [[0, 1]], "adding a watched tile again changes nothing")
	r = _watch(1, [[1, 0], [1, 0], [3, 3]], "remove")
	assert_eq(r["changed"], [[1, 0]], "removing twice, or what was never watched, changes nothing more")
	assert_eq(momos.watched(1), [Vector2i(0, 1)] as Array[Vector2i], "left: one tile")
	assert_true(bool(momos.get_momo(1)["pinned"]), "an edited Momo is the player's: the manager leaves it")


func test_rounds_between_two_lumberyards() -> void:
	var a := bs.place_instant("lumberyard", Vector2i(0, 0))
	var b := bs.place_instant("lumberyard", Vector2i(1, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": a})
	_watch(1, [[1, 1]], "add")
	sim.advance_ms(240000)
	assert_true(int(bs.get_building(a)["completed"]) >= 2, "it works the first (%d stages)" % int(bs.get_building(a)["completed"]))
	assert_true(int(bs.get_building(b)["completed"]) >= 2, "and, while the first waits, the second (%d)" % int(bs.get_building(b)["completed"]))
	var where := (momos.get_momo(1)["history"] as Array).map(func(h: Dictionary) -> int: return int(h["building"]))
	assert_true(where.has(a) and where.has(b), "its history shows both")


func test_one_place_one_momo() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var two := momos.add_momo(Vector2(0.5, 0.5))
	_watch(1, [[1, 0]], "add")
	_watch(two, [[1, 0]], "add")
	sim.advance_ms(1000)
	assert_eq(momos.workers_at(farm).size(), 1, "a farm takes one worker: the other waits")
	var stages := []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p["id"]) == farm:
			stages.append(int(p["worker"])))
	sim.advance_ms(200000)
	assert_true(stages.size() > 0, "and the farm is worked")


func test_an_edit_takes_effect_at_once() -> void:
	var a := bs.place_instant("lumberyard", Vector2i(0, 0))
	var b := bs.place_instant("lumberyard", Vector2i(1, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": a})
	sim.advance_ms(3000)
	_watch(1, [[0, 0]], "remove")
	assert_ne(int(momos.get_momo(1)["assigned"]), a, "its building off its rounds: it goes")
	_watch(1, [[1, 1]], "add")
	assert_eq(int(momos.get_momo(1)["assigned"]), b, "a ready building added: it heads there straight away")
	sim.advance_ms(60000)
	assert_true(int(bs.get_building(b)["completed"]) > 0, "and works it")


func test_saved_and_old_saves() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	_watch(1, [[1, 0], [0, 1]], "add")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_eq((copy.system(&"momo") as MomoSystem).watched(1), [Vector2i(0, 1), Vector2i(1, 0)] as Array[Vector2i], "kept")
	var state := sim.save_state()
	var raw: Dictionary = JSON.parse_string(JSON.stringify(state))
	for m: Dictionary in raw["systems"]["momo"]["momos"]:
		m.erase("watch")
		m["assigned"] = farm
	var old := Simulation.from_save(raw)
	assert_eq((old.system(&"momo") as MomoSystem).watched(1), [Vector2i(1, 0)] as Array[Vector2i], "an older save: it watches its building")
