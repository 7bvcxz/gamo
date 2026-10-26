extends "res://tests/framework/test_case.gd"

## The island's daily book: written from what happened (work, money, items),
## closed at each dawn, read back as rates and shares that stay in range, and
## kept across a save.

var sim: Simulation
var bs: BuildingSystem
var book: AnalyticsSystem


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	bs = sim.system(&"buildings")
	book = sim.system(&"analytics")
	(sim.system(&"progression") as ProgressionSystem).add_exp(1000, "test")
	(sim.system(&"economy") as EconomySystem).earn(500, "test")


func _days(n: int) -> void:
	sim.advance_ms(sim.clock.day_ms * n)


func test_a_day_of_work_is_written_down() -> void:
	var yard := bs.place_instant("lumberyard", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": yard})
	_days(3)
	assert_true(book.days.size() >= 2, "closed days are kept (%d)" % book.days.size())
	var made := AnalyticsSystem.total(book.days, "made")
	assert_true(int(made.get("wood", 0)) > 0, "the wood it made is in the book")
	assert_eq(int(made.get("wood", 0)), (sim.system(&"inventory") as InventorySystem).count("wood") - _wood_in_today(), "exactly what the store gained on closed days")
	var rate := book.building_rate(yard, 7)
	assert_true(rate["stages"] > 0.0, "stages per day")
	assert_true(rate["utilization"] > 0.0 and rate["utilization"] <= 1.0, "a share of the day (%.2f)" % rate["utilization"])
	var u := book.momo_utilization(7)
	assert_true(u > 0.0 and u <= 1.0, "the Momo worked part of each day (%.2f)" % u)


func _wood_in_today() -> int:
	return int(book.today["made"].get("wood", 0))


func test_money_is_booked_by_kind() -> void:
	var before: Dictionary = (book.today["expense"] as Dictionary).duplicate()
	var r := sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})
	assert_true(r["ok"], "a farm bought")
	assert_eq(int(book.today["expense"].get("build", 0)) - int(before.get("build", 0)), 10, "$10 under building")


func test_idle_buildings_and_why() -> void:
	var mine := bs.place_instant("mine", Vector2i(1, 0))
	(sim.system(&"inventory") as InventorySystem).add("stone", 20, "test")
	(sim.system(&"inventory") as InventorySystem).add("wood", 10, "test")
	(sim.system(&"progression") as ProgressionSystem).add_exp(5000, "test")
	assert_true(sim.execute({"type": "building.refit", "id": mine, "building": "smelter"})["ok"], "a smelter with no ore")
	sim.advance_ms(30000)
	book.sample()
	assert_true(int(book.today["blocked"].get("missing", 0)) > 0, "it stands idle for missing ore")
	assert_true(int(book.today["blocked_by"].get(mine, 0)) > 0, "and the book says which building")


func test_old_days_drop_off() -> void:
	_days(35)
	assert_eq(book.days.size(), 30, "keep_days closed days, no more")
	assert_eq(int(book.days[-1]["day"]), sim.clock.day_number() - 1, "the newest is yesterday")


func test_kept_across_a_save() -> void:
	var yard := bs.place_instant("lumberyard", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": yard})
	_days(2)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var cbook: AnalyticsSystem = copy.system(&"analytics")
	assert_eq(cbook.days.size(), book.days.size(), "the same days")
	assert_eq(cbook.building_rate(yard), book.building_rate(yard), "the same rates (ids back as numbers)")
	assert_eq(cbook.momo_utilization(), book.momo_utilization(), "the same Momo share")


func test_numbers_people_read() -> void:
	assert_eq(NumberFormat.compact(1234.0, "en"), "1.2K", "English thousands")
	assert_eq(NumberFormat.compact(2500000.0, "en"), "2.5M", "millions")
	assert_eq(NumberFormat.compact(-2500000.0, "en"), "-2.5M", "with the sign")
	assert_eq(NumberFormat.compact(12345.0, "ko"), "1.2만", "Korean counts in 만")
	assert_eq(NumberFormat.compact(340000000.0, "ja"), "3.4億", "Japanese 億")
	assert_eq(NumberFormat.compact(10000.0, "zh_CN"), "1万", "Chinese 万, no .0")
	assert_eq(NumberFormat.compact(999.0, "en"), "999", "small numbers stay whole")
	assert_eq(NumberFormat.compact(1.5, "en"), "1.5", "and a fraction is kept")
