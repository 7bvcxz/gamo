extends RefCounted

## Capture scenario: a farm worked by Momo, its details open.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000)
	sim.time_scale = 0.0
	(main.get("selection") as SelectionController).select_building(farm)
	main.call("open_details", farm)
