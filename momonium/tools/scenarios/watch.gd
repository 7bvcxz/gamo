extends RefCounted

## Capture scenario: a 3x3 island, a Momo watching three tiles (a farm among
## them), selected and editing, one refused tile flashing.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	main.call("_on_hud_action", &"noop")
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("farm", Vector2i(1, 0))
	bs.place_instant("lumberyard", Vector2i(2, 1))
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[1, 0], [2, 0], [2, 1]], "op": "add"})
	(main.get("selection") as SelectionController).select_momo(1)
	if OS.get_environment("MOMONIUM_CAPTURE_STEP") == "edit":
		var editor: WatchEditor = main.get("watch_editor")
		editor.begin_edit()
		(main.get("watch_overlay") as WatchOverlay).flash(Vector2i(0, 2))
