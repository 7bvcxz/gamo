extends "res://tests/framework/test_case.gd"

var sim: Simulation
var world: WorldSystem


func before_each() -> void:
	sim = Simulation.new_game()
	world = sim.system(&"world")


func test_new_game_is_a_2x2_island_and_nothing_else() -> void:
	assert_eq(world.owned_cells(), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i], "exactly the 2x2 starting island")
	assert_true(world.is_contiguous(), "one piece")
	assert_eq(world.buildable_cells().size(), 4, "all four cells are free to build on")
	assert_eq(world.occupancy.size(), 0, "no prebuilt industries")
	assert_eq((sim.system(&"economy") as EconomySystem).money, 10, "$10")
	assert_eq((sim.system(&"progression") as ProgressionSystem).level, 1, "Level 1")
	assert_eq(world.bounds(), Rect2i(0, 0, 2, 2), "bounds")


func test_cell_states() -> void:
	assert_eq(world.cell_state(Vector2i(0, 0)), WorldSystem.CellState.BUILDABLE, "owned free cell")
	assert_eq(world.cell_state(Vector2i(2, 0)), WorldSystem.CellState.PURCHASABLE, "east of the island")
	assert_eq(world.cell_state(Vector2i(-1, 1)), WorldSystem.CellState.PURCHASABLE, "west of the island")
	assert_eq(world.cell_state(Vector2i(2, 2)), WorldSystem.CellState.OCEAN, "diagonal contact is not adjacency")
	assert_eq(world.cell_state(Vector2i(9, -4)), WorldSystem.CellState.OCEAN, "open sea")
	world.occupy([Vector2i(1, 1)] as Array[Vector2i], 7)
	assert_eq(world.cell_state(Vector2i(1, 1)), WorldSystem.CellState.OCCUPIED, "occupied")
	assert_false(world.is_buildable(Vector2i(1, 1)), "occupied is not buildable")
	assert_eq(world.occupant(Vector2i(1, 1)), 7, "occupant id")


func test_frontier_of_the_start_island() -> void:
	var f := world.frontier()
	assert_eq(f.size(), 8, "eight edge neighbours around a 2x2")
	for c: Vector2i in f:
		assert_true(world.is_purchasable(c), "%s is purchasable" % c)


func test_land_grows_only_by_whole_edges() -> void:
	assert_true(world.add_land(Vector2i(2, 0)), "adjacent cell")
	assert_eq(world.owned_count(), 5, "now five cells")
	assert_false(world.add_land(Vector2i(3, 3)), "far cell refused")
	assert_false(world.add_land(Vector2i(-1, -1)), "diagonal-only cell refused")
	assert_false(world.add_land(Vector2i(0, 0)), "already owned refused")
	assert_true(world.is_contiguous(), "still one piece")
	# Non-rectangular growth is fine.
	assert_true(world.add_land(Vector2i(3, 0)), "a peninsula")
	assert_true(world.add_land(Vector2i(3, -1)), "an L")
	assert_eq(world.bounds(), Rect2i(0, -1, 4, 3), "bounds follow the shape")


func test_occupancy_is_all_or_nothing() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 5)]
	assert_false(world.occupy(cells, 3), "one cell is sea -> nothing is occupied")
	assert_false(world.is_occupied(Vector2i(0, 0)), "the land cell was not taken")
	var two: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	assert_true(world.occupy(two, 3), "two free cells")
	assert_false(world.occupy([Vector2i(1, 0)] as Array[Vector2i], 4), "cannot stack")
	assert_false(world.occupy([Vector2i(0, 1)] as Array[Vector2i], 3), "an id occupies once")
	assert_true(world.vacate(3), "vacate")
	assert_eq(world.buildable_cells().size(), 4, "both cells free again")
	assert_false(world.vacate(3), "vacating twice is refused")


func test_thousands_of_cells_stay_cheap() -> void:
	var cells: Array = []
	for y in 100:
		for x in 100:
			cells.append([x, y, "grass"])
	var t0 := Time.get_ticks_usec()
	world.load_state({"land": cells})
	var f := world.frontier()
	var free := 0
	for i in 20000:
		if world.is_buildable(Vector2i(i % 100, (i / 100) % 100)):
			free += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_eq(world.owned_count(), 10000, "10,000 cells")
	assert_eq(f.size(), 400, "frontier of a 100x100 square")
	assert_true(world.is_contiguous(), "contiguous")
	assert_eq(free, 20000, "lookups")
	assert_true(ms < 500.0, "load + frontier + 20k lookups in %.1f ms" % ms)


func test_save_round_trip() -> void:
	world.add_land(Vector2i(-1, 0))
	world.occupy([Vector2i(-1, 0), Vector2i(0, 0)] as Array[Vector2i], 12)
	var restored := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var w2: WorldSystem = restored.system(&"world")
	assert_eq(w2.owned_cells(), world.owned_cells(), "land restored")
	assert_eq(w2.occupant(Vector2i(-1, 0)), 12, "occupancy restored")
	assert_eq(w2.footprint(12), [Vector2i(-1, 0), Vector2i(0, 0)] as Array[Vector2i], "footprint restored")
	assert_true(w2.vacate(12), "and still vacatable")
