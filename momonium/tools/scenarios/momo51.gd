extends RefCounted

## Capture scenario (Step 51): Momo at work on a small island -- a farm, a
## mine, a lab and a lumberyard, four Momo posted, one free -- the frame the
## sprite sheet is checked in at gameplay size. MOMONIUM_CAPTURE_T picks the
## time of day (a fraction of the day), MOMONIUM_CAPTURE_ZOOM zooms in on the
## middle of the screen (1 = the island framed as the game opens).

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	main.call("_on_hud_action", &"noop")
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 4:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.building_at(Vector2i(0, 0))
	if farm == 0:
		farm = bs.place_instant("farm", Vector2i(2, 1))
	var lab := bs.place_instant("research", Vector2i(0, 1))
	var mine := bs.place_instant("mine", Vector2i(2, 0))
	var lumber := bs.place_instant("lumberyard", Vector2i(0, 2))
	(sim.system(&"economy") as EconomySystem).earn(5000, "capture")
	for i in 4:
		sim.execute({"type": "momo.hire"})
	var momos: MomoSystem = sim.system(&"momo")
	var ids := momos.ids()
	var jobs := [farm, mine, lab, lumber]
	for i in mini(jobs.size(), ids.size()):
		sim.execute({"type": "momo.assign", "momo": ids[i], "building": jobs[i]})
	if ids.size() > 4:
		sim.execute({"type": "momo.unassign", "momo": ids[4]})
	sim.advance_ms(20000)
	var t := float(OS.get_environment("MOMONIUM_CAPTURE_T")) if OS.get_environment("MOMONIUM_CAPTURE_T") != "" else 0.3
	var day: int = sim.clock.day_ms
	sim.advance_ms(posmod(int(t * day) - sim.clock.time_in_day_ms(), day))
	sim.time_scale = 0.0
	var cams: CameraController = main.get("cameras")
	cams.frame_island()
	var z := float(OS.get_environment("MOMONIUM_CAPTURE_ZOOM")) if OS.get_environment("MOMONIUM_CAPTURE_ZOOM") != "" else 1.0
	if z != 1.0:
		cams.zoom_at(z, cams.viewport_size() * Vector2(0.5, 0.55))
