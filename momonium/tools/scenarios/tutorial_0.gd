extends RefCounted

## Capture scenario: the first-run tutorial at step 0.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	(main.get("tutorial") as Tutorial).start()
	match 0:
		1:
			main.call("_on_hud_action", &"build")
		2:
			main.call("_on_hud_action", &"build")
			(main.get("build_menu") as BuildMenu).picked.emit("farm")
		5:
			var bs: BuildingSystem = sim.system(&"buildings")
			var f := bs.place_instant("farm", Vector2i(1, 0))
			sim.execute({"type": "building.tap", "id": f})
			sim.advance_ms(6000)
