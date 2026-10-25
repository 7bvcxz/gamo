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


func test_a_working_momo_shows_the_work_pose() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(3000)
	await tree.process_frame
	var actor := (main.get("momo_views") as MomoViews).actor(1)
	assert_true(actor.is_working(), "the simulation has Momo 1 sowing")
	assert_eq(actor.rig.state, "work", "and the rig shows it working")
	# Sowing then the first watering run back to back (no wait after sowing);
	# the 30 s wait after watering is where Momo stands idle.
	var arrived := int((sim.system(&"momo") as MomoSystem).get_momo(1)["end"])
	sim.advance_to(arrived + 40000 + 5000)
	await tree.process_frame
	assert_false(actor.is_working(), "during the wait after watering Momo is not working")
	assert_ne(actor.rig.state, "work", "and stops the work pose")
