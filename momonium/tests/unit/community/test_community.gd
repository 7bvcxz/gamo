extends "res://tests/framework/test_case.gd"

## Momo life: homes filled in order up to their capacity, rest for the
## housed, happiness from open amenities with diminishing copies and a cap,
## pubs that eat crops each day (or stay shut), a hall that needs power --
## and work time that follows, never below the floor.

var sim: Simulation
var bs: BuildingSystem
var community: CommunitySystem
var momos: MomoSystem
var inv: InventorySystem


func before_each() -> void:
	sim = Simulation.new_game()
	bs = sim.system(&"buildings")
	community = sim.system(&"community")
	momos = sim.system(&"momo")
	inv = sim.system(&"inventory")
	(sim.system(&"economy") as EconomySystem).earn(5000, "test")
	for c: Array in [[2, 0], [2, 1], [-1, 0], [-1, 1], [0, 2], [1, 2]]:
		sim.execute({"type": "land.buy", "cell": c})


func _built(type: String, cell: Vector2i) -> int:
	var id := bs.place_instant(type, cell)
	sim.bus.emit(&"building_built", {"id": id, "type": type})
	return id


func test_homes_fill_in_order_up_to_capacity() -> void:
	for i in 3:
		sim.execute({"type": "momo.hire"})
	var villa := _built("villa", Vector2i(0, 0))
	assert_eq(community.capacity(), 2, "a villa houses two")
	assert_eq(community.housing(), {1: villa, 2: villa}, "the first two Momo, by id")
	assert_eq(community.home_of(4), 0, "the rest sleep outdoors")
	var apt := _built("apartment", Vector2i(1, 0))
	assert_eq(community.housing(), {1: villa, 2: villa, 3: apt, 4: apt}, "then the apartment")


func test_rest_makes_a_housed_momo_quicker() -> void:
	assert_eq(community.work_factor(1), 1.0, "outdoors: no change")
	_built("villa", Vector2i(0, 0))
	assert_eq(community.work_factor(1), 0.92, "a villa: rested, 0.92")
	assert_near(momos.work_multiplier(1, "farm"), 4.0 * 0.92, 0.0001, "and Momo work follows")


func test_happiness_stacks_with_less_each_copy_and_is_capped() -> void:
	_built("park", Vector2i(0, 0))
	assert_eq(community.happiness(), 10.0, "one park: +10")
	_built("park", Vector2i(1, 0))
	assert_eq(community.happiness(), 15.0, "a second: +5")
	_built("park", Vector2i(0, 1))
	_built("park", Vector2i(1, 1))
	assert_eq(community.happiness(), 17.5, "a third +2.5, a fourth nothing")
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	bal["community"]["max_happiness"] = 12
	var s2 := Simulation.new_game(GameData.from_tables({"balance": bal}))
	var b2: BuildingSystem = s2.system(&"buildings")
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0)]:
		var id := b2.place_instant("park", c)
		s2.bus.emit(&"building_built", {"id": id, "type": "park"})
	assert_eq((s2.system(&"community") as CommunitySystem).happiness(), 12.0, "capped at the maximum")


func test_a_pub_needs_its_crops_each_day() -> void:
	var pub := _built("pub", Vector2i(0, 0))
	assert_false(community.is_open(pub), "no crops: shut")
	assert_eq(community.happiness(), 0.0, "and adds nothing")
	inv.add("crop", 5, "test")
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	assert_true(community.is_open(pub), "crops in the store: open for the day")
	assert_eq(community.happiness(), 14.0, "+14")
	var sold_or_eaten := inv.count("crop")
	assert_eq(sold_or_eaten, 0, "three eaten at opening, the other two sold at the day's sale (%d left)" % sold_or_eaten)
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	assert_false(community.is_open(pub), "the next day, with nothing left: shut again")


func test_a_hall_needs_power() -> void:
	(sim.system(&"research") as ResearchSystem).completed["civic_planning"] = 0
	var hall := _built("community_center", Vector2i(0, 0))
	assert_false(community.is_open(hall), "no power: shut")
	_built("water_wheel", Vector2i(-1, 0))
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	assert_true(community.is_open(hall), "3 kW on supply at dawn: open")
	assert_eq(community.happiness(), 18.0, "+18")


func test_work_factor_floor() -> void:
	var bal: Dictionary = GameData.load_default().table("balance").duplicate(true)
	bal["community"]["happiness_effect"] = 0.9
	bal["community"]["max_happiness"] = 10
	var s2 := Simulation.new_game(GameData.from_tables({"balance": bal}))
	var b2: BuildingSystem = s2.system(&"buildings")
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0)]:
		var id := b2.place_instant("park" if c.x == 0 else "villa", c)
		s2.bus.emit(&"building_built", {"id": id, "type": "x"})
	assert_eq((s2.system(&"community") as CommunitySystem).work_factor(1), 0.75, "never quicker than the floor")


func test_happiness_speeds_work_as_stated() -> void:
	_built("park", Vector2i(0, 0))
	_built("villa", Vector2i(1, 0))
	assert_near(community.work_factor(1), 0.92 * (1.0 - 10.0 / 100.0 * 0.15), 0.0001, "rest x (1 - happiness/100 x 0.15)")


func test_community_survives_a_save() -> void:
	var pub := _built("pub", Vector2i(0, 0))
	inv.add("crop", 10, "test")
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_true((copy.system(&"community") as CommunitySystem).is_open(pub), "still open today after loading")
	var state := sim.save_state()
	(state["systems"] as Dictionary).erase("community")
	assert_eq((Simulation.from_save(JSON.parse_string(JSON.stringify(state))).system(&"community") as CommunitySystem).open_on, {}, "an old save loads")


func test_bad_community_data_is_refused() -> void:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["villa"]["housing"]["capacity"] = 0
	b["types"]["pub"]["amenity"]["daily"] = {"ambrosia": 1}
	var text := "\n".join(GameData.from_tables({"buildings": b}).errors)
	assert_true(text.contains("housing needs capacity"), "a home for nobody")
	assert_true(text.contains("unknown item ambrosia"), "a pub serving what does not exist")
