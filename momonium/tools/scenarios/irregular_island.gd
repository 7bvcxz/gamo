extends RefCounted

## Capture scenario: grows the start island into an irregular shape with a
## notch and a peninsula, to look at cliffs, rims and depth order.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for cell: Vector2i in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(3, 1), Vector2i(3, 2), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 2)]:
		world.add_land(cell)
	(main.get("cameras") as CameraController).frame_island()
