extends RefCounted

## Capture scenario: a few played days with rounds and a waiting smelter,
## the Status frame open on its Stats tab.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	(sim.system(&"economy") as EconomySystem).earn(400, "capture")
	(sim.system(&"progression") as ProgressionSystem).add_exp(3000, "capture")
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	bs.place_instant("lumberyard", Vector2i(2, 1))
	bs.place_instant("smelter", Vector2i(0, 2))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[2, 1]], "op": "add"})
	sim.advance_ms(sim.clock.day_ms * 5)
	sim.time_scale = 0.0
	main.call("_on_hud_action", &"status")
	(main.get("status_frame") as PanelFrame).show_tab(5)
