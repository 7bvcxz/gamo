extends RefCounted

## Capture scenario: a village meeting every City milestone -- "status" shows
## the Status tab's tier section; "party" the promotion's celebration.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var momos: MomoSystem = sim.system(&"momo")
	momos.add_momo(Vector2(0.5, 1.5))
	momos.add_momo(Vector2(1.5, 0.5))
	var rs: ResearchSystem = sim.system(&"research")
	rs.completed["momo_training"] = 0
	rs.bought["momo_training"] = 3
	(sim.system(&"economy") as EconomySystem).earn(1600, "sale")
	if OS.get_environment("MOMONIUM_CAPTURE_STEP") == "party":
		sim.execute({"type": "tier.promote"})
	else:
		main.call("_on_hud_action", &"status")
