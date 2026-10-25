extends RefCounted

## Capture scenario: jumps the clock to a fraction of Day 1 given by the
## MOMONIUM_CAPTURE_T environment variable (default sunset).

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var t := float(OS.get_environment("MOMONIUM_CAPTURE_T")) if OS.get_environment("MOMONIUM_CAPTURE_T") != "" else 0.68
	sim.advance_to(int(t * sim.clock.day_ms))
	sim.time_scale = 0.0
