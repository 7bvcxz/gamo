extends "res://tests/framework/test_case.gd"

## Step 85 (design/ROUTES85.md): the Schedule's stops worked adaptively (the
## `order` route). The Momo goes where its next real stage can start soonest
## -- never to a building the player did not schedule -- instead of walking
## to an unready stop and waiting while another stop has work; it stays when
## its own stop is ready sooner than any walk; once it sets off it is not
## turned aside, by a stop turning ready, a new morning or an edit that keeps
## its stop; a stop that turns impossible on the way, or is taken off its
## tiles, is a new decision; a far stop is not starved by an always-ready
## near one; two Momo share stops without doubling; ties go to the tap order,
## the same every time; saves and Step 61 schedules carry on.

var sim: Simulation
var bs: BuildingSystem
var momos: MomoSystem
var jobs: JobSystem
var momo := 0


func before_each() -> void:
	_new()


func _new(data: GameData = null) -> void:
	sim = Simulation.new_game(data)
	sim.time_scale = 0.0
	var world: WorldSystem = sim.system(&"world")
	for x in 8:
		for y in 8:
			world.add_land(Vector2i(x, y))
	bs = sim.system(&"buildings")
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	momos = sim.system(&"momo")
	jobs = sim.system(&"jobs")
	momo = momos.add_momo(Vector2(0.5, 0.5))


## Tiles added in Schedule mode in this order, in one stroke (one at a time,
## the Momo would set off for the first before the second is there -- and,
## committed, keep going).
func _tap(cells: Array, who: int = 0) -> void:
	var list: Array = cells.map(func(c: Vector2i) -> Array: return [c.x, c.y])
	assert_true(sim.execute({"type": "momo.watch", "momo": who if who != 0 else momo, "cells": list, "op": "add", "schedule": true})["ok"], "tiles %s" % [cells])


## Starts by `who` over `ms`, [building, ms] -- recorded through the clock
## (a handler holding this test would keep the simulation alive).
func _starts(ms: int, who: int = 0) -> Array:
	var out: Array = []
	var w := who if who != 0 else momo
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p.get("worker", 0)) == w:
			out.append([int(p["id"]), clock.now_ms]))
	sim.advance_ms(ms)
	return out


## The mine dug by hand: it settles for its cooldown (10 s at Step 84).
func _settling_mine(cell: Vector2i) -> int:
	var mine := bs.place_instant("mine", cell)
	sim.execute({"type": "building.tap", "id": mine})
	sim.advance_ms(bs.remaining_ms(bs.get_building(mine)) + 10)
	assert_eq(String(bs.get_building(mine)["state"]), BuildingSystem.COOLDOWN, "the mine settles")
	return mine


func test_the_schedule_is_adaptive_and_the_numbers_are_a_priority() -> void:
	var a := bs.place_instant("farm", Vector2i(2, 0))
	var b := bs.place_instant("farm", Vector2i(0, 0))
	_tap([Vector2i(2, 0), Vector2i(0, 0)])
	assert_eq(momos.route_of(momo), "order", "Schedule mode: the Schedule's own route")
	assert_eq(jobs.stop_numbers(momo), {a: 1, b: 2}, "numbered as tapped (a priority)")


func test_useful_work_instead_of_waiting_at_an_unready_stop() -> void:
	# Stop 1 is a mine settling for 10 s; stop 2 is a farm ready now, nearer.
	var mine := _settling_mine(Vector2i(5, 5))
	var farm := bs.place_instant("farm", Vector2i(1, 1))
	_tap([Vector2i(5, 5), Vector2i(1, 1)])
	assert_eq(int(momos.get_momo(momo)["assigned"]), farm, "it goes to the farm that has work, not to wait at the mine")
	var seq := _starts(200000)
	assert_eq(int(seq[0][0]), farm, "the farm's stage first: %s" % [seq])
	assert_true(seq.map(func(e: Array) -> int: return e[0]).has(mine), "and the mine when it is ready: %s" % [seq])


