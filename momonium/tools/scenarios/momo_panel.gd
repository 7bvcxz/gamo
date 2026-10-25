extends RefCounted

## Capture scenario: a farm with Momo assigned, a second Momo hired and selected.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	(sim.system(&"economy") as EconomySystem).earn(40, "capture")
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var r := sim.execute({"type": "momo.hire"})
	sim.advance_ms(9000)
	(main.get("selection") as SelectionController).select_momo(int(r["id"]))
	sim.time_scale = 0.0
