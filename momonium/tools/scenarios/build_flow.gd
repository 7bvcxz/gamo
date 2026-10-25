extends RefCounted

## Capture scenario selected by MOMONIUM_CAPTURE_STEP:
##   menu       the shop's building list open
##   placing    placement ghost on (1, 0), valid
##   blocked    placement ghost on an occupied cell
##   building   a farm 2 s into its 5 s construction, selected

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var step := OS.get_environment("MOMONIUM_CAPTURE_STEP")
	match step:
		"menu":
			main.call("_on_hud_action", &"shop")
		"placing":
			(main.get("placement") as PlacementMode).open("farm")
			(main.get("placement") as PlacementMode).on_world_tap((main.get("projection") as IsoProjection).cell_center(Vector2i(1, 0)))
		"blocked":
			(sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(0, 0))
			(main.get("placement") as PlacementMode).open("farm")
			(main.get("placement") as PlacementMode).on_world_tap((main.get("projection") as IsoProjection).cell_center(Vector2i(0, 0)))
		_:
			var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})
			(main.get("selection") as SelectionController).select_building(int(r["id"]))
			sim.advance_ms(2000)
