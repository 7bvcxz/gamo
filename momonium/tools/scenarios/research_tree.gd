extends RefCounted

## Capture scenario: the farm branch part-way researched, menu open.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var research: ResearchSystem = sim.system(&"research")
	for id: String in ["farm_expansion", "watering_efficiency", "harvest_boost"]:
		research.completed[id] = 0
	(sim.system(&"buildings") as BuildingSystem).place_instant("research", Vector2i(0, 1))
	(sim.system(&"progression") as ProgressionSystem).add_mastery("farm", 300)
	sim.time_scale = 0.0
	main.call("_on_hud_action", &"research")
