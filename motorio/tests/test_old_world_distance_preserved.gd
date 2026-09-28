extends SceneTree

## The grid went finer; the world did not get smaller.
##
## Every distance the game promises -- the rings the generator keeps, the walk
## from the landing to the case, how fast a belt carries her, how far the cat
## scatter reaches -- is measured here in world pixels and compared with what it
## was when a cell was 32 pixels. Grid v2 changes the unit things are counted
## in; if any of these moved, it changed the game.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_fire_is_where_the_core_was()
	_test_the_landing_walk()
	_test_rings_over_seeds()
	_test_speeds()
	_test_regions()
	if failures == 0:
		print("PASS test_old_world_distance_preserved")
	else:
		print("FAIL test_old_world_distance_preserved (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## The base is eight cells across now and its middle is exactly where the middle
## of the old one-cell core was: every ring is measured from that point.
func _test_fire_is_where_the_core_was() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_assert(sim.core_centre() == Vector2(16.0, 16.0),
		"불의 가운데는 옛 코어 칸의 가운데 (16,16) 이다: %s" % sim.core_centre())
	# A cell 20 tiles east is 640px out, and says so in tiles.
	var twenty: Vector2i = sim.core_cell + Vector2i(20 * Grid.SCALE, 0)
	_assert(absf(sim.tiles_from_core(twenty) - 20.0) < 0.3,
		"20칸(타일) 거리는 새 칸 40개다: %.2f" % sim.tiles_from_core(twenty))
	sim.free()

func _test_the_landing_walk() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.begin_crash()
	var walk: float = sim.prop_centre(sim.kit_cell).distance_to(sim.core_centre())
	_assert(absf(walk - Grid.px(Vector2(Defs.KIT_OFFSET).length())) < 0.5,
		"착륙 지점에서 상자까지 옛 거리 그대로 (%.1fpx)" % walk)
	sim.free()

## Two hundred worlds, measured in pixels from the fire: the promises the
## generator keeps are in the same places they always were.
func _test_rings_over_seeds() -> void:
	var starter_short := 0
	var debris_off := 0
	var copper_off := 0
	var iron_off := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(70000 + index)
		# The starter frozen cat, at FROZEN_MIN_RING or a little past it.
		var nearest_ice: float = 1e9
		for origin: Vector2i in sim.frozen_cats:
			nearest_ice = minf(nearest_ice, sim.prop_tiles_from_core(origin))
		if nearest_ice < Defs.FROZEN_MIN_RING - 0.5 or nearest_ice > Defs.FROZEN_MIN_RING + 2.0:
			starter_short += 1
		# The first wreck on its ring, and none nearer.
		var nearest_wreck: float = 1e9
		for origin: Vector2i in sim.debris:
			nearest_wreck = minf(nearest_wreck, sim.prop_tiles_from_core(origin))
		if roundi(nearest_wreck) != int(Defs.DEBRIS_FIRST_RING):
			debris_off += 1
		# The pinned copper and iron patches, every node inside their band.
		var copper := 0
		var iron := 0
		for cell: Vector2i in sim.ore_nodes:
			var d: float = sim.ore_tiles_from_core(cell)
			match sim.ore_type_at(cell):
				Defs.ITEM_COPPER:
					if d >= Defs.FIRST_COPPER_BAND.x and d <= Defs.FIRST_COPPER_BAND.y:
						copper += 1
				Defs.ITEM_IRON:
					if d >= Defs.FIRST_IRON_BAND.x and d <= Defs.FIRST_IRON_BAND.y:
						iron += 1
		if copper < Defs.FIRST_COPPER_SIZE:
			copper_off += 1
		if iron < Defs.FIRST_IRON_SIZE:
			iron_off += 1
		sim.free()
	_assert(starter_short == 0, "시작 고양이는 200회차 모두 8.5칸 고리에 (%d회 어긋남)" % starter_short)
	_assert(debris_off == 0, "첫 잔해는 200회차 모두 16칸 고리에 (%d회 어긋남)" % debris_off)
	_assert(copper_off == 0, "첫 구리 %d개는 11.4~12.8칸 띠 안에 (%d회 부족)"
		% [Defs.FIRST_COPPER_SIZE, copper_off])
	_assert(iron_off == 0, "첫 철 %d개는 19.6~20.9칸 띠 안에 (%d회 부족)"
		% [Defs.FIRST_IRON_SIZE, iron_off])

func _test_speeds() -> void:
	# Written against the old 32px cell by hand, so a change in Grid cannot move
	# the expectation along with the thing it checks.
	_assert(is_equal_approx(Defs.belt_carry_speed(), 0.30 * 32.0 * 3.5),
		"벨트가 그녀를 나르는 속도는 %.1fpx/s 그대로" % Defs.belt_carry_speed())
	_assert(is_equal_approx(Defs.belt_cell_speed(0) * float(Grid.CELL), 0.30 * 32.0),
		"벨트 위 물건의 월드 속도도 그대로 (%.1fpx/s)" % (Defs.belt_cell_speed(0) * float(Grid.CELL)))
	_assert(is_equal_approx(Defs.belt_gap_cells() * float(Grid.CELL), 0.34 * 32.0),
		"물건 간격도 월드에서 그대로 (%.2fpx)" % (Defs.belt_gap_cells() * float(Grid.CELL)))
	_assert(is_equal_approx(Defs.CAT_SPEED, 46.0), "고양이 걸음은 픽셀 단위 그대로")
	_assert(is_equal_approx(PlayerActor.SPEED, 84.0), "그녀의 걸음도 픽셀 단위 그대로 (84px/s)")

## The regions that were a number of cells are the same ground.
func _test_regions() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim._refresh_grid()
	var region: Rect2i = sim._grid.region
	_assert(Grid.rect_px(region).size.x >= float(Sim.PATH_RADIUS * 2) * float(Grid.TILE),
		"고양이 길찾기 격자가 옛 48칸 반경의 땅을 덮는다 (%.0fpx)" % Grid.rect_px(region).size.x)
	# A map chunk is the same patch of ground, so a save's chunk numbers still
	# name the places they named.
	_assert(Sim.chunk_of(Vector2i(4, 4)) == Vector2i(1, 1), "탐사 조각 하나는 64px 땅이다")
	_assert(Sim.chunk_of(Vector2i(3, 3)) == Vector2i(0, 0), "그 경계도 같다")
	# The opening circle.
	_assert(is_equal_approx(Grid.px(Defs.WARM_BASE), 224.0), "첫 온기 원은 224px (7칸)")
	sim.free()
