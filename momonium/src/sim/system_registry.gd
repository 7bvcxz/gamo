class_name SystemRegistry
extends RefCounted

## The systems a game runs, in the order they hear about each new day.
## Order matters and is part of the rules (the same order every run keeps
## every island deterministic).


static func create_default() -> Array[SimSystem]:
	var list: Array[SimSystem] = [
		WorldSystem.new(),
		LandSystem.new(),
		BuildingSystem.new(),
		# Before the economy: at dawn the pubs pay for their day's food,
		# booked in the day that is closing.
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
		# Step 72: last -- it only reads the others and announces a milestone.
		GoalSystem.new(),
	]
	return list