func test_it_stays_when_its_own_stop_is_ready_sooner_than_any_walk() -> void:
	var near := bs.place_instant("farm", Vector2i(0, 0))
	var far := bs.place_instant("farm", Vector2i(7, 7))
	_tap([Vector2i(0, 0), Vector2i(7, 7)])
	# Sow and water the near farm: it ripens 3.3 s; the far farm is ready but
	# a long walk away. The far one gets its turn by age (starve_seconds).
	var seq := _starts(150000)
	var ids: Array = seq.map(func(e: Array) -> int: return e[0])
	assert_eq(ids.slice(0, 3), [near, near, near], "sow, water, then the harvest after the 3.3 s ripening -- not a walk across the island first: %s" % [ids])
	assert_true(ids.has(far), "the far farm in its turn: %s" % [ids])


func test_never_turned_aside_on_the_way() -> void:
	# The near smelter has no ore (when it could start cannot be told), the
	# far farm is ready: the Momo sets off for the farm.
	var far := bs.place_instant("farm", Vector2i(7, 7))
	var near := bs.place_instant("smelter", Vector2i(1, 0))
	_tap([Vector2i(1, 0), Vector2i(7, 7)])
	assert_eq(jobs.ready_ms(momo, near), -1, "the smelter's start cannot be told")
	assert_eq(int(momos.get_momo(momo)["assigned"]), far, "off to the far farm")
	var to: Array = momos.get_momo(momo)["to"]
	var turned := [0]
	var who := momo
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"momo_assigned" and int(p.get("id", 0)) == who and int(p.get("building", 0)) != far:
			turned[0] += 1)
	sim.advance_ms(1500)
	assert_true(momos.is_moving(momo), "on its way")
	# On the way: the ore arrives (the smelter could start now, and it is
	# nearer), a morning comes, a tile is added.
	var inv: InventorySystem = sim.system(&"inventory")
	for item: String in bs.current_stage(bs.get_building(near)).get("consumes", {}):
		inv.add(item, 20, "test")
	jobs.on_day_started(sim.clock.day_number())
	_tap([Vector2i(3, 3)])
	assert_true(momos.is_moving(momo), "still walking")
	assert_eq(momos.get_momo(momo)["to"], to, "the same destination")
	assert_eq(int(momos.get_momo(momo)["assigned"]), far, "still the far farm")
	assert_eq(turned[0], 0, "never sent elsewhere on the way")
	var seq := _starts(30000)
	assert_eq(int(seq[0][0]), far, "and works it when it gets there: %s" % [seq])


func test_taking_its_stop_off_or_pulling_it_down_is_a_new_decision() -> void:
	var a := bs.place_instant("farm", Vector2i(7, 7))
	var b := bs.place_instant("farm", Vector2i(1, 1))
	var c := bs.place_instant("farm", Vector2i(7, 0))
	_tap([Vector2i(7, 7), Vector2i(1, 1), Vector2i(7, 0)])
	var first := int(momos.get_momo(momo)["assigned"])
	assert_true(momos.is_moving(momo), "on its way to %d" % first)
	sim.execute({"type": "momo.watch", "momo": momo, "cells": [[bs.get_building(first)["anchor"][0], bs.get_building(first)["anchor"][1]]], "op": "remove", "schedule": true})
	var second := int(momos.get_momo(momo)["assigned"])
	assert_ne(second, first, "its stop taken off: it goes elsewhere")
	assert_true([a, b, c].has(second), "to one of its stops")
	bs.demolish(second)
	var third := int(momos.get_momo(momo)["assigned"])
	assert_true(third != second and [a, b, c].has(third), "its stop pulled down: another of its stops (%d)" % third)


