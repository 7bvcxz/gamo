extends "res://tests/framework/test_case.gd"

## Step 63: a City's island grows up -- warmer grass and, instead of cliffs,
## a bank sloping half a tile out into the water down to the waterline,
## shaped by the distance to the land (corners, coves, a lake: nothing
## overlaps). A Village keeps its cliffs; a Nation keeps the City's look; a
## sale's new island is a Village again. Promotion plays the change; a load
## shows it at once. Only drawn: cells, taps and buildings stay put; the sea
## draws its coast at the bank's foot.

const OWNED := ["######", "######", "###.##", "######", ".#.###"]

var sim: Simulation
var world: WorldSystem
var tiers: TierSystem
var proj: IsoProjection
var island: IslandRenderer


func _land(w: WorldSystem) -> void:
	for y in OWNED.size():
		for x in String(OWNED[y]).length():
			if String(OWNED[y])[x] == "#" and not w.is_owned(Vector2i(x, y)):
				w.add_land(Vector2i(x, y))


func before_each() -> void:
	sim = Simulation.new_game()
	world = sim.system(&"world")
	tiers = sim.system(&"tiers")
	_land(world)
	proj = IsoProjection.from_data(sim.data)
	island = IslandRenderer.new()
	tree.root.add_child(island)
	island.setup(sim, proj)


func after_each() -> void:
	island.queue_free()
	await tree.process_frame


func _promote(to: int = 1) -> void:
	tiers.tier = to
	sim.bus.emit(&"tier_promoted", {"tier": to, "name": tiers.tier_name(), "special_slots": tiers.special_slots()})
	await tree.process_frame


func test_a_village_keeps_its_cliffs_and_its_grass() -> void:
	assert_false(island.city, "a Village")
	assert_eq(island.city_t, 0.0, "")
	assert_eq(island.bank_quads, 0, "no bank")
	assert_eq(island.bank_mesh.get_surface_count(), 0, "")
	assert_true(island.faces_mesh.get_surface_count() > 0, "its cliffs")
	assert_eq(island.grass_tint(), Color.WHITE, "its grass as it was")


func test_a_city_has_warmer_grass_and_a_bank_instead_of_cliffs() -> void:
	await _promote()
	assert_true(island.city, "a City")
	assert_true(island.bank_quads > 0, "a bank (%d sub-quads)" % island.bank_quads)
	island._process(5.0)
	assert_eq(island.city_t, 1.0, "the change has played")
	var raw: Array = sim.data.get_value("art", "island_tiers.city_grass_tint")
	assert_eq(island.grass_tint(), Color(float(raw[0]), float(raw[1]), float(raw[2])), "the City's grass tint")
	assert_true(island.grass_tint().r > island.grass_tint().b, "warmer")
	assert_false(island.is_processing(), "and at rest")


func test_the_bank_runs_half_a_tile_down_to_the_water() -> void:
	await _promote()
	var run := sim.data.get_float("art", "island_tiers.bank_run", 0.0)
	assert_near(run, 0.5, 0.0001, "half a tile, in logical x/y")
	assert_near(island.bank_height(0.0), 0.0, 0.0001, "at the land's height")
	assert_near(island.bank_height(run), -proj.cliff_height, 0.0001, "down to the waterline")
	assert_between(island.bank_height(run * 0.5), -proj.cliff_height * 0.6, -proj.cliff_height * 0.4, "sloping between")
	# Every sub-quad lies within the run (one step's slack) of the land.
	var step := 1.0 / sim.data.get_float("art", "island_tiers.bank_steps", 6.0)
	var far := 0.0
	for o: Vector2 in island.bank_origins:
		far = maxf(far, island.land_distance(o + Vector2(step, step) * 0.5))
	assert_true(far <= run + step, "nothing beyond half a tile and a step (%.3f)" % far)
	assert_true(far >= run - step, "and it reaches it (%.3f)" % far)
	# On screen at the default projection: half a tile out along +x is 32 px
	# across and 24.5 px down, plus the drop to the water.
	var across := proj.to_screen(Vector2(run, 0.0)) - proj.to_screen(Vector2.ZERO)
	assert_near(across.x, proj.tile_width * 0.25, 0.01, "%.1f px across" % across.x)
	assert_near(across.y, proj.tile_height * 0.25, 0.01, "%.1f px down" % across.y)


