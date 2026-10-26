extends "res://tests/framework/test_case.gd"

## Momo grow skilled at what they do: experience per kind of building, levels
## that shorten their work there, training research on top, and a history of
## where they have worked -- all saved.

var sim: Simulation
var momos: MomoSystem
var bs: BuildingSystem
var farm := 0


func before_each() -> void:
	sim = Simulation.new_game()
	momos = sim.system(&"momo")
	bs = sim.system(&"buildings")
	farm = bs.place_instant("farm", Vector2i(1, 0))


## A Momo's base multiple of the player's time (balance data).
func _base() -> float:
	return sim.data.get_float("balance", "momo.work_time_multiplier", 4.0)


func test_experience_is_per_momo_and_per_kind() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000 * 12)
	var exp: Dictionary = momos.get_momo(1)["experience"]
	assert_true(int(exp.get("farm", 0)) >= 5, "farm stages counted (%s)" % [exp])
	assert_eq(exp.keys(), ["farm"], "only where it worked")
	assert_eq(int(exp["farm"]), int(bs.get_building(farm)["completed"]), "every stage it did, none it did not")


func test_levels_shorten_the_work() -> void:
	assert_eq(momos.proficiency(1, "farm"), 0, "a beginner")
	assert_eq(momos.work_multiplier(1, "farm"), _base(), "takes the Momo multiple of the player's time")
	momos.get_momo(1)["experience"]["farm"] = 10
	assert_eq(momos.proficiency(1, "farm"), 1, "10 stages: level 1")
	assert_near(momos.work_multiplier(1, "farm"), _base() * 0.92, 0.0001, "a little faster")
	momos.get_momo(1)["experience"]["farm"] = 150
	assert_eq(momos.proficiency(1, "farm"), 4, "150: level 4")
	assert_near(momos.work_multiplier(1, "farm"), _base() * 0.72, 0.0001, "much faster")
	assert_eq(momos.proficiency(1, "mine"), 0, "but still a beginner at the mine")


func test_the_job_system_uses_the_momos_own_speed() -> void:
	momos.get_momo(1)["experience"]["farm"] = 70
	var spans: Array = []
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and p["stage"] == "sow":
			spans.append(int(p["ends_ms"]) - clock.now_ms))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000)
	var sow := float(sim.data.building_type("farm")["cycle"]["stages"][0]["seconds"])
	assert_eq(spans[0], int(round(sow * _base() * 0.78 * 1000.0)), "sowing takes its time x the Momo multiple x 0.78 for a level-3 farmer (70 stages)")


func test_skill_up_is_announced() -> void:
	momos.get_momo(1)["experience"]["farm"] = 9
	var ups: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"momo_skilled":
			ups.append([p["id"], p["type"], p["level"]]))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000)
	assert_eq(ups, [[1, "farm", 1]], "the 10th stage brings level 1")


func test_training_research_speeds_every_momo() -> void:
	(sim.system(&"research") as ResearchSystem).completed["momo_training"] = 0
	assert_near(momos.work_multiplier(1, "farm"), _base() * 0.9, 0.0001, "Lv 1: x0.9 for all")
	assert_near(momos.work_multiplier(1, "mine"), _base() * 0.9, 0.0001, "at every kind of building")
	(sim.system(&"research") as ResearchSystem).bought["momo_training"] = 2
	assert_near(momos.work_multiplier(1, "farm"), _base() * 0.8, 0.0001, "Lv 2: x0.8, as its data says")


func test_history_and_pinning() -> void:
	(sim.system(&"economy") as EconomySystem).earn(200, "test")
	var mine := bs.place_instant("mine", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	assert_true(momos.get_momo(1)["pinned"], "placed by the player: pinned")
	sim.advance_ms(5000)
	sim.execute({"type": "momo.assign", "momo": 1, "building": mine})
	sim.advance_ms(5000)
	sim.execute({"type": "momo.unassign", "momo": 1})
	var hist: Array = momos.get_momo(1)["history"]
	assert_eq(hist.map(func(h: Dictionary) -> String: return h["type"]), ["farm", "mine"], "where it worked, in order")
	assert_eq([int(hist[0]["from"]), int(hist[0]["to"])], [0, 5000], "with when")
	assert_eq(int(hist[1]["to"]), 10000, "closed when released")
	assert_false(momos.get_momo(1)["pinned"], "a free Momo is not pinned")
	assert_true(sim.execute({"type": "momo.pin", "momo": 1, "pinned": true})["ok"], "pin by command")
	for i in 20:
		sim.execute({"type": "momo.assign", "momo": 1, "building": farm if i % 2 == 0 else mine})
	assert_eq((momos.get_momo(1)["history"] as Array).size(), 12, "only the last 12 places are kept")


func test_skill_and_history_survive_a_save() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(30000 * 6)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var m2 := (copy.system(&"momo") as MomoSystem).get_momo(1)
	assert_eq(m2["experience"], momos.get_momo(1)["experience"], "experience")
	assert_eq(JSON.stringify(m2["history"]), JSON.stringify(momos.get_momo(1)["history"]), "history")
	assert_eq(typeof(m2["experience"]["farm"]), TYPE_INT, "as whole numbers")
	var state := sim.save_state()
	for m: Dictionary in state["systems"]["momo"]["momos"]:
		m.erase("experience")
		m.erase("history")
		m.erase("pinned")
	var old := (Simulation.from_save(JSON.parse_string(JSON.stringify(state))).system(&"momo") as MomoSystem).get_momo(1)
	assert_eq(old["experience"], {}, "an old save starts with no experience")
	assert_true(old["pinned"], "and a Momo already at work stays where the player put it")
