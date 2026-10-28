extends "res://tests/framework/test_case.gd"

## Step 73: a Village, a City and a Nation look different at a glance. The
## Village is drawn exactly as before (cliffs, its flowers, plain turf). A
## City mows its lawn in stripes, runs a sandy footpath inside every coast edge
## and plants flowerbeds and hedges; a Nation mows a checker, lays a jointed
## stone promenade with lamps, plants topiary and builds its bank in stone.
## Each promotion fades the old look into the new; a load, a sale and new land
## show the right look at once. Nothing a hand or a Momo uses moves, and the
## island stays a handful of draws.

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


func _promote(to: int) -> void:
	tiers.tier = to
	sim.bus.emit(&"tier_promoted", {"tier": to, "name": tiers.tier_name(), "special_slots": tiers.special_slots()})
	await tree.process_frame
	island._process(5.0)


## The vertex colours of the tops mesh, one per cell (its first vertex).
func _lawn_shades() -> Array[float]:
	var out: Array[float] = []
	var arr := island.tops_mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	for i in range(0, colors.size(), 6):
		out.append(snappedf(colors[i].r, 0.001))
	return out


## The coast edges of the island (each its own path band).
func _coast_edges() -> int:
	var n := 0
	for cell: Vector2i in world.owned_cells():
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			n += 0 if world.is_owned(cell + d) else 1
	return n


func _bank_mean() -> Color:
	var arr := island.bank_mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for c: Color in colors:
		if c.a > 0.9:
			sum += c
			n += 1
	return sum / maxf(n, 1)


func test_a_village_is_drawn_as_it_always_was() -> void:
	assert_eq(island.look, 0, "a Village")
	assert_eq([island.path_quads, island.lamp_count, island.bed_count], [0, 0, 0], "no path, lamps or beds")
	for s: float in _lawn_shades():
		assert_eq(s, 1.0, "plain turf, unshaded")
	assert_true(island.faces_mesh.get_surface_count() > 0, "its cliffs")
	assert_eq(island.grass_tint(), Color.WHITE, "its grass as it was")
	assert_false(island.glow.visible, "no lamp light")


func test_a_city_mows_stripes_lays_a_footpath_and_plants_beds() -> void:
	await _promote(1)
	assert_eq([island.look, island.look_t], [1, 1.0], "a City")
	var shades := _lawn_shades()
	var distinct := {}
	for s: float in shades:
		distinct[s] = true
	assert_eq(distinct.size(), 2, "the lawn in two shades: mown stripes (%s)" % [distinct.keys()])
	assert_eq(island.path_quads, _coast_edges(), "a footpath inside every coast edge (%d)" % _coast_edges())
	assert_eq(island.lamp_count, 0, "no lamps")
	assert_true(island.bed_count > 0, "flowerbeds and hedges (%d)" % island.bed_count)
	var bank := _bank_mean()
	assert_true(bank.r - bank.b > 0.08, "a sandy bank (%s)" % bank)


func test_a_nation_is_another_island_at_a_glance() -> void:
	await _promote(1)
	var city_bank := _bank_mean()
	var city_tint := island.grass_tint()
	await _promote(2)
	assert_eq([island.look, island.look_t], [2, 1.0], "a Nation")
	assert_true(island.lamp_count > 3, "lamps on the promenade (%d)" % island.lamp_count)
	assert_eq(island.path_quads, _coast_edges(), "the promenade inside every coast edge")
	var nation_bank := _bank_mean()
	var spread := maxf(nation_bank.r, maxf(nation_bank.g, nation_bank.b)) - minf(nation_bank.r, minf(nation_bank.g, nation_bank.b))
	var city_spread := maxf(city_bank.r, maxf(city_bank.g, city_bank.b)) - minf(city_bank.r, minf(city_bank.g, city_bank.b))
	assert_true(spread < city_spread, "a stone bank, greyer than the City's sand (%.3f < %.3f)" % [spread, city_spread])
	assert_true(island.grass_tint() != city_tint, "its own green")
	# The checker: neighbours across a row differ (a City's stripes do not).
	var a := IslandRenderer._lawn(Vector2i(1, 1), island.look_config())
	var b := IslandRenderer._lawn(Vector2i(2, 1), island.look_config())
	assert_true(a != b, "a checker, not stripes")
	assert_eq(IslandRenderer._lawn(Vector2i(1, 1), island.look_config(1)), IslandRenderer._lawn(Vector2i(2, 1), island.look_config(1)), "(a City's stripes run along the row)")


