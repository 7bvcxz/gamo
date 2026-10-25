extends RefCounted

## Capture scenario: farming research done, the farm's details open with its
## varieties, drip irrigation watering by itself.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var research: ResearchSystem = sim.system(&"research")
	for id: String in ["farm_expansion", "watering_efficiency", "harvest_boost", "watering_can", "drip_irrigation", "seed_selection"]:
		research.completed[id] = 0
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	buildings.place_instant("research", Vector2i(0, 1))
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(6000)
	sim.time_scale = 0.0
	(main.get("selection") as SelectionController).select_building(farm)
	main.call("open_details", farm)
