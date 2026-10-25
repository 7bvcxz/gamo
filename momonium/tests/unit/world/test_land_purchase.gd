extends "res://tests/framework/test_case.gd"

var sim: Simulation
var land: LandSystem
var world: WorldSystem
var economy: EconomySystem


func before_each() -> void:
	sim = Simulation.new_game()
	land = sim.system(&"land")
	world = sim.system(&"world")
	economy = sim.system(&"economy")


func test_prices_climb_from_data() -> void:
	assert_eq(land.cost_of(0), 50, "the first cell is $50")
	var last := 0
	for k in 12:
		var c := land.cost_of(k)
		assert_true(c > last, "cell %d costs more than the one before ($%d > $%d)" % [k, c, last])
		assert_eq(c % 5, 0, "prices are round")
		last = c
	var balance: Dictionary = GameData.load_default().table("balance").duplicate(true)
	balance["land"]["base"] = 20
	var cheap := Simulation.new_game(GameData.from_tables({"balance": balance}))
	assert_eq((cheap.system(&"land") as LandSystem).next_cost(), 20, "the table sets the price")


func test_buying_takes_the_money_and_raises_the_land() -> void:
	economy.earn(90, "test")
	var r := sim.execute({"type": "land.buy", "cell": [2, 0]})
	assert_true(r["ok"], "an adjacent cell")
	assert_eq(economy.money, 50, "$100 - $50")
	assert_true(world.is_owned(Vector2i(2, 0)), "now land")
	assert_true(world.is_contiguous(), "one island")
	assert_eq(r["next_cost"], 65, "the next one costs more")
	assert_eq(land.purchased_count(), 1, "recorded")


func test_invalid_purchases_change_nothing() -> void:
	economy.earn(10000, "test")
	var before := economy.money
	for cell: Array in [[2, 2], [5, 0], [0, 0], [-1, -1]]:
		var r := sim.execute({"type": "land.buy", "cell": cell})
		assert_false(r["ok"], "%s refused" % [cell])
	assert_eq(economy.money, before, "no money taken")
	assert_eq(world.owned_count(), 4, "no land added")
	assert_eq(sim.execute({"type": "land.buy", "cell": [0, 0]})["reason"], "err.owned", "owned")
	assert_eq(sim.execute({"type": "land.buy", "cell": [2, 2]})["reason"], "err.not_adjacent", "diagonal is not adjacent")


func test_cannot_buy_without_the_money() -> void:
	var r := sim.execute({"type": "land.buy", "cell": [2, 0]})
	assert_false(r["ok"], "$10 does not buy a $50 cell")
	assert_eq(r["reason"], "err.not_enough_money", "with the reason")
	assert_eq(r["cost"], 50, "and the price")
	assert_eq(economy.money, 10, "money untouched")
	assert_false(world.is_owned(Vector2i(2, 0)), "land untouched")


func test_suggestions_grow_towards_a_square() -> void:
	economy.earn(100000, "test")
	# 2x2 -> the suggested ring adds a column: 2x3 or 3x2.
	var s := land.suggested()
	assert_true(s.size() >= 2, "a whole side is suggested (%s)" % [s])
	for c: Vector2i in s:
		land.buy(c)
	var b := world.bounds()
	assert_eq(b.size.x * b.size.y, world.owned_count(), "after following them the island is a full rectangle %s" % b)
	for c: Vector2i in land.suggested():
		land.buy(c)
	var b2 := world.bounds()
	assert_eq(b2.size, Vector2i(3, 3), "2x2 -> 2x3 -> 3x3")
	assert_eq(world.owned_count(), 9, "nine cells")


func test_any_shape_is_allowed() -> void:
	economy.earn(100000, "test")
	for cell: Array in [[2, 0], [3, 0], [4, 0], [4, 1], [4, 2]]:
		assert_true(sim.execute({"type": "land.buy", "cell": cell})["ok"], "%s" % [cell])
	assert_true(world.is_contiguous(), "a hook-shaped island is still one piece")


func test_save_round_trip_keeps_the_price_level() -> void:
	economy.earn(1000, "test")
	land.buy(Vector2i(2, 0))
	land.buy(Vector2i(2, 1))
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var l2: LandSystem = copy.system(&"land")
	assert_eq(l2.next_cost(), land.next_cost(), "the price level survives a save")
	assert_eq((copy.system(&"world") as WorldSystem).owned_count(), 6, "and the land")