func test_a_stop_that_cannot_start_is_left_out_and_only_scheduled_buildings_are_visited() -> void:
	var lab := bs.place_instant("research", Vector2i(1, 1))
	var farm := bs.place_instant("farm", Vector2i(5, 5))
	var other := bs.place_instant("farm", Vector2i(2, 2))
	var inv: InventorySystem = sim.system(&"inventory")
	inv.add("notes", inv.capacity("notes"))
	_tap([Vector2i(1, 1), Vector2i(5, 5)])
	assert_eq(jobs.ready_ms(momo, lab), -1, "the lab's store is full: its start cannot be told")
	assert_eq(int(momos.get_momo(momo)["assigned"]), farm, "so it goes to the farm, not to wait at the lab")
	var seq := _starts(120000)
	var ids: Array = seq.map(func(e: Array) -> int: return e[0])
	assert_false(ids.has(lab), "the lab still cannot start")
	assert_false(ids.has(other), "the farm next door was never scheduled: never visited")
	# Room in the store: the lab is a stop again.
	inv.take_all({"notes": inv.count("notes")}, "test")
	ids = _starts(200000).map(func(e: Array) -> int: return e[0])
	assert_true(ids.has(lab), "with room, the lab is worked again: %s" % [ids])


func test_a_far_stop_is_not_starved_by_an_always_ready_near_one() -> void:
	var near_a := bs.place_instant("farm", Vector2i(0, 0))
	var near_b := bs.place_instant("farm", Vector2i(1, 0))
	var lab := bs.place_instant("research", Vector2i(7, 7))
	_tap([Vector2i(0, 0), Vector2i(1, 0), Vector2i(7, 7)])
	var seq := _starts(20 * 60000)
	var lab_times: Array = seq.filter(func(e: Array) -> bool: return e[0] == lab).map(func(e: Array) -> int: return e[1])
	assert_true(lab_times.size() >= 3, "the far lab is studied again and again (%d times)" % lab_times.size())
	var starve := int(sim.data.get_float("balance", "momo.schedule.starve_seconds", 0.0) * 1000.0)
	var longest := 0
	for i in range(1, lab_times.size()):
		longest = maxi(longest, int(lab_times[i]) - int(lab_times[i - 1]))
	var lab_cycle := ms(bs.stage_seconds(bs.get_building(lab), bs.stages(bs.get_building(lab))[0]) + bs.stage_cooldown(bs.get_building(lab), bs.stages(bs.get_building(lab))[0]))
	assert_true(longest <= starve + lab_cycle + 60000, "never left longer than its age limit, a cycle and a farm stage (%.0f s)" % (longest / 1000.0))
	assert_true(seq.size() > lab_times.size() * 2, "and the farms are worked meanwhile")


func test_two_momo_share_stops_without_doubling() -> void:
	var stops: Array[Vector2i] = [Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7)]
	for c: Vector2i in stops:
		bs.place_instant("farm", c)
	var second := momos.add_momo(Vector2(7.5, 7.5))
	_tap(stops)
	var reversed := stops.duplicate()
	reversed.reverse()
	_tap(reversed, second)
	var both := [0, 0]
	var clash := [0]
	var first := momo
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started":
			if int(p["worker"]) == first:
				both[0] += 1
			elif int(p["worker"]) == second:
				both[1] += 1)
	for i in 600:
		sim.advance_ms(1000)
		var a := int(momos.get_momo(first)["assigned"])
		var b := int(momos.get_momo(second)["assigned"])
		if a != 0 and a == b and momos.at_work(first) and momos.at_work(second):
			clash[0] += 1
	assert_true(both[0] >= 10 and both[1] >= 10, "both work (%d and %d stages)" % [both[0], both[1]])
	assert_eq(clash[0], 0, "never both at one building with one place")


