extends "res://tests/framework/test_case.gd"

## Step 57: a Momo's letter discovers its research the moment it arrives --
## read or not -- and nothing more: prerequisites, the lab, money and notes are
## asked as before, nothing is researched for free. A newly available topic is
## news (the Research button's dot) until the player is shown it; that is
## saved, carried over a Prestige, and seeded sensibly for an old save.

var sim: Simulation
var research: ResearchSystem
var mail: MailSystem
var buildings: BuildingSystem
var farm := 0


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	research = sim.system(&"research")
	mail = sim.system(&"mail")
	buildings = sim.system(&"buildings")
	farm = buildings.place_instant("farm", Vector2i(1, 0))


func _first_letter() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var waited := 0
	while mail.letters.is_empty() and waited < 300000:
		sim.advance_ms(500)
		waited += 500
	assert_eq(mail.letters.size(), 1, "the first letter came")


func test_an_unopened_letter_discovers_its_research() -> void:
	assert_eq(research.state_of("farm_expansion"), "locked", "before: waiting for a proposal")
	assert_eq(research.new_topics(), [] as Array[String], "nothing new")
	_first_letter()
	assert_eq(mail.letters[0]["read_ms"], -1, "the letter is unread")
	assert_eq(research.state_of("farm_expansion"), "available", "and its research is open all the same")
	assert_eq(research.new_topics(), ["farm_expansion"] as Array[String], "news: the Research button's dot")


func test_discovery_grants_nothing() -> void:
	_first_letter()
	assert_eq(research.level("farm_expansion"), 0, "not researched")
	assert_false(research.completed.has("farm_expansion"), "not completed")
	var check := research.can_start("farm_expansion")
	assert_false(check["ok"], "it still needs what research needs")
	assert_eq(check["reason"], "err.no_lab", "a lab first")
	buildings.place_instant("research", Vector2i(0, 1))
	assert_true(research.can_start("farm_expansion")["reason"] in ["err.not_enough_money", "err.not_enough_items"], "then its cost")


func test_prerequisites_still_hold() -> void:
	(sim.system(&"progression") as ProgressionSystem).add_mastery("farm", 100)
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	assert_true(mail.discovered_research().has("watering_efficiency"), "the watering letter came")
	assert_eq(research.state_of("watering_efficiency"), "locked", "but it comes after field expansion")
	assert_eq(research.missing("watering_efficiency"), [{"kind": "requires", "id": "farm_expansion"}] as Array[Dictionary], "only that is missing now")
	assert_false(research.new_topics().has("watering_efficiency"), "so it is not news yet")


func test_shown_once_then_not_news() -> void:
	_first_letter()
	assert_true(sim.execute({"type": "research.acknowledge", "ids": research.new_topics()})["ok"], "shown")
	assert_eq(research.new_topics(), [] as Array[String], "no longer news")
	# Saved and loaded: still seen.
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_eq((copy.system(&"research") as ResearchSystem).new_topics(), [] as Array[String], "the same after a load")
	assert_true((copy.system(&"research") as ResearchSystem).seen.has("farm_expansion"), "")


func test_several_discoveries_are_each_news_once() -> void:
	research.completed["farm_expansion"] = 0
	research.bought["farm_expansion"] = 1
	research.unlocked["farm_expansion"] = true
	var prog: ProgressionSystem = sim.system(&"progression")
	prog.add_mastery("farm", 100000)
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var waited := 0
	while not (mail.discovered_research().has("watering_efficiency") and mail.discovered_research().has("harvest_boost")) and waited < 1200000:
		sim.advance_ms(1000)
		waited += 1000
	var news := research.new_topics()
	assert_true(news.has("watering_efficiency") and news.has("harvest_boost"), "two letters, two new topics (%s)" % [news])
	sim.execute({"type": "research.acknowledge", "ids": news})
	assert_eq(research.new_topics(), [] as Array[String], "one look acknowledges them all")
	sim.execute({"type": "research.acknowledge", "ids": news})
	assert_eq(research.seen.size(), news.size(), "acknowledging twice adds nothing")


func test_a_topic_that_is_started_is_no_news() -> void:
	_first_letter()
	buildings.place_instant("research", Vector2i(0, 1))
	(sim.system(&"inventory") as InventorySystem).add("notes", 20, "test")
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	assert_true(sim.execute({"type": "research.start", "id": "farm_expansion"})["ok"], "started straight from the letter")
	assert_eq(research.new_topics(), [] as Array[String], "running is not news: no stale dot")


func test_offline_catch_up_discovers_and_keeps_the_news() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var state := sim.save_state()
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	copy.replaying = true
	copy.advance_ms(300000)
	copy.replaying = false
	var m2: MailSystem = copy.system(&"mail")
	var r2: ResearchSystem = copy.system(&"research")
	assert_true(m2.letters.size() >= 1, "letters came while away")
	assert_eq(r2.state_of("farm_expansion"), "available", "its research is open")
	assert_true(r2.new_topics().has("farm_expansion"), "and it is news on return (%s)" % [r2.new_topics()])


func test_seen_is_carried_over_a_prestige() -> void:
	_first_letter()
	sim.execute({"type": "research.acknowledge", "ids": ["farm_expansion"]})
	var carry := research.carry_over()
	var next := Simulation.new_game()
	var r2: ResearchSystem = next.system(&"research")
	r2.adopt(carry)
	assert_true(r2.seen.has("farm_expansion"), "a topic seen once is not news again")


func test_an_old_save_is_seeded_without_stale_or_lost_news() -> void:
	# Before Step 57: a letter accepted (claimed) and its topic researched
	# once; a second letter written but never accepted.
	_first_letter()
	var state := sim.save_state()
	var sys: Dictionary = state["systems"]
	(sys["research"] as Dictionary).erase("seen")
	(sys["mail"] as Dictionary)["letters"][0]["claimed_ms"] = 1000
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	var r2: ResearchSystem = copy.system(&"research")
	assert_eq(r2.new_topics(), [] as Array[String], "an accepted proposal was already on the list: no dot")
	(sys["mail"] as Dictionary)["letters"][0]["claimed_ms"] = -1
	copy = Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	r2 = copy.system(&"research")
	assert_eq(r2.new_topics(), ["farm_expansion"] as Array[String], "a proposal never accepted opens now: that is news")
