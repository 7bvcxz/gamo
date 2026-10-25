extends RefCounted

## Capture scenario: the demo island, a worker's Momo card.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	(main.get("selection") as SelectionController).select_momo(5)
