extends RefCounted

## Capture scenario: the demo island, the second mine's details (priority),
## then (momo variant) a worker's card.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var bs: BuildingSystem = sim.system(&"buildings")
	var mine := bs.building_at(Vector2i(3, 1))
	(main.get("selection") as SelectionController).select_building(mine)
	main.call("open_details", mine)