func test_the_same_island_gives_the_same_route_and_ties_go_to_the_tap_order() -> void:
	var runs: Array = []
	for k in 2:
		_new()
		bs.place_instant("farm", Vector2i(2, 0))
		bs.place_instant("farm", Vector2i(0, 2))
		_tap([Vector2i(0, 2), Vector2i(2, 0)])
		runs.append(_starts(300000).map(func(e: Array) -> Array: return [int(e[0]), int(e[1])]))
	assert_eq(runs[0], runs[1], "the same inputs, the same route, to the millisecond")
	# Two farms the same distance away, both ready: the first tapped goes first.
	_new()
	var left := bs.place_instant("farm", Vector2i(0, 2))
	var right := bs.place_instant("farm", Vector2i(2, 0))
	momos.get_momo(momo)["from"] = [0.5, 0.5]
	momos.get_momo(momo)["to"] = [0.5, 0.5]
	_tap([Vector2i(2, 0), Vector2i(0, 2)])
	assert_eq(int(momos.get_momo(momo)["assigned"]), right, "equally near: stop 1 (tapped first)")
	assert_ne(left, right, "")


func test_a_save_carries_the_destination_and_a_step61_schedule_works_adaptively() -> void:
	bs.place_instant("farm", Vector2i(7, 7))
	bs.place_instant("farm", Vector2i(1, 0))
	_tap([Vector2i(7, 7), Vector2i(1, 0)])
	sim.advance_ms(1500)
	var dest := int(momos.get_momo(momo)["assigned"])
	var state: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	var loaded := Simulation.from_save(state)
	var lm: MomoSystem = loaded.system(&"momo")
	assert_eq(int(lm.get_momo(momo)["assigned"]), dest, "loaded: on its way to the same stop")
	assert_eq(lm.route_of(momo), "order", "the Schedule's route")
	var a: Array = _starts(120000)
	var b: Array = []
	var clock := loaded.clock
	loaded.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p.get("worker", 0)) == 1:
			b.append([int(p["id"]), clock.now_ms]))
	loaded.advance_ms(120000)
	assert_eq(b, a, "the saved island goes on exactly as the one never saved")
	# A Step 61 save: an `order` route with no turn memory -- worked adaptively.
	var old: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	for m: Dictionary in old["systems"]["momo"]["momos"]:
		m.erase("done")
		m.erase("idle")
	var older := Simulation.from_save(old)
	var works := [0]
	older.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p.get("worker", 0)) == 1:
			works[0] += 1)
	older.advance_ms(120000)
	assert_true(works[0] >= 3, "an older schedule carries on, adaptively (%d stages)" % works[0])


func test_the_step84_production_times_these_cases_stand_on() -> void:
	var farm := bs.get_building(bs.place_instant("farm", Vector2i(6, 6)))
	var stages := bs.stages(farm)
	assert_eq(ms(bs.stage_seconds(farm, stages[0])), 10417, "a farm stage: 10.4 s of work (Step 84)")
	var water: Dictionary = stages.filter(func(s: Dictionary) -> bool: return String(s.get("action", "")) == "water")[0]
	assert_eq(ms(bs.stage_cooldown(farm, water)), 3333, "the ripening after watering: 3.3 s (Step 84)")
	var mine := bs.get_building(bs.place_instant("mine", Vector2i(3, 6)))
	assert_eq(ms(bs.stage_cooldown(mine, bs.stages(mine)[0])), 10000, "the mine settles 10 s after a dig (Step 84)")


