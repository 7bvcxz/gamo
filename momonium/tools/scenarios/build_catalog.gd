extends RefCounted

## Capture scenario: a new island at Lv 1 with the catalog open from the
## right-side Build button -- farm buildable, the others showing their level.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	main.call("_on_hud_action", &"build")
