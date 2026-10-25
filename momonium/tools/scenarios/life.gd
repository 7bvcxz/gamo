extends RefCounted

## Capture scenario: the demo island's Life tab.

func setup(main: Node) -> void:
	(main.get("sim") as Simulation).time_scale = 0.0
	main.call("_on_hud_action", &"status")
	(main.get("status_frame") as PanelFrame).show_tab(4)
