extends RefCounted

## Capture scenario: land mode open with $120, the cell east of the island chosen.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	(sim.system(&"economy") as EconomySystem).earn(110, "capture")
	var mode: LandMode = main.get("land_mode")
	mode.open()
	var proj: IsoProjection = main.get("projection")
	mode.on_world_tap(proj.cell_center(Vector2i(2, 1)))
	sim.time_scale = 0.0
