extends RefCounted

## Capture scenario: night, a burst of the Clock Tower, the four families at
## bronze / silver / gold mastery, a smelter at work -- lights, pennants,
## smoke, the tower's glow. MOMONIUM_CAPTURE_STEP "day" shows the same by day.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("farm", Vector2i(0, 0))
	bs.place_instant("mine", Vector2i(2, 0))
	bs.place_instant("lumberyard", Vector2i(0, 2))
	var smelter := bs.place_instant("smelter", Vector2i(1, 1))
	bs.place_instant("clock_tower", Vector2i(2, 2))
	var prog: ProgressionSystem = sim.system(&"progression")
	prog.mastery["farm"] = {"level": 8, "exp": 0}
	prog.mastery["mine"] = {"level": 5, "exp": 0}
	prog.mastery["lumberyard"] = {"level": 3, "exp": 0}
	var inv: InventorySystem = sim.system(&"inventory")
	inv.add("copper_ore", 20, "capture")
	inv.add("wood", 20, "capture")
	var day := OS.get_environment("MOMONIUM_CAPTURE_STEP") == "day"
	sim.advance_to(180000 + (12000 if day else 27000))
	bs.start_stage(smelter, 0, 4.0)
	sim.time_scale = 0.0
