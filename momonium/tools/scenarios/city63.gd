extends RefCounted

## Capture scenario (Step 63): one irregular island -- outer corners, inner
## corners, a cove and a one-tile lake inside -- at the tier
## MOMONIUM_TIER (0 Village, 1 City, 2 Nation) and the time of day
## MOMONIUM_CAPTURE_T (default noon), framed the same every time, so a
## Village and a City are the same island under the same camera.

const OWNED := [
	"######",
	"######",
	"###.##",
	"######",
	".#.###",
]


func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for y in OWNED.size():
		for x in String(OWNED[y]).length():
			if String(OWNED[y])[x] == "#" and not world.is_owned(Vector2i(x, y)):
				world.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("farm", Vector2i(4, 3))
	bs.place_instant("lumberyard", Vector2i(1, 1))
	var t := float(OS.get_environment("MOMONIUM_CAPTURE_T")) if OS.get_environment("MOMONIUM_CAPTURE_T") != "" else 0.3
	sim.advance_to(int(t * sim.clock.day_ms))
	sim.time_scale = 0.0
	var tier := int(OS.get_environment("MOMONIUM_TIER")) if OS.get_environment("MOMONIUM_TIER") != "" else 0
	var tiers: TierSystem = sim.system(&"tiers")
	if tier > 0:
		# As a load would: the tier's look at once, without the celebration.
		tiers.tier = tier
		sim.bus.emit(&"game_loaded", {})
	# One camera for every shot: framed once, and put back after anything
	# that reframes in the first frames (the promotion's celebration).
	var cams: CameraController = main.get("cameras")
	cams.frame_island()
	var zoom := cams.camera.zoom
	var at := cams.camera.position
	for i in 3:
		(func() -> void:
			cams.camera.zoom = zoom
			cams.camera.position = at).call_deferred()
	main.get_tree().process_frame.connect(func() -> void:
		cams.camera.zoom = zoom
		cams.camera.position = at)
