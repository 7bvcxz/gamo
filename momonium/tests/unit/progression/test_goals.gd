extends "res://tests/framework/test_case.gd"

## Step 72: one distant goal at a time. A Village works toward City, then
## Nation; then the civilization milestones -- a Golden Age, then a whole
## Civilization -- measured from the game, reached for good, announced once,
## each replaced by the next. Saving, loading and selling the island keep what
## was reached; the island's own tiers start again. The goal never changes
## the work.

var sim: Simulation
var goals: GoalSystem
var tiers: TierSystem
var rs: ResearchSystem


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	goals = sim.system(&"goals")
	tiers = sim.system(&"tiers")
	rs = sim.system(&"research")


func _nation(s: Simulation) -> void:
	var t: TierSystem = s.system(&"tiers")
	t.tier = 2
	s.bus.emit(&"tier_promoted", {"tier": 2, "name": "nation", "special_slots": t.special_slots()})


func _momos(s: Simulation, n: int) -> void:
	var m: MomoSystem = s.system(&"momo")
	while m.ids().size() < n:
		m.add_momo(Vector2(0.5, 0.5))
	s.bus.emit(&"momo_hired", {"id": m.ids()[-1]})


## The eighth-tier topic of each of the first `n` disciplines, researched.
func _capstones(s: Simulation, n: int) -> void:
	var r: ResearchSystem = s.system(&"research")
	var done := 0
	for ind: String in r.industries():
		if done >= n:
			break
		for node: Dictionary in r.nodes(ind):
			if r.tier_of(String(node["id"])) >= 8:
				r.completed[String(node["id"])] = s.now_ms()
				r.unlocked[String(node["id"])] = true
				done += 1
				break
	s.bus.emit(&"research_completed", {"id": ""})


func _current_count(steps: Array[Dictionary]) -> int:
	return steps.filter(func(st: Dictionary) -> bool: return st["state"] == "current").size()


func test_one_goal_at_a_time_from_village() -> void:
	var cur := goals.current()
	assert_eq([cur["id"], cur["kind"]], ["city", "tier"], "a new island works toward City")
	assert_eq(cur["progress"], tiers.progress(), "with the tier's own milestones")
	var steps := goals.steps()
	assert_eq(steps.map(func(st: Dictionary) -> String: return st["id"]), ["village", "city", "nation", "golden_age", "civilization"], "the road, in order")
	assert_eq(steps.map(func(st: Dictionary) -> String: return st["state"]), ["done", "current", "ahead", "ahead", "ahead"], "where the island is")
	assert_eq(_current_count(steps), 1, "never two goals")


func test_after_the_nation_the_golden_age_with_real_progress() -> void:
	_nation(sim)
	var cur := goals.current()
	assert_eq([cur["id"], cur["kind"]], ["golden_age", "civ"], "a Nation looks toward a Golden Age")
	var by := {}
	for p: Dictionary in cur["progress"]:
		by[p["key"]] = p
	assert_true(bool(by["tier"]["met"]), "it is a Nation")
	assert_eq(int(by["momos"]["have"]), 1, "Momo counted from the island (1 of 10)")
	assert_eq(int(by["eighth_tiers"]["have"]), 0, "no eighth tier yet")
	_capstones(sim, 1)
	assert_eq(int(goals.progress_of(goals.ladder()[0])[2]["have"]), 1, "one eighth tier researched: 1 of 2")
	assert_false(goals.reached.has("golden_age"), "not reached while partial")
	assert_eq(_current_count(goals.steps()), 1, "still one goal")


func test_reaching_is_announced_once_and_the_next_takes_its_place() -> void:
	var heard: Array[String] = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"goal_reached":
			heard.append(String(p["id"])))
	_nation(sim)
	_momos(sim, 10)
	_capstones(sim, 2)
	assert_eq(heard, ["golden_age"] as Array[String], "the Golden Age, once")
	assert_true(goals.reached.has("golden_age"), "reached for good")
	assert_eq(goals.current()["id"], "civilization", "the next distant goal")
	goals.check()
	sim.advance_ms(sim.clock.day_ms)
	assert_eq(heard.size(), 1, "never announced twice")


