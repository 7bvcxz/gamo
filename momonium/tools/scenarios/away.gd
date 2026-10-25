extends RefCounted

## Capture scenario (Step 49): the welcome-back card after two hours away --
## a farm and a lumberyard worked by two Momo, caught up by the real offline
## run. MOMONIUM_CAPTURE_STEP=quiet: three hours on an untouched island;
## =capped: ten hours (the island counts eight).

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var step := OS.get_environment("MOMONIUM_CAPTURE_STEP")
	var hours := 3 if step == "quiet" else (10 if step == "capped" else 2)
	if step != "quiet":
		(sim.system(&"economy") as EconomySystem).earn(200, "capture")
		sim.execute({"type": "momo.hire"})
		var bs: BuildingSystem = sim.system(&"buildings")
		var f := bs.place_instant("farm", Vector2i(1, 0))
		var l := bs.place_instant("lumberyard", Vector2i(0, 1))
		sim.execute({"type": "momo.assign", "momo": 1, "building": f})
		sim.execute({"type": "momo.assign", "momo": 2, "building": l})
	var tips: Object = main.get("tips")
	if tips != null:
		tips.set("allowed", false)
	main.call("_tell_about_return", OfflineProgress.catch_up(sim, hours * 3600000))
