extends RefCounted

## Capture scenario (Step 47): growth feedback from real events -- a ripe farm
## harvested by a tap (the "+N" crop pop over it, "+EXP" by the level), and
## the day's sale (the "+$" by the money). MOMONIUM_CAPTURE_STEP=reduced takes
## the same frame with reduced motion.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	main.call("_on_hud_action", &"noop")
	if OS.get_environment("MOMONIUM_CAPTURE_STEP") == "reduced":
		FxPrefs.reduced_motion = true
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 1))
	bs.place_instant("farm", Vector2i(2, 1))
	var tap := func() -> void: sim.execute({"type": "building.tap", "id": farm})
	tap.call(); sim.advance_ms(5000)
	for i in 3:
		tap.call(); sim.advance_ms(35000)
	# Settle into the next day first, so the sale below is the only one.
	sim.advance_to(sim.clock.next_day_start_ms() + 1000)
	(main.get("hud") as Hud).flush_feedback()
	(main.get("hud") as Hud).pops.clear()
	(main.get("feedback_fx") as FeedbackFx).flush()
	(main.get("feedback_fx") as FeedbackFx).clear()
	tap.call()
	sim.advance_ms(6000)
	sim.advance_to(sim.clock.next_day_start_ms() + 10)
	sim.time_scale = 0.0
	(main.get("cameras") as CameraController).frame_island()
