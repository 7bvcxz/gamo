extends RefCounted

## Capture scenario (Step 50, incremental pacing): MOMONIUM_CAPTURE_STEP=
##   start -- a new player's island: the ripe crop, the tutorial ringing it;
##   money -- the harvest just picked: "+$" over the farm and the money pill,
##            the "+$N/min" line under the EXP pill;
##   land  -- every tile in use and the next one affordable: the sea tile the
##            island would grow into glows with its price, unasked;
##   shop  -- a building nobody looks after and a hire affordable: a dot on
##            the Hire button; wood and notes in the store: the stock row.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.time_scale = 0.0
	var tips: Object = main.get("tips")
	if tips != null:
		tips.set("allowed", false)
	var bs: BuildingSystem = sim.system(&"buildings")
	var eco: EconomySystem = sim.system(&"economy")
	match OS.get_environment("MOMONIUM_CAPTURE_STEP"):
		"money":
			var f := bs.place_ready("farm", Vector2i(0, 0), "harvest")
			bs.place_instant("farm", Vector2i(1, 0))
			sim.execute({"type": "momo.assign", "momo": 1, "building": bs.ids()[1]})
			sim.advance_ms(20000)
			sim.execute({"type": "building.tap", "id": f})
			sim.advance_ms(1000)
		"land":
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				bs.place_instant("farm", c)
			eco.earn(60, "capture")
		"shop":
			var inv: InventorySystem = sim.system(&"inventory")
			inv.add("wood", 12, "capture")
			inv.add("notes", 3, "capture")
			bs.place_instant("farm", Vector2i(0, 0))
			bs.place_instant("farm", Vector2i(1, 0))
			sim.execute({"type": "momo.assign", "momo": 1, "building": bs.ids()[0]})
			eco.earn(80, "capture")
		_:
			bs.place_ready("farm", Vector2i(0, 0), "harvest")
			(main.get("tutorial") as Tutorial).start()
