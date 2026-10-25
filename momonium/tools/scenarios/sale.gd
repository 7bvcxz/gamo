extends RefCounted

## Capture scenario: a Lv 6 island with a few buildings and research levels --
## "sale" shows the sale frame; "rp" the research points after a sale.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	(sim.system(&"economy") as EconomySystem).earn(600, "capture")
	sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})
	sim.execute({"type": "building.place", "building": "lumberyard", "anchor": [0, 1]})
	var rs: ResearchSystem = sim.system(&"research")
	for id: String in ["momo_training", "momo_reach", "farm_expansion"]:
		rs.bought[id] = 2 if id == "momo_training" else 1
		rs.completed[id] = 0
		rs.unlocked[id] = true
	if OS.get_environment("MOMONIUM_CAPTURE_STEP") == "rp":
		rs.adopt(rs.carry_over())
		rs.bought.clear()
		rs.completed.clear()
		main.call("open_rp")
		var rp: RpView = main.get("rp_view")
		rp.draft = {"momo_training": 1, "momo_reach": 1}
		rp.refresh()
	else:
		main.call("open_sale")
