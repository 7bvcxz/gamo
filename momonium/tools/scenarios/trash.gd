extends RefCounted

## Capture scenario: a farm selected, the trash tapped -- the check above it.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	(main.get("selection") as SelectionController).select_building(farm)
	(main.get("panel") as ContextPanel).trash_button.pressed.emit()
