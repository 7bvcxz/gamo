extends "res://tests/framework/test_case.gd"

## Automation is never a penalty (Step 50): a Momo works a stage as fast as a
## person, so a farm left to a Momo earns as much as one tapped nonstop, and
## far more than a player who has other things to do; a Momo starts on new
## work by itself once it is at work; and time away earns exactly what the
## same time with the game open would have -- no more, no less.


func _farm_cycle_s(sim: Simulation) -> float:
	var total := 0.0
	for st: Dictionary in sim.data.building_type("farm")["cycle"]["stages"]:
		total += float(st["seconds"]) * work_scale(sim) + float(st.get("cooldown", 0.0))
	return total


func test_a_momo_is_as_quick_as_a_person() -> void:
	var sim := with_starter_momo(Simulation.new_game())
	assert_true(sim.data.get_float("balance", "momo.work_time_multiplier", 4.0) <= 1.0, "a Momo's stage takes no longer than a person's")
	var bs: BuildingSystem = sim.system(&"buildings")
	var eco: EconomySystem = sim.system(&"economy")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(5000)
	var start := int(eco.lifetime.get("sale", 0))
	sim.advance_ms(60000)
	var per_minute := int(eco.lifetime.get("sale", 0)) - start
	var by_hand := int(floor(60.0 / _farm_cycle_s(sim))) * eco.unit_price("crop")
	assert_true(per_minute >= by_hand, "a Momo-run farm earns $%d a minute, a nonstop pair of hands $%d" % [per_minute, by_hand])


func test_automation_beats_a_busy_player() -> void:
	# The same farm for ten minutes: a player who taps it every ten seconds
	# (as busy as the blind playtesters were), or its Momo.
	var hands := with_starter_momo(Simulation.new_game())
	var hb: BuildingSystem = hands.system(&"buildings")
	var f1 := hb.place_instant("farm", Vector2i(1, 0))
	for i in 60:
		hands.execute({"type": "building.tap", "id": f1})
		hands.advance_ms(10000)
	var momo := with_starter_momo(Simulation.new_game())
	var f2 := (momo.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	momo.execute({"type": "momo.assign", "momo": 1, "building": f2})
	momo.advance_ms(600000)
	var by_hand := int((hands.system(&"economy") as EconomySystem).lifetime.get("sale", 0))
	var by_momo := int((momo.system(&"economy") as EconomySystem).lifetime.get("sale", 0))
	assert_true(by_hand > 0, "the player earns something ($%d)" % by_hand)
	# Step 69: a stage is 6.25 s of work now, so a hand on a ten-second beat
	# nearly keeps up with one farm; the Momo's lead fell from over 3x to about
	# 1.6x (design/INCREMENTAL_BALANCE_REPORT.md 'Step 69'). It still earns
	# clearly more -- and it never stops.
	assert_true(by_momo * 10 >= 15 * by_hand, "the Momo earns at least one and a half times as much ($%d against $%d)" % [by_momo, by_hand])


func test_a_momo_at_work_takes_new_buildings_by_itself() -> void:
	var sim := with_starter_momo(Simulation.new_game())
	var bs: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	var first := bs.place_instant("farm", Vector2i(0, 0))
	var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})
	sim.advance_ms(build_ms(sim, "farm"))
	assert_true(momos.watchers_of(int(r["id"])).is_empty(), "a Momo nobody put to work stays the player's to place")
	sim.execute({"type": "momo.assign", "momo": 1, "building": first})
	var r2 := sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 1]})
	sim.advance_ms(build_ms(sim, "farm"))
	assert_eq(momos.watchers_of(int(r2["id"])), [1] as Array[int], "once at work, it takes the new farm into its rounds")
	sim.advance_ms(30000)
	assert_true(int(bs.get_building(int(r2["id"]))["completed"]) > 0, "and works it")
	var hire := sim.execute({"type": "momo.hire"})
	assert_true(hire["ok"], "a hire")
	sim.advance_ms(20000)
	assert_true(momos.watched(int(hire["id"])).is_empty(), "Step 53: the newcomer waits to be placed -- it takes nothing by itself")
	sim.execute({"type": "momo.assign", "momo": int(hire["id"]), "building": int(r["id"])})
	assert_eq(momos.watchers_of(int(r["id"])), [int(hire["id"])] as Array[int], "the player puts it on the farm nobody looked after")


func test_time_away_earns_what_the_same_time_open_would() -> void:
	var states: Array = []
	for away: bool in [false, true]:
		var sim := with_starter_momo(Simulation.new_game())
		var bs: BuildingSystem = sim.system(&"buildings")
		(sim.system(&"economy") as EconomySystem).earn(200, "test")
		sim.execute({"type": "momo.hire"})
		var a := bs.place_instant("farm", Vector2i(0, 0))
		var b := bs.place_instant("mine", Vector2i(1, 0))
		sim.execute({"type": "momo.assign", "momo": 1, "building": a})
		sim.execute({"type": "momo.assign", "momo": 2, "building": b})
		sim.advance_ms(30000)
		if away:
			OfflineProgress.catch_up(sim, 30 * 60000)
		else:
			sim.advance_ms(30 * 60000)
		var eco: EconomySystem = sim.system(&"economy")
		states.append([eco.money, eco.lifetime.duplicate(), bs.get_building(a)["completed"], bs.get_building(b)["completed"], (sim.system(&"inventory") as InventorySystem).items.duplicate()])
	assert_eq(states[1], states[0], "half an hour away: the same money, sales, work and store as half an hour open")
	assert_true(int(states[0][0]) > 200, "and it did earn")
