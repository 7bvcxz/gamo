extends RefCounted

## Capture scenario: the demo island at dusk with its power panel open.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	main.call("_on_hud_action", &"power")
