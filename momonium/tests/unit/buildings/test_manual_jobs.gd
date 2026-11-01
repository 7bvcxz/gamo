extends "res://tests/framework/test_case.gd"

## Step 83 (design/HANDS83.md): the player's own hands work at most
## `balance.manual.limit` (3) buildings at once, by the simulation's rule --
## a building in WORKING on a stage the player started (worker 0). A fourth
## start is refused with a reason and changes nothing; a hand comes free when
## a job ends, is stopped or its building comes down; cooldowns, growing and
## construction hold none; Momo and automatic work are never limited and
## never take a hand. A save holding more than the limit lets them finish.

var sim: Simulation
var bs: BuildingSystem
var inv: InventorySystem
var events: Array[Dictionary] = []


func before_each() -> void:
	before_each_with(unit_pace())


func before_each_with(data: GameData) -> void:
	if sim != null and sim.bus.emitted.is_connected(_on_event):
		sim.bus.emitted.disconnect(_on_event)
	sim = Simulation.new_game(data)
	bs = sim.system(&"buildings")
	inv = sim.system(&"inventory")
	var world: WorldSystem = sim.system(&"world")
	for x in 5:
		for y in 4:
			world.add_land(Vector2i(x, y))
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	events.clear()
	sim.bus.emitted.connect(_on_event)


func _on_event(type: StringName, p: Dictionary) -> void:
	events.append({"type": type, "p": p})


## The bus holds this test's method: let go of it, or the test, the island
## and the bus keep each other alive past the end (leaked at exit).
func after_each() -> void:
	if sim != null and sim.bus.emitted.is_connected(_on_event):
		sim.bus.emitted.disconnect(_on_event)
	sim = null


## A building of `type` at `cell`, ready at its stage `action` (its first
## stage when ""), with what that stage takes in the store.
func _ready_at(type: String, cell: Vector2i, action: String = "") -> int:
	var id := bs.place_instant(type, cell)
	assert_true(id > 0, "%s placed" % type)
	var b := bs.get_building(id)
	if action != "":
		var list := bs.stages(b)
		for k in list.size():
			if String((list[k] as Dictionary).get("action", "")) == action:
				b["stage"] = k
				break
	var consumes: Dictionary = bs.current_stage(b).get("consumes", {})
	for item: String in consumes:
		inv.add(item, int(consumes[item]) * 3, "test")
	return id


func _tap(id: int) -> Dictionary:
	return sim.execute({"type": "building.tap", "id": id})


func test_a_fourth_job_waits_for_a_free_hand_and_costs_nothing() -> void:
	assert_eq(bs.manual_limit(), 3, "three hands (balance manual.limit)")
	var farm := _ready_at("farm", Vector2i(0, 0), "sow")
	var mine := _ready_at("mine", Vector2i(1, 0))
	var wood := _ready_at("lumberyard", Vector2i(2, 0))
	var lab := _ready_at("research", Vector2i(3, 0))
	for id: int in [farm, mine, wood]:
		assert_true(_tap(id)["ok"], "%s starts by hand" % bs.get_building(id)["type"])
	assert_eq(bs.manual_slots_used(), 3, "three at work")
	assert_eq(bs.manual_jobs(), [farm, mine, wood] as Array[int], "these three")
	var money := (sim.system(&"economy") as EconomySystem).money
	var store := inv.items.duplicate(true)
	var before := bs.get_building(lab).duplicate(true)
	var queued := sim.scheduler.size()
	events.clear()
	var r := _tap(lab)
	assert_false(r["ok"], "the fourth is refused")
	assert_eq(r["reason"], "err.manual_limit", "for want of a hand")
	assert_eq(int(r["used"]), 3, "three in use")
	assert_eq(int(r["limit"]), 3, "of three")
	assert_eq(bs.get_building(lab), before, "the lab untouched")
	assert_eq(inv.items, store, "nothing taken from the store")
	assert_eq((sim.system(&"economy") as EconomySystem).money, money, "no money")
	assert_eq(sim.scheduler.size(), queued, "nothing scheduled")
	assert_eq(events.filter(func(e: Dictionary) -> bool: return e["type"] == &"task_started" or e["type"] == &"consumed").size(), 0, "no start, nothing consumed")
	# The farm's sowing ends: a hand is free at once.
	var b := bs.get_building(farm)
	sim.advance_ms(int(b["task_end"]) - sim.now_ms())
	assert_ne(bs.get_building(farm)["state"], BuildingSystem.WORKING, "the sowing is done")
	assert_eq(bs.manual_slots_used(), 2, "a hand free")
	assert_true(_tap(lab)["ok"], "and the lab starts")
	assert_eq(bs.manual_slots_used(), 3, "three again")


func test_repeat_taps_and_cooldowns_hold_no_extra_hand() -> void:
	var farm := _ready_at("farm", Vector2i(0, 0), "sow")
	assert_true(_tap(farm)["ok"], "sowing")
	var again := _tap(farm)
	assert_false(again["ok"], "a second tap on it")
	assert_eq(again["reason"], "err.busy", "is busy, not out of hands")
	assert_eq(bs.manual_slots_used(), 1, "still one")
	# Through its stages: while it waits or grows it holds no hand.
	var held_while_waiting := false
	for i in 400:
		sim.advance_ms(500)
		var b := bs.get_building(farm)
		if b["state"] != BuildingSystem.WORKING:
			held_while_waiting = held_while_waiting or bs.manual_jobs().has(farm)
		if b["state"] == BuildingSystem.IDLE:
			_tap(farm)
		assert_true(bs.manual_slots_used() >= 0 and bs.manual_slots_used() <= 1, "never below 0 or above 1")
	assert_false(held_while_waiting, "a cooldown or growing never holds a hand")


