extends RefCounted

## Capture scenario (Step 66): one Momo at work at every job the island has --
## a farm sowing, watering and harvesting, a mine, a lumberyard felling and
## replanting, a lab, a smelter, a steam engine, a car factory and a game
## studio -- each standing at its building's work spot in the stage it shows,
## the clock stopped. MOMONIUM_CAPTURE_ZOOM zooms in on the middle.

## [building, stage index]
const JOBS := [
	["farm", 0], ["farm", 1], ["farm", 2], ["mine", 0],
	["lumberyard", 0], ["lumberyard", 1], ["research", 0], ["smelter", 0],
	["steam_engine", 0], ["car_factory", 0], ["game_studio", 0],
]


func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	(main.get("tips") as Tips).allowed = false
	sim.replaying = true
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var momos: MomoSystem = sim.system(&"momo")
	for id: int in momos.ids().duplicate():
		momos.momos.erase(id)
	for i in JOBS.size():
		var job: Array = JOBS[i]
		var b := bs.place_instant(String(job[0]), Vector2i(i % 4, i / 4))
		var rec := bs.get_building(b)
		rec["state"] = BuildingSystem.WORKING
		rec["stage"] = int(job[1])
		# Half way through, as the progress ring shows it.
		var ms := int(bs.stage_seconds(rec, bs.current_stage(rec)) * 1000.0)
		rec["task_start"] = sim.now_ms() - ms / 2
		rec["task_end"] = sim.now_ms() + ms / 2
		var m := momos.add_momo(momos.work_spot(b))
		rec["worker"] = m
		momos.get_momo(m)["assigned"] = b
	sim.time_scale = 0.0
	sim.replaying = false
	(main.get("celebration") as CanvasItem).hide()
	var cams: CameraController = main.get("cameras")
	cams.frame_island()
	var z := float(OS.get_environment("MOMONIUM_CAPTURE_ZOOM")) if OS.get_environment("MOMONIUM_CAPTURE_ZOOM") != "" else 1.0
	if z != 1.0:
		cams.zoom_at(z, cams.world_to_screen((main.get("projection") as IsoProjection).to_screen(Vector2(2, 1.5))))
