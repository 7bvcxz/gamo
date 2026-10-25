extends "res://tests/framework/test_case.gd"

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_the_starting_momo_is_on_screen_and_sleeps_at_night() -> void:
	var views: MomoViews = main.get("momo_views")
	var actor := views.actor(1)
	assert_true(actor != null, "an actor for the starting Momo")
	assert_true(actor.get_parent() is EntityLayer, "depth-sorted with the buildings")
	await tree.process_frame
	assert_ne(actor.rig.state, "sleep", "awake by day")
	sim.advance_to(int(0.8 * sim.clock.day_ms))
	await tree.process_frame
	assert_eq(actor.rig.state, "sleep", "asleep at night")
	sim.advance_to(sim.clock.next_day_start_ms() + 1000)
	await tree.process_frame
	assert_ne(actor.rig.state, "sleep", "up in the morning")
