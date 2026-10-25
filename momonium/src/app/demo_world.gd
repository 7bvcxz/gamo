class_name DemoWorld
extends RefCounted

## A clearly labelled demo island for trying what a new island reaches only
## after hours: every industry built and staffed, research part-way through
## each branch, materials and ores in the store, letters in the mailbox. It
## is built by playing the real rules forward (commands and time), not by
## writing numbers into the world, and it is never saved over the player's
## island.

static func build(data: GameData = null) -> Simulation:
	var sim := Simulation.new_game(data)
	var economy: EconomySystem = sim.system(&"economy")
	var bs: BuildingSystem = sim.system(&"buildings")
	var prog: ProgressionSystem = sim.system(&"progression")
	var research: ResearchSystem = sim.system(&"research")
	economy.earn(5000, "demo")
	prog.add_exp(900, "demo")
	for cell: Array in [[2, 0], [2, 1], [-1, 0], [-1, 1], [0, 2], [1, 2]]:
		sim.execute({"type": "land.buy", "cell": cell})
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var farm2 := bs.place_instant("farm", Vector2i(2, 0))
	var lab := bs.place_instant("research", Vector2i(0, 1))
	var lumber := bs.place_instant("lumberyard", Vector2i(-1, 0))
	var mine := bs.place_instant("mine", Vector2i(2, 1))
	var smelter := bs.place_instant("smelter", Vector2i(1, 1))
	# Power: one of each kind -- sun, wind, a stoked boiler, a wheel on the shore.
	bs.place_instant("solar_panel", Vector2i(1, 2))
	bs.place_instant("wind_turbine", Vector2i(-1, 1))
	var steam := bs.place_instant("steam_engine", Vector2i(0, 0))
	bs.place_instant("water_wheel", Vector2i(0, 2))
	for i in 6:
		sim.execute({"type": "momo.hire"})
	var jobs := [farm, farm2, lab, lumber, mine, smelter, steam]
	for i in jobs.size():
		sim.execute({"type": "momo.assign", "momo": i + 1, "building": jobs[i]})
	prog.add_mastery("farm", 700)
	prog.add_mastery("mine", 700)
	prog.add_mastery("lumberyard", 350)
	prog.add_mastery("research", 300)
	prog.add_mastery("smelter", 300)
	for id: String in ["farm_expansion", "watering_efficiency", "harvest_boost", "watering_can", "seed_selection", "pickaxes", "copper_prospecting", "iron_prospecting", "sharp_axes", "bellows", "bloomery", "photovoltaics", "wind_power", "steam_power", "hydropower", "electric_drill", "lab_lighting"]:
		research.completed[id] = 0
	sim.bus.emit(&"research_completed", {"id": "sharp_axes"})
	(sim.system(&"inventory") as InventorySystem).add("notes", 25, "demo")
	(sim.system(&"inventory") as InventorySystem).add("wood", 30, "demo")
	# Let the staffed island run a while so its stores, mail and ledger are real:
	# the mine's ore and the lumberyard's wood feed the smelter by the rules.
	sim.advance_ms(30000 * 60)
	return sim
