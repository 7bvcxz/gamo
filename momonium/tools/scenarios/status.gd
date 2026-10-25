extends RefCounted

## Capture scenario: some EXP and farm mastery, Status open.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var prog: ProgressionSystem = sim.system(&"progression")
	prog.add_exp(135, "capture")
	prog.add_mastery("farm", 60)
	sim.time_scale = 0.0
	main.call("_on_hud_action", &"status")
