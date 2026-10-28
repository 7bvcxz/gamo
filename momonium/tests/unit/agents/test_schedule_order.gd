extends "res://tests/framework/test_case.gd"

## Step 61: a schedule entered in Schedule mode is an order, not a set. The
## stops are the buildings on its tiles in the order they were tapped (a
## stroke: the order it crossed them); the Momo works them strictly in turn,
## one stage each -- 1 -> 2 -> 3 -> 1 -- committed to the stop it is walking
## to, never turned aside by a building coming free; it waits out a cooldown
## at its next stop, passes over a stop that is gone at once and one that
## cannot start (a full store) after balance.momo.schedule.wait_seconds. The
## order and the commitment are saved; offline plays it the same.

var sim: Simulation
var bs: BuildingSystem
var momos: MomoSystem
var jobs: JobSystem
var momo := 0


func before_each() -> void:
	sim = Simulation.new_game()
	sim.time_scale = 0.0
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 4:
			world.add_land(Vector2i(x, y))
	bs = sim.system(&"buildings")
	momos = sim.system(&"momo")
	jobs = sim.system(&"jobs")
	momo = momos.add_momo(Vector2(0.5, 0.5))


## Tiles tapped in Schedule mode, one tap each, in this order.
func _tap(cells: Array) -> void:
	for c: Vector2i in cells:
		var r := sim.execute({"type": "momo.watch", "momo": momo, "cells": [[c.x, c.y]], "op": "add", "schedule": true})
		assert_true(r["ok"], "tile %s" % c)


## The buildings this Momo starts stages at, in order, over `ms`.
func _starts(ms: int, who: int = 0) -> Array:
	var out: Array = []
	var w := who if who != 0 else momo
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p.get("worker", 0)) == w:
			out.append(int(p["id"])))
	sim.advance_ms(ms)
	return out


func _cycle(seq: Array, stops: Array) -> bool:
	for i in seq.size():
		if seq[i] != stops[i % stops.size()]:
			return false
	return true


func test_stops_follow_the_tap_order_not_the_map() -> void:
	var first := bs.place_instant("farm", Vector2i(0, 0))
	var second := bs.place_instant("farm", Vector2i(1, 0))
	var third := bs.place_instant("farm", Vector2i(2, 0))
	_tap([Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 0)])
	assert_eq(momos.route_of(momo), "order", "Schedule mode: the player's order")
	assert_eq(jobs.stops_of(momo), [third, first, second] as Array[int], "3rd tile, 1st, 2nd: as tapped")
	assert_eq(jobs.stop_numbers(momo), {third: 1, first: 2, second: 3}, "numbered as tapped (not by place, distance or id)")
	assert_eq(momos.watched(momo), [Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], "the tiles keep that order")


func test_works_them_strictly_in_turn_one_stage_each() -> void:
	var first := bs.place_instant("farm", Vector2i(0, 0))
	var second := bs.place_instant("farm", Vector2i(1, 0))
	var third := bs.place_instant("farm", Vector2i(2, 0))
	_tap([Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 0)])
	var seq := _starts(240000)
	assert_true(seq.size() >= 9, "three rounds at least (%d stages)" % seq.size())
	assert_true(_cycle(seq, [third, first, second]), "3 -> 1 -> 2 -> 3 ... one stage at each: %s" % [seq])


