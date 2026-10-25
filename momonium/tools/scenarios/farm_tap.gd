extends RefCounted

## Capture scenario: a farm on (1, 0), tapped, two seconds into its work.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var id := buildings.place_instant("farm", Vector2i(1, 0))
	var sel: SelectionController = main.get("selection")
	sel.select_building(id)
	sim.execute({"type": "building.tap", "id": id})
	sim.advance_ms(2000)
	sim.time_scale = 0.0