func test_a_whole_civilization_then_nothing_more_to_chase() -> void:
	_nation(sim)
	_momos(sim, 10)
	_capstones(sim, 6)
	(sim.system(&"prestige") as PrestigeSystem).sales = 3
	goals.check()
	assert_true(goals.reached.has("golden_age") and goals.reached.has("civilization"), "both, in order")
	assert_eq(goals.current()["kind"], "done", "every goal reached")
	assert_eq(_current_count(goals.steps()), 0, "nothing left as current")


func test_save_and_load_keep_the_goals() -> void:
	_nation(sim)
	_momos(sim, 10)
	_capstones(sim, 2)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var g2: GoalSystem = copy.system(&"goals")
	assert_true(g2.reached.has("golden_age"), "the Golden Age stays reached")
	assert_eq(g2.current()["id"], "civilization", "and the goal is still the next one")
	# A save from before Step 72 has no goals: its tier counts as reached.
	var old := sim.save_state()
	(old["systems"] as Dictionary).erase("goals")
	var copy2 := Simulation.from_save(JSON.parse_string(JSON.stringify(old)))
	var g3: GoalSystem = copy2.system(&"goals")
	assert_true(g3.reached.has("city") and g3.reached.has("nation"), "an old Nation's tiers are on the road")
	assert_true(g3.reached.has("golden_age"), "and an old save already meeting the Golden Age reaches it on load")


func test_prestige_keeps_the_milestones_and_the_island_starts_again() -> void:
	_nation(sim)
	_momos(sim, 10)
	_capstones(sim, 2)
	(sim.system(&"progression") as ProgressionSystem).add_exp(100000, "test")
	(sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	var r := PrestigeSystem.sell(sim)
	assert_true(r["ok"], "sold (%s)" % r.get("reason", ""))
	if not r["ok"]:
		return
	var next: Simulation = r["sim"]
	var g2: GoalSystem = next.system(&"goals")
	assert_true(g2.reached.has("golden_age"), "the Golden Age is kept")
	var cur := g2.current()
	assert_eq([cur["id"], cur["kind"]], ["city", "tier"], "the new island is a Village again: City first")
	assert_eq(g2.steps().map(func(st: Dictionary) -> String: return st["state"]), ["done", "current", "ahead", "done", "ahead"], "the road shows the Golden Age reached")
	_nation(next)
	assert_eq(g2.current()["id"], "civilization", "at Nation again: the Civilization, not the Golden Age twice")
	assert_eq((next.system(&"prestige") as PrestigeSystem).sales, 1, "and the island sold counts toward it")


func test_the_goal_never_changes_the_work() -> void:
	# The same ten minutes of play with the goal system and without it.
	var results: Array = []
	for with_goals: bool in [true, false]:
		var systems := SystemRegistry.create_default()
		if not with_goals:
			systems = systems.filter(func(s: SimSystem) -> bool: return not s is GoalSystem)
		var typed: Array[SimSystem] = []
		typed.assign(systems)
		var s := Simulation.new_game(null, typed)
		with_starter_momo(s)
		var bs: BuildingSystem = s.system(&"buildings")
		var farm := bs.place_instant("farm", Vector2i(1, 0))
		s.execute({"type": "momo.assign", "momo": 1, "building": farm})
		s.advance_ms(600000)
		var eco: EconomySystem = s.system(&"economy")
		results.append([eco.money, int(bs.get_building(farm)["completed"])])
	assert_eq(results[0], results[1], "same money and work (%s)" % [results])
	assert_eq(goals.handled_commands().size(), 0, "it takes no commands")
	assert_eq(goals.handled_events().size(), 0, "and schedules nothing")


func test_the_ladder_data_is_checked() -> void:
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	bal["goals"]["ladder"].append({"id": "golden_age", "needs": {"stars": 3}})
	var text := "\n".join(GameData.from_tables({"balance": bal}).errors)
	assert_true(text.contains("unique ids"), "a repeated id is refused")
	assert_true(text.contains("unknown or empty need"), "an unknown need is refused")