func test_never_turned_aside_on_the_way() -> void:
	var far := bs.place_instant("farm", Vector2i(3, 3))
	var near := bs.place_instant("farm", Vector2i(1, 0))
	# The near farm is busy: the player is sowing it by hand.
	assert_true(sim.execute({"type": "building.tap", "id": near})["ok"], "the player sows the near farm")
	# Near the end of the sowing (Step 69: 6.25 s, longer than the walk), the
	# schedule: the near farm comes free while the Momo is still on its way.
	sim.advance_to(int(bs.get_building(near)["task_end"]) - 1500)
	_tap([Vector2i(3, 3), Vector2i(1, 0)])
	assert_eq(int(momos.get_momo(momo)["assigned"]), far, "committed to stop 1, the far farm")
	var to: Array = momos.get_momo(momo)["to"]
	var redirects := [0]
	# Locals only in a bus handler: one that reads a member holds this test,
	# and the test holds the simulation (a cycle, leaked at exit).
	var who := momo
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"momo_assigned" and int(p.get("id", 0)) == who and int(p.get("building", 0)) != far:
			redirects[0] += 1)
	# The near farm comes free while the Momo is still walking.
	var end := int(momos.get_momo(momo)["end"])
	sim.advance_to(mini(end - 10, int(bs.get_building(near)["task_end"]) + 10))
	assert_eq(String(bs.get_building(near)["state"]), BuildingSystem.IDLE, "the near farm is free (and nearer)")
	assert_true(momos.is_moving(momo), "the Momo is still on its way")
	assert_eq(int(momos.get_momo(momo)["assigned"]), far, "and still going to stop 1")
	assert_eq(momos.get_momo(momo)["to"], to, "the same destination")
	assert_eq(redirects[0], 0, "never sent elsewhere")
	var seq := _starts(60000)
	assert_eq(seq.slice(0, 3), [far, near, far], "stop 1 first, then 2, then 1: %s" % [seq])


