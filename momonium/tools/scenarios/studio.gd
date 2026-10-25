extends RefCounted

## Capture scenario: the demo island's game studio details.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var studio := (sim.system(&"buildings") as BuildingSystem).building_at(Vector2i(4, 2))
	(main.get("selection") as SelectionController).select_building(studio)
	main.call("open_details", studio)
