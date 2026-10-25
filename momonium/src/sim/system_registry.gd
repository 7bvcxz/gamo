class_name SystemRegistry
extends RefCounted

## The systems a game runs, in the order they hear about each new day.
## Order matters and is part of the rules: a day's sales must see the stock the
## previous day produced before anything else runs.


static func create_default() -> Array[SimSystem]:
	var list: Array[SimSystem] = [
		WorldSystem.new(),
		LandSystem.new(),
		BuildingSystem.new(),
		EconomySystem.new(),
		ProgressionSystem.new(),
	]
	return list
