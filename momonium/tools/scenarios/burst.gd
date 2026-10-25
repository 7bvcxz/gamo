extends RefCounted

## Capture scenario: a Clock Tower standing, 12 s into a burst -- the HUD's
## small dial counts the burst down.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("clock_tower", Vector2i(2, 2))
	bs.place_instant("lumberyard", Vector2i(0, 0))
	sim.advance_to(180000 * 2 + 12000)
	sim.time_scale = 0.0
