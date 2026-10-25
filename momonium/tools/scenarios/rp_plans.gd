extends RefCounted

## Capture scenario: after a sale -- 5 points, Momo paths unlocked, a plan
## saved in slot A, the draft showing its preview.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var rs: ResearchSystem = sim.system(&"research")
	for id: String in ["momo_training", "momo_paths", "momo_reach", "watering_can", "sharp_axes"]:
		rs.unlocked[id] = true
	rs.rp_earned = 5
	rs.save_profile(0, {"momo_training": 3, "momo_reach": 2})
	main.call("open_rp")
	var rp: RpView = main.get("rp_view")
	rp.draft = {"momo_training": 2, "momo_reach": 1, "momo_paths": 1}
	rp.refresh()