func test_remove_renumbers_and_readd_goes_last() -> void:
	var a := bs.place_instant("farm", Vector2i(0, 0))
	var b := bs.place_instant("farm", Vector2i(1, 0))
	var c := bs.place_instant("farm", Vector2i(2, 0))
	_tap([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	sim.execute({"type": "momo.watch", "momo": momo, "cells": [[1, 0]], "op": "remove", "schedule": true})
	assert_eq(jobs.stop_numbers(momo), {a: 1, c: 2}, "taken away: the rest renumbered")
	_tap([Vector2i(1, 0)])
	assert_eq(jobs.stops_of(momo), [a, c, b] as Array[int], "added again: last")
	_tap([Vector2i(1, 0)])
	assert_eq(jobs.stops_of(momo), [a, c, b] as Array[int], "an add of a tile it has: no duplicate")


func test_empty_tiles_make_no_stops() -> void:
	var farm := bs.place_instant("farm", Vector2i(2, 2))
	_tap([Vector2i(0, 0), Vector2i(2, 2), Vector2i(1, 1)])
	assert_eq(jobs.stops_of(momo), [farm] as Array[int], "grass is watched, but is not a stop")
	var seq := _starts(120000)
	assert_true(seq.size() >= 3 and seq.all(func(id: int) -> bool: return id == farm), "it works the farm, never stalls on grass: %s" % [seq])


func test_a_stop_pulled_down_is_passed_over() -> void:
	var a := bs.place_instant("farm", Vector2i(0, 0))
	var b := bs.place_instant("farm", Vector2i(1, 0))
	var c := bs.place_instant("farm", Vector2i(2, 0))
	_tap([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	var seq := _starts(100)
	for i in 300:
		if not seq.is_empty():
			break
		seq += _starts(100)
	assert_eq(seq, [a], "at work at stop 1")
	bs.demolish(b)
	seq = _starts(120000)
	assert_true(seq.size() >= 4 and _cycle(seq, [c, a]), "stop 2 gone: 3, 1, 3, 1 ... %s" % [seq])


func test_it_waits_for_a_cooldown_at_the_next_stop() -> void:
	var farm := bs.place_instant("farm", Vector2i(0, 0))
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	# The mine was just dug by hand: it settles for its cooldown.
	sim.execute({"type": "building.tap", "id": mine})
	sim.advance_ms(int(float(bs.current_stage(bs.get_building(mine))["seconds"]) * work_scale(sim) * 1000.0) + 10)
	assert_eq(String(bs.get_building(mine)["state"]), BuildingSystem.COOLDOWN, "the mine is cooling down")
	_tap([Vector2i(1, 0), Vector2i(0, 0)])
	var seq := _starts(60000)
	assert_eq(seq[0], mine, "it waited at stop 1 for the cooldown -- not off to the ready farm: %s" % [seq])
	assert_true(_cycle(seq, [mine, farm]), "then in turn: %s" % [seq])


func test_a_stop_that_cannot_start_is_passed_after_a_wait() -> void:
	var lab := bs.place_instant("research", Vector2i(0, 0))
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var inv: InventorySystem = sim.system(&"inventory")
	inv.add("notes", inv.capacity("notes"))
	_tap([Vector2i(0, 0), Vector2i(1, 0)])
	var wait := int(sim.data.get_float("balance", "momo.schedule.wait_seconds", 0.0) * 1000.0)
	assert_true(wait > 0, "a wait in the data")
	var seq := _starts(wait - 1000)
	assert_eq(seq, [], "the lab's store is full: it waits there (%d ms)" % wait)
	assert_eq(int(momos.get_momo(momo)["assigned"]), lab, "at stop 1")
	seq = _starts(30000)
	assert_true(not seq.is_empty() and seq[0] == farm, "then on to stop 2: %s" % [seq])
	assert_false(seq.has(lab), "the lab still cannot start")
	assert_eq(jobs.stops_of(momo), [lab, farm] as Array[int], "and keeps its place in the order")


func test_two_momo_keep_their_own_orders() -> void:
	var a := bs.place_instant("farm", Vector2i(0, 0))
	var b := bs.place_instant("farm", Vector2i(3, 0))
	var c := bs.place_instant("farm", Vector2i(0, 3))
	var d := bs.place_instant("farm", Vector2i(3, 3))
	_tap([Vector2i(3, 0), Vector2i(0, 0)])
	var first := momo
	momo = momos.add_momo(Vector2(0.5, 3.5))
	_tap([Vector2i(3, 3), Vector2i(0, 3)])
	var seq1: Array = []
	var seq2: Array = []
	var second := momo
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started":
			if int(p.get("worker", 0)) == first:
				seq1.append(int(p["id"]))
			elif int(p.get("worker", 0)) == second:
				seq2.append(int(p["id"])))
	sim.advance_ms(200000)
	assert_true(seq1.size() >= 4 and _cycle(seq1, [b, a]), "the first: its order %s" % [seq1])
	assert_true(seq2.size() >= 4 and _cycle(seq2, [d, c]), "the second: its own %s" % [seq2])


func test_save_and_offline_play_the_order_the_same() -> void:
	bs.place_instant("farm", Vector2i(0, 0))
	bs.place_instant("lumberyard", Vector2i(2, 1))
	bs.place_instant("mine", Vector2i(1, 3))
	_tap([Vector2i(1, 3), Vector2i(0, 0), Vector2i(2, 1)])
	sim.advance_ms(23456)
	var state := JSON.stringify(sim.save_state())
	var runs: Array = []
	for mode in 3:
		var s := Simulation.from_save(JSON.parse_string(state))
		var seq: Array = []
		var who := momo
		s.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
			if t == &"task_started" and int(p.get("worker", 0)) == who:
				seq.append(int(p["id"])))
		s.replaying = mode == 2
		s.advance_ms(180000)
		runs.append(seq)
	var loaded := Simulation.from_save(JSON.parse_string(state))
	assert_eq((loaded.system(&"momo") as MomoSystem).route_of(momo), "order", "saved: the order")
	assert_eq((loaded.system(&"momo") as MomoSystem).watched(momo), momos.watched(momo), "the tiles in their order")
	assert_eq(int((loaded.system(&"momo") as MomoSystem).get_momo(momo)["stop"]), int(momos.get_momo(momo)["stop"]), "and the stop it is committed to")
	assert_true((runs[0] as Array).size() >= 6, "work went on (%d)" % (runs[0] as Array).size())
	assert_eq(runs[1], runs[0], "loaded twice: the same stages in the same order")
	assert_eq(runs[2], runs[0], "away (caught up offline): the same")


func test_an_old_save_keeps_its_sorted_tiles_and_route() -> void:
	bs.place_instant("farm", Vector2i(0, 0))
	bs.place_instant("farm", Vector2i(2, 0))
	var state: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	var raw: Dictionary = state["systems"]["momo"]["momos"][0] if state.has("systems") else {}
	if raw.is_empty():
		for k: String in state:
			if typeof(state[k]) == TYPE_DICTIONARY and (state[k] as Dictionary).has("momo"):
				raw = state[k]["momo"]["momos"][0]
	assert_false(raw.is_empty(), "found the Momo in the save")
	raw.erase("stop")
	raw.erase("cursor")
	raw.erase("wait")
	raw["route"] = "rows"
	raw["watch"] = [[2, 0], [0, 0]]
	var loaded := Simulation.from_save(state)
	var lm: MomoSystem = loaded.system(&"momo")
	assert_eq(lm.route_of(momo), "rows", "an old route stays")
	assert_eq(lm.watched(momo), [Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i], "its tiles sorted, as they always were")
	assert_eq(int(lm.get_momo(momo)["stop"]), 0, "no commitment invented")


func test_plain_watch_commands_keep_the_old_routes() -> void:
	sim.execute({"type": "momo.watch", "momo": momo, "cells": [[2, 0], [0, 0]], "op": "add"})
	assert_eq(momos.route_of(momo), "nearest", "not from Schedule mode: the old way")
	assert_eq(momos.watched(momo), [Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i], "sorted")
	sim.execute({"type": "momo.route", "momo": momo, "route": "rows"})
	_tap([Vector2i(1, 1)])
	assert_eq(momos.route_of(momo), "order", "a tile added in Schedule mode: the player's order takes over")
	assert_eq(momos.watched(momo), [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1)] as Array[Vector2i], "what it had first, then the new tile")


func test_an_undone_stroke_puts_the_order_back_exactly() -> void:
	_tap([Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 0)])
	sim.execute({"type": "momo.watch", "momo": momo, "cells": [[0, 0]], "op": "remove", "schedule": true})
	sim.execute({"type": "momo.watch", "momo": momo, "cells": [[2, 0], [0, 0], [1, 0]], "op": "set", "schedule": true})
	assert_eq(momos.watched(momo), [Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], "as it was, in order")


