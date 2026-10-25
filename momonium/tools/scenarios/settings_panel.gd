extends RefCounted

## Capture scenario: the settings panel.

func setup(main: Node) -> void:
	(main.get("sim") as Simulation).time_scale = 0.0
	main.call("_on_hud_action", &"settings")