func test_a_stopped_or_demolished_job_frees_its_hand() -> void:
	var a := _ready_at("farm", Vector2i(0, 0), "sow")
	var b := _ready_at("mine", Vector2i(1, 0))
	var c := _ready_at("lumberyard", Vector2i(2, 0))
	var d := _ready_at("farm", Vector2i(3, 0), "sow")
	for id: int in [a, b, c]:
		_tap(id)
	assert_eq(_tap(d)["reason"], "err.manual_limit", "full")
	assert_true(bs.demolish(b)["ok"], "the mine comes down mid-job")
	assert_eq(bs.manual_slots_used(), 2, "its hand is free")
	assert_true(_tap(d)["ok"], "the other farm starts")
	# A building under construction is not a job of the hands.
	var e := bs.place("farm", Vector2i(4, 0))
	assert_true(e["ok"], "a farm going up")
	assert_eq(bs.manual_slots_used(), 3, "construction takes no hand")


func test_momo_and_automatic_work_are_never_limited_and_take_no_hand() -> void:
	with_starter_momo(sim)
	var momo: int = (sim.system(&"momo") as MomoSystem).ids()[0]
	for i in 3:
		_tap(_ready_at("farm", Vector2i(i, 0), "sow"))
	assert_eq(bs.manual_slots_used(), 3, "the player's hands full")
	var other := _ready_at("mine", Vector2i(3, 0))
	var r := bs.start_stage(other, momo, 1.0)
	assert_true(r["ok"], "a Momo starts work with every hand busy")
	assert_eq(bs.manual_slots_used(), 3, "and takes no hand")
	assert_false(bs.manual_jobs().has(other), "its job is not the player's")
	var auto := _ready_at("lumberyard", Vector2i(4, 0))
	assert_true(bs.start_stage(auto, JobSystem.AUTO_WORKER, 1.0)["ok"], "automatic work too")
	assert_eq(bs.manual_slots_used(), 3, "no hand either")
	# The same building is never worked twice, whoever asks.
	assert_eq(bs.start_stage(other, BuildingSystem.PLAYER, 1.0)["reason"], "err.busy", "the player cannot take the Momo's job")
	sim.advance_ms(int(bs.get_building(other)["task_end"]) - sim.now_ms())
	assert_ne(bs.get_building(other)["state"], BuildingSystem.WORKING, "the Momo's job completes")


func test_a_scheduled_momo_works_while_the_hands_are_full() -> void:
	# At the game's own pace: the hands' sowing lasts long enough for the Momo
	# to walk over and start while all three are still busy.
	before_each_with(GameData.load_default())
	with_starter_momo(sim)
	var momos: MomoSystem = sim.system(&"momo")
	var momo: int = momos.ids()[0]
	for i in 3:
		_tap(_ready_at("farm", Vector2i(i, 0), "sow"))
	var farm := _ready_at("farm", Vector2i(1, 2), "sow")
	# Step 61: a Momo's ordered Schedule.
	var r := sim.execute({"type": "momo.watch", "momo": momo, "cells": [[1, 2]], "op": "set", "schedule": true})
	assert_true(r["ok"], "scheduled")
	var worked := false
	for i in 240:
		sim.advance_ms(500)
		var b := bs.get_building(farm)
		if b["state"] == BuildingSystem.WORKING and int(b["worker"]) == momo:
			worked = true
			assert_eq(bs.manual_slots_used(), 3, "the hands still all busy as it starts -- three, not four")
			break
	assert_true(worked, "the Momo walks there and works it with all three hands busy")


func test_a_save_with_more_than_the_limit_lets_them_finish() -> void:
	var ids: Array[int] = []
	for i in 5:
		ids.append(_ready_at("farm", Vector2i(i, 0), "sow"))
	# An island from before the limit: five farms the player was working.
	for k in 4:
		var b := bs.get_building(ids[k])
		var stage := bs.current_stage(b)
		b["state"] = BuildingSystem.WORKING
		b["worker"] = BuildingSystem.PLAYER
		b["task_start"] = sim.now_ms()
		b["task_end"] = sim.now_ms() + 1000 * (k + 1)
		b["token"] = int(b["token"]) + 1
		sim.scheduler.schedule(int(b["task_end"]), BuildingSystem.TASK_DONE, {"id": ids[k], "token": b["token"]})
		assert_false(stage.is_empty(), "a stage")
	var loaded := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())), unit_pace())
	var lbs: BuildingSystem = loaded.system(&"buildings")
	assert_eq(lbs.manual_slots_used(), 4, "four still at work after loading")
	assert_eq(loaded.execute({"type": "building.tap", "id": ids[4]})["reason"], "err.manual_limit", "a fifth waits")
	loaded.advance_ms(1000)
	assert_eq(lbs.manual_slots_used(), 3, "one finished -- none cancelled")
	assert_eq(loaded.execute({"type": "building.tap", "id": ids[4]})["reason"], "err.manual_limit", "three busy: still waits")
	loaded.advance_ms(1000)
	assert_eq(lbs.manual_slots_used(), 2, "another finished")
	assert_true(loaded.execute({"type": "building.tap", "id": ids[4]})["ok"], "now it starts")


func test_a_manual_job_is_still_the_players_after_a_save() -> void:
	var farm := _ready_at("farm", Vector2i(0, 0), "sow")
	_tap(farm)
	var loaded := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())), unit_pace())
	assert_eq((loaded.system(&"buildings") as BuildingSystem).manual_jobs(), [farm] as Array[int], "the player's job, after loading")
