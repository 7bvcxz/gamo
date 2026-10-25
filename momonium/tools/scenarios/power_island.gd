extends RefCounted

## Capture scenario: the demo island, no panel.

func setup(main: Node) -> void:
	(main.get("sim") as Simulation).time_scale = 0.0
