extends RefCounted

## Capture scenario (Step 55): one building with Momo standing around it --
## in front, at each side, passing its tile's back half on either side, and
## well behind -- to see who is drawn over whom. MOMONIUM_DEPTH55 picks the
## building (farm, mine, lumberyard, research, clock_tower);
## MOMONIUM_CAPTURE_ZOOM zooms in. The "before" shots set
## art.momo_depth.bias_tiles to 0 -- exactly the order before Step 55.
## Offsets are from the building's centre, in tiles (x right-down, y left-down
## on screen): front (+,+), screen left (-,+), screen right (+,-), behind (-,-).

const SPOTS := [Vector2(0.62, 0.62), Vector2(-0.55, 0.62), Vector2(0.62, -0.55), Vector2(0.18, -0.45), Vector2(-0.45, 0.18), Vector2(-0.9, -0.9)]


func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	(main.get("tips") as Tips).allowed = false
	sim.replaying = true
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var type := OS.get_environment("MOMONIUM_DEPTH55")
	if type == "":
		type = "research"
	bs.place_instant(type, Vector2i(1, 1))
	var momos: MomoSystem = sim.system(&"momo")
	var centre := Vector2(1.5, 1.5)
	for d: Vector2 in SPOTS:
		momos.add_momo(centre + d)
	sim.time_scale = 0.0
	sim.replaying = false
	(main.get("celebration") as CanvasItem).hide()
	var cams: CameraController = main.get("cameras")
	cams.frame_island()
	var z := float(OS.get_environment("MOMONIUM_CAPTURE_ZOOM")) if OS.get_environment("MOMONIUM_CAPTURE_ZOOM") != "" else 1.0
	if z != 1.0:
		cams.zoom_at(z, cams.world_to_screen((main.get("projection") as IsoProjection).to_screen(centre)))
	# Where each Momo's body is on screen (window pixels), for the annotated
	# sheet: "depth55: <spot> <x> <y>".
	var layer: EntityLayer = main.get("entities")
	var t := main.get_viewport().get_final_transform()
	for i in SPOTS.size():
		var body := layer.ground_point(centre + SPOTS[i]) + Vector2(0, -40)
		var p: Vector2 = t * cams.world_to_screen(body)
		print("depth55: %d %d %d" % [i, roundi(p.x), roundi(p.y)])