func test_promotions_fade_one_look_into_the_next() -> void:
	tiers.tier = 1
	sim.bus.emit(&"tier_promoted", {"tier": 1, "name": "city", "special_slots": 2})
	await tree.process_frame
	assert_true(island.look_t < 0.2, "Village to City starts (%.2f)" % island.look_t)
	assert_false(island._prev.is_empty(), "drawn over the Village's look")
	assert_eq(int(island._prev["look"]), 0, "")
	island._process(0.45)
	assert_between(island.city_t, 0.3, 0.8, "the cliffs giving way (Step 63's value follows)")
	island._process(5.0)
	assert_true(island._prev.is_empty(), "done: the old look let go")
	tiers.tier = 2
	sim.bus.emit(&"tier_promoted", {"tier": 2, "name": "nation", "special_slots": 3})
	await tree.process_frame
	assert_true(island.look_t < 0.2, "City to Nation plays too")
	assert_eq(island.city_t, 1.0, "with the bank kept throughout")
	island._process(5.0)
	assert_eq(island.look_t, 1.0, "")


func test_a_load_a_sale_and_new_land_show_the_right_look_at_once() -> void:
	tiers.tier = 2
	sim.bus.emit(&"game_loaded", {})
	await tree.process_frame
	assert_eq([island.look, island.look_t], [2, 1.0], "a Nation loaded: its look at once")
	assert_true(island._prev.is_empty(), "no fade")
	var fresh := Simulation.new_game()
	_land(fresh.system(&"world"))
	var next := IslandRenderer.new()
	tree.root.add_child(next)
	next.setup(fresh, proj)
	assert_eq([next.look, next.path_quads, next.lamp_count], [0, 0, 0], "the next island after a sale: a Village")
	next.queue_free()
	var before := island.path_quads
	world.add_land(Vector2i(6, 0))
	await tree.process_frame
	await tree.process_frame
	assert_eq(island.path_quads, _coast_edges(), "new land: the promenade round the new coast at once (%d -> %d)" % [before, island.path_quads])


func test_nothing_for_the_hand_moves() -> void:
	var land: LandSystem = sim.system(&"land")
	var before := land.candidates()
	var taps := {}
	for p: Vector2 in [Vector2(1.5, 1.5), Vector2(5.95, 2.5), Vector2(6.3, 2.5), Vector2(3.5, 2.5)]:
		taps[p] = proj.cell_at(proj.to_screen(p))
	for t in [1, 2]:
		await _promote(t)
		assert_eq(land.candidates(), before, "tier %d: the same land to buy" % t)
		for p: Vector2 in taps:
			assert_eq(proj.cell_at(proj.to_screen(p)), taps[p], "tier %d: a tap at %s lands where it did" % [t, p])
		assert_eq(world.owned_count(), 27, "the same island")


func test_the_lamps_light_up_at_night_only() -> void:
	await _promote(2)
	BuildingView.ambient = Color.WHITE
	island._process(0.016)
	assert_false(island.glow.visible, "by day, no glow")
	BuildingView.ambient = Color(0.35, 0.4, 0.62)
	island._process(0.016)
	assert_true(island.glow.visible and island.glow.modulate.a > 0.5, "at night, the lamps glow (%.2f)" % island.glow.modulate.a)
	assert_true(island.glow.modulate.r > 1.0, "warm through the night tint")
	BuildingView.ambient = Color.WHITE


func test_a_large_irregular_island_stays_cheap() -> void:
	var big := Simulation.new_game()
	var w: WorldSystem = big.system(&"world")
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	for x in 30:
		for y in 30:
			if rng.randf() < 0.82:
				w.add_land(Vector2i(x, y))
	var t: TierSystem = big.system(&"tiers")
	t.tier = 2
	var r := IslandRenderer.new()
	tree.root.add_child(r)
	r.setup(big, proj)
	assert_eq(r.look, 2, "a Nation")
	assert_true(r.last_build_ms < 1500.0, "built in %.0f ms" % r.last_build_ms)
	var verts := 0
	for m: ArrayMesh in [r.faces_mesh, r.tops_mesh, r.overlay_mesh, r.bank_mesh, r.bank_grass_mesh, r.glow_mesh]:
		if m.get_surface_count() > 0:
			verts += (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector2Array).size()
	assert_true(verts < 400000, "%d vertices in six meshes" % verts)
	r.queue_free()
