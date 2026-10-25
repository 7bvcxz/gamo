extends RefCounted

## Capture scenario: a lab at Lv 6 with materials, its details showing refits.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	(sim.system(&"progression") as ProgressionSystem).add_exp(6000, "capture")
	(sim.system(&"economy") as EconomySystem).earn(2000, "capture")
	(sim.system(&"research") as ResearchSystem).completed["photovoltaics"] = 0
	(sim.system(&"inventory") as InventorySystem).add("copper_ingot", 8, "capture")
	(sim.system(&"inventory") as InventorySystem).add("stone", 20, "capture")
	var lab := (sim.system(&"buildings") as BuildingSystem).place_instant("research", Vector2i(1, 0))
	(main.get("selection") as SelectionController).select_building(lab)
	main.call("open_details", lab)