func test_edits_on_the_way_do_not_turn_it_aside() -> void:
	var a := bs.place_instant("farm", Vector2i(3, 3))
	var b := bs.place_instant("farm", Vector2i(1, 0))
	var c := bs.place_instant("farm", Vector2i(0, 1))
	_tap([Vector2i(3, 3), Vector2i(1, 0)])
	sim.advance_ms(500)
	assert_true(momos.is_moving(momo), "walking to stop 1")
	var to: Array = momos.get_momo(momo)["to"]
	_tap([Vector2i(0, 1)])
	assert_eq(int(momos.get_momo(momo)["assigned"]), a, "a stop added at the end: still going to stop 1")
	assert_eq(momos.get_momo(momo)["to"], to, "same destination")
	assert_eq(jobs.stops_of(momo), [a, b, c] as Array[int], "")
	# The stop it is walking to taken away: the one after it, now in its place.
	sim.execute({"type": "momo.watch", "momo": momo, "cells": [[3, 3]], "op": "remove", "schedule": true})
	assert_eq(int(momos.get_momo(momo)["assigned"]), b, "its stop taken away by the player: on to the next one")
	assert_eq(jobs.stop_numbers(momo), {b: 1, c: 2}, "")


func test_a_stop_someone_else_holds_is_passed_after_a_wait() -> void:
	var held := bs.place_instant("farm", Vector2i(1, 0))
	var other := bs.place_instant("farm", Vector2i(2, 0))
	# Another Momo has the farm's one place, for good.
	var keeper := momos.add_momo(Vector2(1.5, 0.5))
	sim.execute({"type": "momo.assign", "momo": keeper, "building": held})
	_tap([Vector2i(1, 0), Vector2i(2, 0)])
	var wait := int(sim.data.get_float("balance", "momo.schedule.wait_seconds", 0.0) * 1000.0)
	var seq := _starts(wait + 30000)
	assert_true(not seq.is_empty() and seq[0] == other, "no place at stop 1: after its wait, stop 2 (%s)" % [seq])
