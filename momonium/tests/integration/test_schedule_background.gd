extends "res://tests/framework/test_case.gd"

## Step 85 in the running game: a Momo on the adaptive Schedule walking to
## its stop when the tab goes to the background (Step 79: the island stands
## still) is on the same walk to the same stop when it comes back -- no new
## decision, nothing caught up -- and goes on to work it. (A save and a
## reload: test_schedule_adaptive.gd.)

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	with_starter_momo(sim)
	await tree.process_frame
	var world: WorldSystem = sim.system(&"world")
	for x in 8:
		for y in 8:
			world.add_land(Vector2i(x, y))
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_a_walk_survives_the_background() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var far := bs.place_instant("farm", Vector2i(7, 7))
	bs.place_instant("smelter", Vector2i(1, 0))
	assert_true(sim.execute({"type": "momo.watch", "momo": 1, "cells": [[1, 0], [7, 7]], "op": "add", "schedule": true})["ok"], "scheduled")
	sim.advance_ms(1500)
	var m := momos.get_momo(1)
	assert_eq(int(m["assigned"]), far, "walking to the farm (the smelter has no ore)")
	assert_true(momos.is_moving(1), "on its way")
	var to: Array = m["to"]
	var end := int(m["end"])
	var before := sim.now_ms()
	main.call("go_background")
	sim.time_scale = 1.0
	main.call("_process", 1.0)
	main.call("come_back")
	main.call("_process", 600.0)
	sim.time_scale = 0.0
	assert_eq(sim.now_ms(), before, "ten minutes away ran nothing")
	assert_eq(int(momos.get_momo(1)["assigned"]), far, "the same stop")
	assert_eq(momos.get_momo(1)["to"], to, "the same destination")
	assert_eq(int(momos.get_momo(1)["end"]), end, "the same time left on the walk")
	var started := [0]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and int(p.get("worker", 0)) == 1 and int(p["id"]) == far:
			started[0] += 1)
	sim.advance_ms(end - sim.now_ms() + 100)
	assert_eq(started[0], 1, "and it works the farm when it gets there")
