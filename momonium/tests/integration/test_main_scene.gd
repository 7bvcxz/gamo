extends "res://tests/framework/test_case.gd"

## The real main scene in a real SceneTree: it builds a simulation and the
## frame loop moves its clock.

const MainScene := preload("res://scenes/main.tscn")


func test_main_scene_runs_the_clock() -> void:
	var main: Node = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var sim: Simulation = main.get("sim")
	assert_true(sim != null, "main builds a simulation")
	var before := sim.now_ms()
	for i in 10:
		await tree.process_frame
	assert_true(sim.now_ms() > before, "frames advance simulated time (%d -> %d)" % [before, sim.now_ms()])
	assert_eq(sim.clock.day_number(), 1, "still Day 1 after a few frames")
	main.queue_free()
	await tree.process_frame
