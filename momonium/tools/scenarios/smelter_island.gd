extends RefCounted

## Capture scenario: the same smelter, no panel -- the island view.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("smelter", Vector2i(1, 0))
	bs.place_instant("mine", Vector2i(0, 1))
	sim.time_scale = 0.0
