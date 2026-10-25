extends RefCounted

## Capture scenario: a smelter short of ore (marker on the island), its
## details open with the recipes and what it takes.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var bs: BuildingSystem = sim.system(&"buildings")
	(sim.system(&"research") as ResearchSystem).completed["bloomery"] = 0
	var sm := bs.place_instant("smelter", Vector2i(1, 0))
	bs.place_instant("mine", Vector2i(0, 1))
	(sim.system(&"inventory") as InventorySystem).add("copper_ore", 1, "capture")
	(sim.system(&"inventory") as InventorySystem).add("wood", 3, "capture")
	sim.time_scale = 0.0
	(main.get("selection") as SelectionController).select_building(sm)
	main.call("open_details", sm)
