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
	# The Momo these cases are about (Step 53: a new island has none).
	with_starter_momo(sim)
	await tree.process_frame


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
	var arrived := int((sim.system(&"momo") as MomoSystem).get_momo(1)["end"])
	sim.advance_to(arrived + 300)
	await tree.process_frame
	var actor := (main.get("momo_views") as MomoViews).actor(1)
	assert_true(actor.is_working(), "the simulation has Momo 1 sowing")
	assert_eq(actor.rig.state, "work", "and the rig shows it working")
	# Sowing then the first watering run back to back (no wait after sowing);
	# the wait after watering is where Momo stands idle.
	var stages: Array = sim.data.building_type("farm")["cycle"]["stages"]
	var x := sim.data.get_float("balance", "momo.work_time_multiplier", 4.0)
	var work := int(round((float(stages[0]["seconds"]) + float(stages[1]["seconds"])) * work_scale(sim) * x * 1000.0))
	sim.advance_to(arrived + work + int(float(stages[1]["cooldown"]) * 500.0))
	await tree.process_frame
	assert_false(actor.is_working(), "during the wait after watering Momo is not working")
	assert_ne(actor.rig.state, "work", "and stops the work pose")


## Step 51: the sheet's job cells follow the stage the simulation has Momo
## doing; the moods have poses.
func test_the_work_cell_follows_the_job() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var arrived := int(momos.get_momo(1)["end"])
	sim.advance_to(arrived + 300)
	await tree.process_frame
	var actor := (main.get("momo_views") as MomoViews).actor(1)
	assert_true(actor.is_working(), "sowing")
	assert_eq(actor.rig.cell_name(), "back_work", "sowing: busy, back turned (no seed in the sheet)")
	var stages: Array = sim.data.building_type("farm")["cycle"]["stages"]
	var x := sim.data.get_float("balance", "momo.work_time_multiplier", 4.0)
	sim.advance_to(arrived + int(float(stages[0]["seconds"]) * work_scale(sim) * x * 1000.0) + 300)
	await tree.process_frame
	if actor.is_working():
		assert_eq(actor.work_pose(), "water", "watering")
		assert_eq(actor.rig.cell_name(), "water", "with the watering can")
	for job: Array in [["mine", Vector2i(0, 1), "dig"], ["research", Vector2i(1, 1), "study"]]:
		var id := buildings.place_instant(String(job[0]), job[1])
		assert_true(id > 0, "%s placed on the island" % job[0])
		assert_true(sim.execute({"type": "momo.assign", "momo": 1, "building": id})["ok"], "%s: assigned" % job[0])
		sim.advance_to(int(momos.get_momo(1)["end"]) + 300)
		await tree.process_frame
		assert_true(actor.is_working(), "%s: working" % job[0])
		assert_eq(actor.rig.cell_name(), String(job[2]), "%s: its own pose" % job[0])


func test_every_mood_has_a_pose() -> void:
	for mood: String in MomoMood.MOODS.values():
		assert_true(MomoActor.MOOD_POSE.has(mood), "%s has a pose" % mood)
		assert_true(MomoRig.MOOD_POSES.has(String(MomoActor.MOOD_POSE[mood])), "%s: a pose the sheet has" % mood)