func test_the_player_s_hands_at_a_stop() -> void:
	var mine_by_hand := bs.place_instant("farm", Vector2i(0, 1))
	var other := bs.place_instant("farm", Vector2i(2, 1))
	var bsys: BuildingSystem = bs
	assert_true(sim.execute({"type": "building.tap", "id": mine_by_hand})["ok"], "the player sows a farm by hand")
	_tap([Vector2i(0, 1), Vector2i(2, 1)])
	assert_eq(int(momos.get_momo(momo)["assigned"]), other, "stop 1 is in the player's hands: the Momo works stop 2")
	var hands := [0]
	sim.bus.emitted.connect(func(t: StringName, _p: Dictionary) -> void:
		if t == &"task_started":
			hands[0] = maxi(hands[0], bsys.manual_slots_used()))
	var end := int(bs.get_building(mine_by_hand)["task_end"])
	sim.advance_to(end - 10)
	assert_eq(int(bs.get_building(mine_by_hand)["worker"]), BuildingSystem.PLAYER, "the player's stage is never taken over")
	var ids: Array = _starts(120000).map(func(e: Array) -> int: return e[0])
	assert_true(ids.has(mine_by_hand), "the farm's next stages are the Momo's: %s" % [ids])
	assert_eq(hands[0], 1, "the Momo's stages never take one of the player's three hands")


func test_two_momo_on_the_strict_order_holding_each_other_s_next_stop_move_on() -> void:
	# Step 61's strict order, kept as a route: a Momo whose next stop is
	# someone else's does not work its last stop again and again meanwhile.
	var a := bs.place_instant("farm", Vector2i(0, 0))
	var b := bs.place_instant("mine", Vector2i(3, 0))
	var c := bs.place_instant("farm", Vector2i(0, 6))
	var d := bs.place_instant("farm", Vector2i(6, 6))
	var second := momos.add_momo(Vector2(6.5, 6.5))
	_tap([Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 6)])
	_tap([Vector2i(6, 6), Vector2i(0, 6), Vector2i(3, 0)], second)
	for who: int in [momo, second]:
		assert_true(sim.execute({"type": "momo.route", "momo": who, "route": "strict"})["ok"], "strict")
	var runs := {}
	var first := momo
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p.get("worker", 0)) in [first, second]:
			var w := int(p["worker"])
			var seq: Array = runs.get(w, [])
			seq.append(int(p["id"]))
			runs[w] = seq)
	sim.advance_ms(10 * 60000)
	for w: int in [first, second]:
		var seq: Array = runs.get(w, [])
		var longest := 1
		var run := 1
		for i in range(1, seq.size()):
			run = run + 1 if seq[i] == seq[i - 1] else 1
			longest = maxi(longest, run)
		assert_true(seq.size() >= 6, "Momo %d works (%d stages)" % [w, seq.size()])
		assert_true(longest <= 1, "Momo %d: one stage at each stop in turn, never one stop twice running: %s" % [w, seq])
	assert_ne(a, d, "")
	assert_ne(b, c, "")


func test_a_sold_island_s_momo_take_up_a_schedule_from_fresh() -> void:
	bs.place_instant("farm", Vector2i(1, 1))
	_tap([Vector2i(1, 1)])
	sim.advance_ms(60000)
	var prog: ProgressionSystem = sim.system(&"progression")
	var level := int(sim.data.get_value("balance", "prestige.min_level", 5))
	while prog.level < level:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	var r := PrestigeSystem.sell(sim)
	assert_true(r["ok"], "sold")
	var next: Simulation = r["sim"]
	next.time_scale = 0.0
	sim = next
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 4:
			world.add_land(Vector2i(x, y))
	bs = sim.system(&"buildings")
	momos = sim.system(&"momo")
	jobs = sim.system(&"jobs")
	assert_eq(momos.ids().size(), 0, "the new island starts with no Momo (Step 53)")
	momo = momos.add_momo(Vector2(0.5, 0.5))
	assert_eq(momos.get_momo(momo)["done"], {}, "nothing carried over")
	var farm := bs.place_instant("farm", Vector2i(2, 2))
	_tap([Vector2i(2, 2)])
	assert_eq(momos.route_of(momo), "order", "the Schedule's own route")
	var ids: Array = _starts(60000).map(func(e: Array) -> int: return e[0])
	assert_true(ids.size() >= 3 and ids.all(func(id: int) -> bool: return id == farm), "it works its stop on the new island: %s" % [ids])
