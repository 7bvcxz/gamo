extends RefCounted

## Capture scenario: a lab on the island, Momo's first proposal accepted,
## two research notes in the store, the research menu open.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	buildings.place_instant("research", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(250000)
	sim.execute({"type": "mail.claim", "id": 1})
	(sim.system(&"inventory") as InventorySystem).add("notes", 2, "capture")
	sim.time_scale = 0.0
	main.call("_on_hud_action", &"research")
