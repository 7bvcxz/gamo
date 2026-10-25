extends RefCounted

## Capture scenario (Step 46): a small early island -- the four core
## buildings, ripe crops, one Special and Momo at work -- the frame the art
## contact sheet compares with the concepts. MOMONIUM_CAPTURE_T picks the
## time of day as a fraction of the day (default mid-morning).

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	main.call("_on_hud_action", &"noop")
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(2, 1))
	bs.place_instant("research", Vector2i(0, 0))
	bs.place_instant("mine", Vector2i(2, 0))
	bs.place_instant("lumberyard", Vector2i(0, 2))
	bs.place_instant("clock_tower", Vector2i(0, 1))
	var tap := func() -> void: sim.execute({"type": "building.tap", "id": farm})
	tap.call(); sim.advance_ms(5000)
	for i in 3:
		tap.call(); sim.advance_ms(35000)
	var t := float(OS.get_environment("MOMONIUM_CAPTURE_T")) if OS.get_environment("MOMONIUM_CAPTURE_T") != "" else 0.3
	var day: int = sim.clock.day_ms
	sim.advance_ms(posmod(int(t * day) - sim.clock.time_in_day_ms(), day))
	sim.time_scale = 0.0
	(main.get("cameras") as CameraController).frame_island()
