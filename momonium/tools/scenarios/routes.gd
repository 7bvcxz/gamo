extends RefCounted

## Capture scenario: a 3x3 island, a Momo watching four lumberyards on the
## zigzag route, selected: its tiles, its numbered route and the panel.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	for c: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
		bs.place_instant("lumberyard", c)
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0], [2, 0], [0, 2], [2, 2]], "op": "add"})
	sim.execute({"type": "momo.route", "momo": 1, "route": "zigzag"})
	(main.get("selection") as SelectionController).select_momo(1)
