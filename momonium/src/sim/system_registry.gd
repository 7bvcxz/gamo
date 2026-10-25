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
		# Before the economy: at dawn the island feeds its pubs from the
		# night's stock first, then sells what is left.
		CommunitySystem.new(),
		EconomySystem.new(),
		InventorySystem.new(),
		ProgressionSystem.new(),
		MomoSystem.new(),
		JobSystem.new(),
		MailSystem.new(),
		ResearchSystem.new(),
		PowerSystem.new(),
		ManagerSystem.new(),
		AnalyticsSystem.new(),
		PrestigeSystem.new(),
		TierSystem.new(),
		SpecialSystem.new(),
		JourneySystem.new(),
	]
	return list
