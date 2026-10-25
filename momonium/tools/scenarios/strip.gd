extends RefCounted

## Capture scenario: a new island, an empty tile tapped -- the four choices.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var proj: IsoProjection = main.get("projection")
	(main.get("selection") as SelectionController).on_tap(Vector2.ZERO, proj.cell_center(Vector2i(1, 1)))
