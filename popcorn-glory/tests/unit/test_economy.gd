extends "res://tests/framework/test_case.gd"

## data/economy.json loads clean, prices follow round(base * growth^L), and the
## checks refuse a table whose upgrade would change nothing.


func test_default_file_loads_without_errors() -> void:
	var e := PopEconomy.load_default()
	assert_eq(e.errors.size(), 0, "errors %s" % [e.errors])
	assert_true(e.has("stub"), "the stub's table is there")


func test_cost_is_rounded_geometric_and_stops_at_max_level() -> void:
	var e := PopEconomy.new()
	assert_true(e.load_dict({"x": {"pops": [1, 2, 3], "cost": {"base": 10, "growth": 1.7}, "max_level": 2}}), "loads")
	assert_eq(e.cost("x", 0), 10, "level 0")
	assert_eq(e.cost("x", 1), 17, "level 1")
	assert_eq(e.cost("x", 2), -1, "nothing to buy at max level")
	assert_eq(e.cost("x", -1), -1, "no negative level")


func test_a_flat_or_falling_table_is_refused() -> void:
	var e := PopEconomy.new()
	assert_false(e.load_dict({"x": {"pops": [1, 1, 2], "cost": {"base": 10, "growth": 2}, "max_level": 2}}), "1 -> 1 refused")
	assert_true(e.errors[0].contains("rise"), "says why: %s" % [e.errors])


func test_a_short_table_is_refused() -> void:
	var e := PopEconomy.new()
	assert_false(e.load_dict({"x": {"pops": [1, 2], "cost": {"base": 10, "growth": 2}, "max_level": 2}}), "needs 3 entries")


func test_bad_costs_are_refused() -> void:
	var e := PopEconomy.new()
	assert_false(e.load_dict({"x": {"pops": [1, 2], "cost": {"base": 10, "growth": 1.0}, "max_level": 1}}), "growth 1 refused")
	assert_false(e.load_dict({"x": {"pops": [1, 2], "cost": {"base": 0, "growth": 2}, "max_level": 1}}), "base 0 refused")
