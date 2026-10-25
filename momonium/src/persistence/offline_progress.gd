class_name OfflineProgress
extends RefCounted

## What happens while the game is closed.
##
## Nothing new: the simulation advances by the time away, which runs exactly
## what it would have run with the game open and nobody touching it -- Momo
## at their assigned work, drip lines, cooldowns ending, research finishing,
## the daily sale -- with every rule intact (a full store stops a harvest, a
## wait is a wait). Nothing is tapped on the player's behalf: work nobody is
## assigned to stays undone.
##
## Two ceilings, both deterministic: time away counts up to
## `balance.offline.max_hours`, and the catch-up handles at most
## `balance.offline.max_events` events, stopping the clock at the last one
## handled. Beyond either, the island simply did not do more -- nothing is
## estimated or granted.

static func catch_up(sim: Simulation, away_ms: int) -> Dictionary:
	var max_ms := int(sim.data.get_float("balance", "offline.max_hours", 8.0) * 3600000.0)
	var budget := sim.data.get_int("balance", "offline.max_events", 200000)
	var start := sim.now_ms()
	var wanted := clampi(away_ms, 0, max_ms)
	var before := counters(sim)
	var journey: JourneySystem = sim.system(&"journey")
	if journey != null:
		journey.begin_away()
	var reached := sim.advance_to_budget(start + wanted, budget)
	if journey != null:
		journey.end_away(maxi(away_ms, 0), reached - start)
	var after := counters(sim)
	var research_done: Array = []
	for id: String in after["research"]:
		if not (before["research"] as Array).has(id):
			research_done.append(id)
	return {
		"away_ms": maxi(away_ms, 0), "clock_went_back": away_ms < 0,
		"counted_ms": reached - start, "capped_time": away_ms > max_ms, "capped_events": reached < start + wanted,
		"crops": int(after["crops"]) - int(before["crops"]), "income": int(after["income"]) - int(before["income"]),
		"jobs": int(after["jobs"]) - int(before["jobs"]), "letters": int(after["letters"]) - int(before["letters"]),
		"research": research_done, "days": int(after["day"]) - int(before["day"]),
	}


static func counters(sim: Simulation) -> Dictionary:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var jobs := 0
	for id: int in buildings.ids():
		jobs += int(buildings.get_building(id).get("completed", 0))
	var economy: EconomySystem = sim.system(&"economy")
	var mail: MailSystem = sim.system(&"mail")
	var research: ResearchSystem = sim.system(&"research")
	return {
		"crops": int((sim.system(&"inventory") as InventorySystem).produced.get("crop", 0)),
		"income": economy.lifetime_income(), "jobs": jobs, "day": sim.clock.day_number(),
		"letters": mail.letters.size() if mail != null else 0,
		"research": research.completed.keys() if research != null else [],
	}


## Whether the player should hear about it: away a while and something happened.
static func worth_telling(report: Dictionary, min_seconds: float) -> bool:
	return int(report.get("counted_ms", 0)) >= int(min_seconds * 1000.0) and \
		(int(report["jobs"]) > 0 or int(report["income"]) > 0 or not (report["research"] as Array).is_empty() or int(report["letters"]) > 0)
