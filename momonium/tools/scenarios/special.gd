extends RefCounted

## Capture scenario: a Lv 6 island with money and materials, an empty tile
## tapped -- "core" shows the five choices, "special" the landmarks submenu
## (the School already standing is not offered).

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	(sim.system(&"economy") as EconomySystem).earn(2000, "capture")
	var inv: InventorySystem = sim.system(&"inventory")
	inv.add("stone", 50, "capture")
	inv.add("wood", 50, "capture")
	inv.add("copper_ingot", 10, "capture")
	var strip: BuildStrip = main.get("build_strip")
	(main.get("selection") as SelectionController).on_tap(Vector2.ZERO, (main.get("projection") as IsoProjection).cell_center(Vector2i(1, 1)))
	if OS.get_environment("MOMONIUM_CAPTURE_STEP") == "special":
		strip.show_specials()
