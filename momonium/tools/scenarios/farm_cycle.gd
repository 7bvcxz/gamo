extends RefCounted

## Capture scenario: a selected farm advanced to the point named by
## MOMONIUM_CAPTURE_STEP: sowing | cooldown | watering | ripe | harvesting.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var id := buildings.place_instant("farm", Vector2i(1, 0))
	(main.get("selection") as SelectionController).select_building(id)
	var tap := func() -> void: sim.execute({"type": "building.tap", "id": id})
	match OS.get_environment("MOMONIUM_CAPTURE_STEP"):
		"sowing":
			tap.call(); sim.advance_ms(2500)
		"cooldown":
			tap.call(); sim.advance_ms(5000); tap.call(); sim.advance_ms(5000 + 8000)
		"watering":
			tap.call(); sim.advance_ms(5000); tap.call(); sim.advance_ms(35000); tap.call(); sim.advance_ms(2000)
		"ripe":
			tap.call(); sim.advance_ms(5000)
			for i in 3:
				tap.call(); sim.advance_ms(35000)
		_:
			tap.call(); sim.advance_ms(5000)
			for i in 3:
				tap.call(); sim.advance_ms(35000)
			tap.call(); sim.advance_ms(2500)
	sim.time_scale = 0.0
