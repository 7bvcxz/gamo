extends "res://tests/framework/test_case.gd"

## Saves from before Step 50 (schema 2) open in the new economy: what waited
## in the store for the next dawn's sale is paid once, at the old prices, and
## never again; farms continue from where their old five-stage cycle was, in
## the new sow-water-harvest cycle; and the island plays on.


## A schema-2 island as v0.49 saved it: a farm part-way through its old
## cycle, crops and a car waiting for dawn, money booked.
func _old_save(stage: int, state: String, variety: String = "base") -> Dictionary:
	# A schema-3 island had its starting Momo (Step 53 removed it from new games).
	var sim := with_starter_momo(Simulation.new_game())
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var s := sim.save_state()
	s["schema"] = 2
	var b: Dictionary = s["systems"]["buildings"]["buildings"][0]
	b["stage"] = stage
	b["state"] = state
	if variety != "base":
		b["variety"] = variety
	s["systems"]["inventory"]["items"] = {"crop": 4, "car": 1, "wood": 7}
	s["systems"]["economy"]["money"] = 30
	s["systems"]["economy"]["lifetime"] = {"sale": 100}
	assert_eq(farm, int(b["id"]), "")
	return s


func test_waiting_crops_and_cars_are_paid_once_at_the_old_prices() -> void:
	var state := SaveMigration.migrate(_old_save(0, "idle"))
	assert_eq(int(state["schema"]), Simulation.SAVE_SCHEMA, "now at the current schema")
	var sim := Simulation.from_save(state)
	var eco: EconomySystem = sim.system(&"economy")
	var inv: InventorySystem = sim.system(&"inventory")
	assert_eq(eco.money, 30 + 4 * 5 + 420, "4 crops at $5 and the car at $420, as the next dawn would have paid")
	assert_eq(int(eco.lifetime["sale"]), 100 + 4 * 5 + 420, "booked as sales")
	assert_eq([inv.count("crop"), inv.count("car")], [0, 0], "and gone from the store")
	assert_eq(inv.count("wood"), 7, "materials kept")
	var before := eco.money
	sim.advance_ms(sim.clock.day_ms * 3)
	assert_eq(eco.money, before, "nothing is paid again at dawn")


func test_farms_continue_where_their_old_cycle_was() -> void:
	# old: sow, water1, water2, water3, harvest -> new: sow, water, harvest
	var cases := [[0, "idle", "sow"], [1, "idle", "water"], [2, "idle", "harvest"], [3, "cooldown", "harvest"], [4, "idle", "harvest"],
		[1, "working", "water"], [3, "working", "water"], [4, "working", "harvest"]]
	for c: Array in cases:
		var sim := Simulation.from_save(SaveMigration.migrate(_old_save(int(c[0]), String(c[1]))))
		var bs: BuildingSystem = sim.system(&"buildings")
		var b := bs.get_building(bs.ids()[0])
		assert_eq(String(bs.current_stage(b)["id"]), String(c[2]), "old stage %d (%s) -> %s" % [c[0], c[1], c[2]])


func test_millet_maps_onto_its_dry_cycle() -> void:
	for c: Array in [[0, "idle", "sow"], [1, "idle", "harvest"], [2, "cooldown", "harvest"], [3, "idle", "harvest"], [2, "working", "sow"]]:
		var sim := Simulation.from_save(SaveMigration.migrate(_old_save(int(c[0]), String(c[1]), "millet")))
		var bs: BuildingSystem = sim.system(&"buildings")
		var b := bs.get_building(bs.ids()[0])
		assert_eq(String(bs.current_stage(b)["id"]), String(c[2]), "millet stage %d (%s) -> %s" % [c[0], c[1], c[2]])


func test_an_old_island_plays_on() -> void:
	var sim := Simulation.from_save(SaveMigration.migrate(_old_save(4, "idle")))
	var bs: BuildingSystem = sim.system(&"buildings")
	var eco: EconomySystem = sim.system(&"economy")
	var farm: int = bs.ids()[0]
	var before := eco.money
	assert_true(sim.execute({"type": "building.tap", "id": farm})["ok"], "the waiting harvest")
	sim.advance_to(int(bs.get_building(farm)["task_end"]))
	assert_eq(eco.money, before + eco.unit_price("crop"), "pays at once, in the new economy")
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var done := int(bs.get_building(farm)["completed"])
	sim.advance_ms(60000)
	# A cycle is three stages; its length is the game's (Step 69: 20.75 s).
	var cycle := float(bs.cycle_estimate(bs.get_building(farm))["cycle_seconds"])
	var want := int(60.0 / cycle * 3.0) - 2
	assert_true(int(bs.get_building(farm)["completed"]) - done >= want, "and its Momo keeps the cycle going (%d stages in a minute, %d+ expected)" % [int(bs.get_building(farm)["completed"]) - done, want])