func test_corners_a_cove_and_a_lake_never_overlap() -> void:
	await _promote()
	var seen := {}
	for o: Vector2 in island.bank_origins:
		var key := "%.4f,%.4f" % [o.x, o.y]
		assert_false(seen.has(key), "one sub-quad per place (%s)" % key)
		seen[key] = true
		var cell := Vector2i(floori(o.x + 0.0001), floori(o.y + 0.0001))
		assert_false(world.is_owned(cell), "out in the water, never on the land (%s)" % cell)
	var cells := island.bank_cells()
	for want: Vector2i in [Vector2i(3, 2), Vector2i(2, 4), Vector2i(0, 4), Vector2i(6, 5), Vector2i(-1, -1)]:
		assert_true(cells.has(want), "the bank reaches %s (lake, cove, notch, outer corners)" % want)
	# The one-tile lake: its middle is the deepest, at the waterline.
	assert_near(island.bank_height(island.land_distance(Vector2(3.5, 2.5))), -proj.cliff_height, 0.0001, "the lake's middle is water")


func test_promotion_plays_and_a_load_shows_it_at_once() -> void:
	await _promote()
	assert_between(island.city_t, 0.0, 0.1, "the change starts from the Village (a frame in)")
	assert_true(island.is_processing(), "and plays")
	island._process(sim.data.get_float("art", "island_tiers.fade_seconds", 0.9) * 0.5)
	assert_between(island.city_t, 0.4, 0.6, "half way")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	var loaded := Simulation.from_save(saved)
	var again := IslandRenderer.new()
	tree.root.add_child(again)
	again.setup(loaded, proj)
	assert_true(again.city, "a City loaded")
	assert_eq(again.city_t, 1.0, "with its look at once")
	assert_true(again.bank_quads > 0, "")
	again.queue_free()


func test_a_nation_keeps_it_and_a_sold_island_is_a_village() -> void:
	await _promote(2)
	assert_true(island.city, "a Nation keeps the City's look")
	var fresh := Simulation.new_game()
	_land(fresh.system(&"world"))
	var next := IslandRenderer.new()
	tree.root.add_child(next)
	next.setup(fresh, proj)
	assert_false(next.city, "the next island (after a sale) starts a Village")
	assert_eq(next.bank_quads, 0, "")
	next.queue_free()
	# Back to a Village on the same renderer (a load of a Village save).
	tiers.tier = 0
	sim.bus.emit(&"game_loaded", {})
	await tree.process_frame
	assert_false(island.city, "a Village again")
	assert_eq(island.city_t, 0.0, "at once")


func test_land_bought_after_promotion_gets_its_bank() -> void:
	await _promote()
	island._process(5.0)
	assert_false(island.bank_cells().has(Vector2i(8, 0)), "not yet")
	world.add_land(Vector2i(6, 0))
	sim.bus.emit(&"land_added", {"cell": [6, 0]})
	await tree.process_frame
	assert_true(island.bank_cells().has(Vector2i(7, 0)), "the new coast has a bank")
	assert_false(island.bank_cells().has(Vector2i(6, 0)), "and the new land none")


func test_the_bank_is_only_drawn() -> void:
	var land: LandSystem = sim.system(&"land")
	var before := land.candidates()
	await _promote()
	assert_eq(land.candidates(), before, "the same tiles to buy")
	var on_bank := proj.to_screen(Vector2(6.25, 1.5))
	assert_eq(proj.cell_at(on_bank), Vector2i(6, 1), "a tap there is on the water cell, as before")
	assert_false(world.is_owned(Vector2i(6, 1)), "which nobody owns")


func test_the_sea_draws_its_coast_at_the_banks_foot() -> void:
	var f := ShoreField.new()
	f.build(world)
	var village_coast := f.sample(Vector2(6.0, 1.5))
	f.build(world, 0.5)
	assert_near(f.sample(Vector2(6.5, 1.5)), village_coast, 0.1, "a City's coast at the bank's foot, as a Village's at its cliff")
	assert_true(f.sample(Vector2(7.0, 1.5)) < 0.06, "open water half a tile beyond, as for a Village")
	assert_eq(f.sample(Vector2(2.5, 1.5)), 1.0, "land")
	var v := ShoreField.new()
	v.build(world)
	assert_eq(v.sample(Vector2(6.0, 1.5)), village_coast, "a Village's coast as it always was")
