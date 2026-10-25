extends RefCounted

## Capture scenario: a played day, Status frame open on tab 2.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	(sim.system(&"economy") as EconomySystem).earn(40, "capture")
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000 * 14)
	sim.time_scale = 0.0
	main.call("_on_hud_action", &"status")
	(main.get("status_frame") as PanelFrame).show_tab(2)
