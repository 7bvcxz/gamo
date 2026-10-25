extends "res://tests/framework/test_case.gd"

## Advanced industry: a game studio that needs a crew, power and research
## notes and earns more as it gains releases (up to a cap); a car factory
## that turns ingots into cars on a powered line, sold each day; delivery
## vans built from those cars -- and money only ever from work and inputs.

var sim: Simulation
var bs: BuildingSystem
var inv: InventorySystem
var economy: EconomySystem
var research: ResearchSystem


func before_each() -> void:
	sim = Simulation.new_game()
	bs = sim.system(&"buildings")
	inv = sim.system(&"inventory")
	economy = sim.system(&"economy")
	research = sim.system(&"research")
	economy.earn(1000, "test")
	for i in 3:
		sim.execute({"type": "momo.hire"})


func _crew(id: int) -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": id})
	sim.execute({"type": "momo.assign", "momo": 2, "building": id})
	sim.advance_ms(5000)


func test_they_wait_for_research_and_level() -> void:
	var entry: Dictionary = bs.catalog().filter(func(e: Dictionary) -> bool: return e["type"] == "game_studio")[0]
	assert_eq([entry["level"], entry["research"]], [6, "software"], "the studio: Lv 6 and software")
	entry = bs.catalog().filter(func(e: Dictionary) -> bool: return e["type"] == "car_factory")[0]
	assert_eq([entry["level"], entry["research"]], [7, "automotive"], "the factory: Lv 7 and automotive")
	assert_eq(research.node("automotive")["requires"], ["electric_furnace"], "which needs electric furnaces first")


func test_a_studio_needs_its_crew_and_power() -> void:
	var studio := bs.place_instant("game_studio", Vector2i(1, 0))
	inv.add("notes", 10, "test")
	assert_eq(sim.execute({"type": "building.tap", "id": studio})["reason"], "err.no_power", "dark computers")
	bs.place_instant("water_wheel", Vector2i(0, 0))
	assert_eq(sim.execute({"type": "building.tap", "id": studio})["reason"], "err.needs_crew", "the player alone cannot make a game")
	assert_eq(bs.blocked(bs.get_building(studio)), {"crew": 2}, "it says two more Momo are needed")
	_crew(studio)
	var b := bs.get_building(studio)
	assert_eq(b["state"], BuildingSystem.WORKING, "with a crew and power it starts by itself")
	assert_eq(inv.count("notes"), 7, "designing takes three research notes")


func test_releases_pay_more_with_experience_up_to_a_cap() -> void:
	var studio := bs.place_instant("game_studio", Vector2i(1, 0))
	var b := bs.get_building(studio)
	var release: Dictionary = bs.stages(b)[2]
	assert_eq(bs.revenue_of(b, release), 150, "a first game: $150")
	b["releases"] = 5
	assert_eq(bs.revenue_of(b, release), 210, "after five: +8% each, $210")
	b["releases"] = 50
	assert_eq(bs.revenue_of(b, release), 270, "never more than 1.8x: $270")
	research.completed["delivery_vans"] = 0
	assert_eq(bs.revenue_of(b, release), 297, "better market access: x1.1")


func test_a_whole_game_by_the_crew() -> void:
	bs.place_instant("water_wheel", Vector2i(0, 0))
	var studio := bs.place_instant("game_studio", Vector2i(1, 0))
	inv.add("notes", 3, "test")
	var money := economy.money
	var paid := [0]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"released":
			paid[0] += int(p["money"]))
	_crew(studio)
	sim.advance_ms(30000 * 20)
	assert_eq(paid[0], 150, "one game released, $150 (only three notes: one game)")
	assert_eq(economy.money - money, 150 + 0, "and that is all the money that came in")
	assert_eq(int(bs.get_building(studio)["releases"]), 1, "one release behind it")
	assert_eq(bs.blocked(bs.get_building(studio)), {"missing": {"notes": 3}}, "now it waits for ideas")


func test_cars_from_ingots_sold_each_day() -> void:
	bs.place_instant("water_wheel", Vector2i(0, 0))
	bs.place_instant("water_wheel", Vector2i(0, 1))
	var plant := bs.place_instant("car_factory", Vector2i(1, 0))
	inv.add("iron_ingot", 3, "test")
	inv.add("copper_ingot", 1, "test")
	_crew(plant)
	assert_eq([inv.count("iron_ingot"), inv.count("copper_ingot")], [0, 0], "the line takes a frame's worth of ingots")
	var sold := [0]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"sold":
			sold[0] += int((p["items"] as Dictionary).get("car", 0)))
	sim.advance_ms(30000 * 8)
	assert_eq(sold[0], 1, "one car built and sold at the day's sale")
	assert_eq(inv.count("car"), 0, "none left in the store")


func test_delivery_vans_speed_momo_and_sales() -> void:
	inv.add("crop", 10, "test")
	research.completed["delivery_vans"] = 0
	var money := economy.money
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	assert_eq(economy.money - money, 50, "crops sell at 5 x 1.1 = 5 (whole dollars, rounded down)")
	var momos: MomoSystem = sim.system(&"momo")
	var t0 := sim.now_ms()
	sim.execute({"type": "momo.move", "momo": 1, "pos": [0.1, 0.1]})
	var farm := bs.place_instant("farm", Vector2i(1, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var with_vans := int(momos.get_momo(1)["end"]) - sim.now_ms()
	research.completed.erase("delivery_vans")
	sim.execute({"type": "momo.move", "momo": 1, "pos": [0.1, 0.1]})
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var on_foot := int(momos.get_momo(1)["end"]) - sim.now_ms()
	assert_near(float(on_foot) / float(with_vans), 1.5, 0.02, "the same walk takes 1.5x longer on foot")
	assert_true(t0 >= 0, "")


func test_no_money_from_nothing() -> void:
	bs.place_instant("water_wheel", Vector2i(0, 0))
	var studio := bs.place_instant("game_studio", Vector2i(1, 0))
	var lab := bs.place_instant("research", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 3, "building": lab})
	_crew(studio)
	var notes_in := [0]
	var notes_used := [0]
	var earned := [0]
	var releases := [0]
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"inventory_changed" and p["item"] == "notes":
			if int(p["delta"]) > 0:
				notes_in[0] += int(p["delta"])
			else:
				notes_used[0] -= int(p["delta"])
		elif t == &"money_changed" and int(p.get("delta", 0)) > 0:
			earned[0] += int(p["delta"])
		elif t == &"released":
			releases[0] += 1)
	sim.advance_ms(30000 * 60)
	assert_true(releases[0] >= 1, "games came out (%d)" % releases[0])
	assert_eq(notes_used[0], 3 * releases[0] + 3 * int(bs.get_building(studio)["stage"] != 0), "three notes per game, no game without them")
	assert_true(notes_used[0] <= notes_in[0], "and never more notes than the lab wrote")
	var max_pay := 0
	for r in releases[0]:
		max_pay += int(floor(150.0 * minf(1.0 + 0.08 * r, 1.8)))
	assert_eq(earned[0], max_pay, "money came only from releases, exactly their revenue")
