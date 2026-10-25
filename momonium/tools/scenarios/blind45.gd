extends RefCounted

## Capture scenario (Step 45, blind playtest fixes): a farm worked by the
## first Momo, two crops waiting for dawn (the line under the EXP pill, all of
## it on screen and saying when it pays), and the Momo selected -- its pencil
## waits by its card. MOMONIUM_CAPTURE_STEP=level: the Lv 2 banner naming
## what it opened.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var tips: Object = main.get("tips")
	if tips != null:
		tips.set("allowed", false)
	var bs: BuildingSystem = sim.system(&"buildings")
	var f := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": f})
	sim.advance_ms(30000)
	(sim.system(&"inventory") as InventorySystem).add("crop", 2, "capture")
	if OS.get_environment("MOMONIUM_CAPTURE_STEP") == "level":
		var prog: ProgressionSystem = sim.system(&"progression")
		prog.add_exp(prog.next_level_exp(), "capture")
		return
	(main.get("selection") as SelectionController).select_momo(1)
