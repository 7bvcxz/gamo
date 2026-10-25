extends "res://tests/framework/test_case.gd"

## Crops go to the store; at the next day boundary the store's crops are sold
## at their data price; every dollar is booked; the store has limits.

var sim: Simulation
var economy: EconomySystem
var inv: InventorySystem
var buildings: BuildingSystem


func _start(data: GameData = null) -> void:
	sim = Simulation.new_game(data)
	economy = sim.system(&"economy")
	inv = sim.system(&"inventory")
	buildings = sim.system(&"buildings")


func before_each() -> void:
	_start()


## Runs a farm through a full cycle (115 s) by tapping whenever it is ready.
func _grow_one_batch(farm: int) -> void:
	for i in 5:
		var b := buildings.get_building(farm)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(buildings.remaining_ms(b))
		sim.execute({"type": "building.tap", "id": farm})
		sim.advance_ms(5000)


func test_harvest_is_sold_at_the_next_day_boundary() -> void:
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	_grow_one_batch(farm)
	assert_eq(inv.count("crop"), 1, "the harvest is in the store")
	var day := sim.clock.day_number()
	var before := economy.money
	sim.advance_to(sim.clock.next_day_start_ms() - 1)
	assert_eq(inv.count("crop"), 1, "still there just before midnight")
	sim.advance_ms(1)
	assert_eq(sim.clock.day_number(), day + 1, "a new day")
	assert_eq(economy.money, before + 5, "sold for $5")
	assert_eq(inv.count("crop"), 0, "the store is empty")


func test_price_comes_from_data() -> void:
	var items: Dictionary = GameData.load_default().table("items").duplicate(true)
	items["items"]["crop"]["price"] = 12
	_start(GameData.from_tables({"items": items}))
	inv.add("crop", 3)
	sim.advance_to(sim.clock.next_day_start_ms())
	assert_eq(economy.money, 10 + 36, "3 batches at $12")


func test_only_crops_are_sold() -> void:
	inv.add("crop", 2)
	inv.add("wood", 4)
	var sold: Array = []
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"sold":
			sold.append(p))
	sim.advance_to(sim.clock.next_day_start_ms())
	assert_eq(inv.count("wood"), 4, "wood is kept for building")
	assert_eq(sold.size(), 1, "one sale event")
	assert_eq(sold[0]["money"], 10, "$10 for two batches")
	assert_eq(sold[0]["day"], 2, "on Day 2")


func test_store_limit_stops_the_harvest_instead_of_wasting_it() -> void:
	inv.add("crop", inv.capacity("crop"))
	assert_eq(inv.room_for("crop"), 0, "full")
	assert_eq(inv.add("crop", 1), 0, "nothing more fits")
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	var b := buildings.get_building(farm)
	b["stage"] = 4
	var r := sim.execute({"type": "building.tap", "id": farm})
	assert_eq(r["reason"], "err.storage_full", "the harvest waits for room")
	assert_eq(b["state"], BuildingSystem.IDLE, "and has not started")
	sim.advance_to(sim.clock.next_day_start_ms())
	assert_true(sim.execute({"type": "building.tap", "id": farm})["ok"], "after the day's sale it can harvest")


func test_every_dollar_is_booked_by_day() -> void:
	economy.earn(200, "test")
	sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})
	sim.execute({"type": "land.buy", "cell": [2, 0]})
	inv.add("crop", 2)
	sim.advance_to(sim.clock.next_day_start_ms())
	var day1: Dictionary = economy.history[-1]
	assert_eq(day1["day"], 1, "Day 1 closed")
	assert_eq(day1["by"]["build"], -10, "farm")
	assert_eq(day1["by"]["land"], -50, "land")
	assert_eq(day1["by"]["sale"], 10, "the boundary's sale counts for the day that grew it")
	assert_eq(day1["expense"], 60, "$60 out")
	assert_eq(day1["close"], 10 + 200 - 60 + 10, "closing balance")
	sim.advance_to(sim.clock.next_day_start_ms())
	assert_eq(economy.history.size(), 2, "an empty day is still a day")
	assert_eq(economy.history[-1]["income"], 0, "with nothing in it")


func test_history_is_bounded() -> void:
	sim.advance_ms(30000 * 45)
	assert_eq(economy.history.size(), 30, "thirty days kept")
	assert_eq(economy.history[-1]["day"], 45, "the newest last")


func test_ledger_and_store_survive_a_save() -> void:
	inv.add("crop", 3)
	economy.spend(4, "build:farm")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var e2: EconomySystem = copy.system(&"economy")
	assert_eq((copy.system(&"inventory") as InventorySystem).count("crop"), 3, "crops in store")
	assert_eq(e2.today["build"], -4, "today's ledger")
	copy.advance_to(copy.clock.next_day_start_ms())
	assert_eq(e2.money, 6 + 15, "and the next sale still happens")


func test_a_harvest_on_the_boundary_is_sold_the_next_night() -> void:
	var farm := buildings.place_instant("farm", Vector2i(0, 0))
	var b := buildings.get_building(farm)
	b["stage"] = 4
	sim.advance_to(sim.clock.next_day_start_ms() - 5000)
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(5000)
	assert_eq(inv.count("crop"), 1, "harvested exactly at midnight: kept, not lost")
	sim.advance_to(sim.clock.next_day_start_ms())
	assert_eq(inv.count("crop"), 0, "sold at the following boundary")


func test_no_dead_end_from_the_start() -> void:
	# Whatever a player does, they always either own a farm or can afford one.
	var farm_cost := int(sim.data.building_type("farm")["cost"]["money"])
	var rng := RandomNumberGenerator.new()
	for run in 25:
		rng.seed = 1000 + run
		_start()
		for step in 120:
			match rng.randi_range(0, 4):
				0:
					sim.execute({"type": "building.place", "building": "farm", "anchor": [rng.randi_range(-1, 2), rng.randi_range(-1, 2)]})
				1:
					var ids := buildings.ids()
					if not ids.is_empty():
						sim.execute({"type": "building.cancel", "id": ids[rng.randi_range(0, ids.size() - 1)]})
				2:
					var land: LandSystem = sim.system(&"land")
					var c := land.candidates()
					sim.execute({"type": "land.buy", "cell": c[rng.randi_range(0, c.size() - 1)]})
				_:
					for id: int in buildings.ids():
						sim.execute({"type": "building.tap", "id": id})
			sim.advance_ms(rng.randi_range(500, 20000))
			assert_true(buildings.ids().size() > 0 or economy.money >= farm_cost, "run %d step %d: has a farm or can buy one" % [run, step])
	# And steady play grows money: one farm earns its first land.
	_start()
	var f: int = sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})["id"]
	sim.advance_ms(5000)
	var days := 0
	while economy.money < 50 and days < 60:
		_grow_one_batch(f)
		days = sim.clock.day_number()
	assert_true(economy.money >= 50, "one farm pays for the first land (by Day %d)" % days)
