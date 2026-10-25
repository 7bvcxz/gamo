class_name DemoWorld
extends RefCounted

## A clearly labelled demo island for trying what a new island reaches only
## after hours: every industry built and staffed, research part-way through
## each branch, materials and ores in the store, letters in the mailbox. It
## is built by playing the real rules forward (commands and time), not by
## writing numbers into the world, and it is never saved over the player's
## island.

## Which demo an address asks for (`?demo=` on the page): "full", "large",
## or "" for none. Anything else is ignored -- the player's island opens.
static func kind_from(value: String) -> String:
	match value.strip_edges().to_lower():
		"full", "demo", "1", "true":
			return "full"
		"large", "big", "stress":
			return "large"
	return ""


static func build(data: GameData = null) -> Simulation:
	var sim := Simulation.new_game(data)
	var economy: EconomySystem = sim.system(&"economy")
	var bs: BuildingSystem = sim.system(&"buildings")
	var prog: ProgressionSystem = sim.system(&"progression")
	var research: ResearchSystem = sim.system(&"research")
	economy.earn(40000, "demo")
	prog.add_exp(4000, "demo")
	for cell: Array in [[2, 0], [2, 1], [-1, 0], [-1, 1], [0, 2], [1, 2], [3, 0], [3, 1], [2, 2], [3, 2], [-1, 2], [4, 0], [4, 1], [4, 2], [2, 3]]:
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
	# An office with a manager, and a second mine the manager may staff.
	var office := bs.place_instant("office", Vector2i(3, 0))
	bs.place_instant("mine", Vector2i(3, 1))
	# Momo life: two villas, an apartment, a park and a pub (the hall needs power).
	bs.place_instant("villa", Vector2i(2, 2))
	bs.place_instant("apartment", Vector2i(3, 2))
	bs.place_instant("park", Vector2i(-1, 2))
	bs.place_instant("pub", Vector2i(4, 0))
	bs.place_instant("community_center", Vector2i(4, 1))
	# Advanced industry: a game studio and a car factory, each with its crew of two.
	var studio := bs.place_instant("game_studio", Vector2i(4, 2))
	var cars := bs.place_instant("car_factory", Vector2i(2, 3))
	for i in 11:
		sim.execute({"type": "momo.hire"})
	var jobs := [farm, farm2, lab, lumber, mine, smelter, steam, office, studio, studio, cars, cars]
	for i in jobs.size():
		sim.execute({"type": "momo.assign", "momo": i + 1, "building": jobs[i]})
	# Industry workers are left to the manager (the farms and lab stay put).
	for i in range(3, jobs.size() - 1):
		sim.execute({"type": "momo.pin", "momo": i + 1, "pinned": false})
	prog.add_mastery("farm", 700)
	prog.add_mastery("mine", 700)
	prog.add_mastery("lumberyard", 350)
	prog.add_mastery("research", 300)
	prog.add_mastery("smelter", 300)
	for id: String in ["farm_expansion", "watering_efficiency", "harvest_boost", "watering_can", "seed_selection", "pickaxes", "copper_prospecting", "iron_prospecting", "sharp_axes", "bellows", "bloomery", "photovoltaics", "wind_power", "steam_power", "hydropower", "electric_drill", "lab_lighting", "momo_training", "management", "masonry", "civic_planning", "electric_furnace", "software", "automotive"]:
		research.completed[id] = 0
	sim.bus.emit(&"research_completed", {"id": "sharp_axes"})
	(sim.system(&"inventory") as InventorySystem).add("notes", 25, "demo")
	(sim.system(&"inventory") as InventorySystem).add("wood", 30, "demo")
	# Ingots for the car line to start on (the smelter makes more as it runs).
	(sim.system(&"inventory") as InventorySystem).add("iron_ingot", 12, "demo")
	(sim.system(&"inventory") as InventorySystem).add("copper_ingot", 4, "demo")
	# Let the staffed island run a while so its stores, mail and ledger are real:
	# the mine's ore and the lumberyard's wood feed the smelter by the rules.
	sim.advance_ms(30000 * 60)
	return sim
