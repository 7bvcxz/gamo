extends RefCounted

## Capture scenario: the sea tile right of the island previewed for buying --
## MOMONIUM_CAPTURE_STEP "touch" shows a finger's first tap ("tap again"),
## "short" with too little money, anything else a mouse hovering with money.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var buyer: LandBuyer = main.get("land_buyer")
	var at := (main.get("projection") as IsoProjection).cell_center(Vector2i(2, 0))
	match OS.get_environment("MOMONIUM_CAPTURE_STEP"):
		"touch":
			(sim.system(&"economy") as EconomySystem).earn(100, "capture")
			buyer.on_tap(at, false)
		"short":
			buyer.on_hover(at)
		_:
			(sim.system(&"economy") as EconomySystem).earn(100, "capture")
			buyer.on_hover(at)
