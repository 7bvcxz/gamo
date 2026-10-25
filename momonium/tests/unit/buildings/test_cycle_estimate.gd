extends "res://tests/framework/test_case.gd"

## What the panels show about a cycle comes from the same rules the
## simulation runs: a measured unattended cycle equals the estimate.

func test_estimate_matches_the_rules() -> void:
	var sim := Simulation.new_game()
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	var b := buildings.get_building(farm)
	var you := buildings.cycle_estimate(b, 1.0)
	assert_eq(you["work_seconds"], 25.0, "five stages of 5 s")
	assert_eq(you["wait_seconds"], 90.0, "three 30 s waits")
	assert_eq(you["yield"], {"crop": 1.0}, "one crop")
	assert_near(you["per_day"]["crop"], 30.0 / 115.0, 0.0001, "per 30 s day")
	var momo := buildings.cycle_estimate(b, 4.0)
	assert_eq(momo["cycle_seconds"], 190.0, "4 x the work, the same waits")


func test_a_momo_cycle_takes_what_the_estimate_says() -> void:
	var sim := Simulation.new_game()
	var buildings: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	var starts: Array = []
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_started" and p["stage"] == "sow":
			starts.append(clock.now_ms))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(400000)
	assert_true(starts.size() >= 2, "two cycles began")
	var est := buildings.cycle_estimate(buildings.get_building(farm), 4.0)
	assert_eq(starts[1] - starts[0], int(est["cycle_seconds"] * 1000.0), "measured cycle = estimate")
	assert_eq(momos.ids().size(), 1, "")


func test_lifetime_ledgers_and_production_survive_a_save() -> void:
	var sim := Simulation.new_game()
	var eco: EconomySystem = sim.system(&"economy")
	var inv: InventorySystem = sim.system(&"inventory")
	eco.earn(50, "sale")
	eco.spend(20, "land")
	inv.add("crop", 4, "yield:farm")
	inv.add("crop", 2, "gift")
	assert_eq(inv.produced, {"crop": 4}, "only yields count as produced")
	assert_eq(eco.lifetime_income(), 50 + 0, "income")
	assert_eq(eco.lifetime_expense(), 20, "spending")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_eq((copy.system(&"economy") as EconomySystem).lifetime, eco.lifetime, "lifetime ledger saved")
	assert_eq((copy.system(&"inventory") as InventorySystem).produced, {"crop": 4}, "production saved")


func test_old_saves_without_the_new_fields_load() -> void:
	var sim := Simulation.new_game()
	var state := sim.save_state()
	(state["systems"]["economy"] as Dictionary).erase("lifetime")
	(state["systems"]["inventory"] as Dictionary).erase("produced")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	assert_eq((copy.system(&"economy") as EconomySystem).lifetime, {}, "empty lifetime")
	assert_eq((copy.system(&"inventory") as InventorySystem).produced, {}, "empty production")
