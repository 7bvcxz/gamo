extends SceneTree

## The hut covers four cells by four -- two tiles by two -- and every one of them
## is the hut (World Visual Pass 01). It was six by eight: a barn for one person
## and a handful of cats, bigger than the fire it stood beside the fire for.
##
## It is not a machine, so it is not in `machines`; it is a building on the grid
## all the same, and the same questions get the same answers on each of its
## sixteen cells: solid to her, solid to the cats' pathing, and no building on
## top of it. Its door is below it, on open snow, and the picture stays on it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_size_is_data()
	_test_generated_hut()
	_test_carried_hut()
	_test_picture_stays_on_its_cells()
	if failures == 0:
		print("PASS test_shelter_is_4x4")
	else:
		print("FAIL test_shelter_is_4x4 (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_size_is_data() -> void:
	_assert(Defs.SHELTER_SIZE == Vector2i(4, 4), "숙소의 크기는 한 상수 4x4 이다")
	# Square: the same footprint function turns it into itself.
	_assert(Grid.footprint(Vector2i.ZERO, Defs.SHELTER_SIZE, Vector2i.DOWN).size == Vector2i(4, 4),
		"돌려도 4x4")

func _test_generated_hut() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_check(sim, "생성된 숙소")
	sim.free()

## Carried out of the case and put down in the warm ground, the way she does it.
func _test_carried_hut() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.shelter_placed = false
	sim.carried_kit = Defs.KIT_SHELTER
	# Right against the fire is refused on every cell the band covers.
	var close: Vector2i = sim.core_cell + Vector2i(-6, 0)
	var problems: Dictionary = sim.shelter_problems(close)
	_assert(not problems.is_empty(), "불에 붙여 놓으면 거부된다")
	var reasons: Array = problems.values()
	_assert(reasons.has("불에 너무 가깝습니다"), "이유는 불에 너무 가깝다는 것")
	_assert(not sim.place_shelter(close), "그리고 실제로 놓이지 않는다")
	var spot: Vector2i = sim.free_anchor_near(sim.core_cell + Defs.SHELTER_CELL, Defs.SHELTER_SIZE,
		func(anchor: Vector2i) -> Dictionary: return sim.shelter_problems(anchor))
	_assert(spot != Sim.NONE, "기지 곁에 숙소를 놓을 자리가 있다")
	_assert(sim.place_shelter(spot), "그 자리에 놓인다")
	_check(sim, "손으로 놓은 숙소")
	sim.free()

func _check(sim: Sim, label: String) -> void:
	var rect: Rect2i = sim.shelter_rect()
	_assert(rect.size == Vector2i(4, 4), "%s: 발자국이 4x4 이다 %s" % [label, rect.size])
	_assert(rect.position == sim.shelter_cell - Vector2i(1, 1), "%s: 앵커는 (1,1)" % label)
	_assert(Grid.rect_px(rect).size == Vector2(64.0, 64.0), "%s: 월드에서 64x64px" % label)
	var inside := 0
	var solid := 0
	var refused := 0
	var pathed := 0
	sim._grid_dirty = true
	sim._refresh_grid()
	for cell: Vector2i in Grid.cells_in(rect):
		if sim.in_shelter(cell):
			inside += 1
		if sim.blocks_player(cell):
			solid += 1
		if sim.can_build(Defs.M_BELT, cell) != "":
			refused += 1
		if sim._grid.is_point_solid(cell):
			pathed += 1
	_assert(inside == 16, "%s: 16칸 모두 숙소다 (%d)" % [label, inside])
	_assert(solid == 16, "%s: 16칸 모두 그녀를 막는다 (%d)" % [label, solid])
	_assert(refused == 16, "%s: 16칸 어디에도 설비를 지을 수 없다 (%d)" % [label, refused])
	_assert(pathed == 16, "%s: 16칸 모두 고양이 길찾기에서 막혀 있다 (%d)" % [label, pathed])
	var leaked := 0
	for cell: Vector2i in Grid.edge_cells(rect.grow(1)):
		if sim.in_shelter(cell):
			leaked += 1
	_assert(leaked == 0, "%s: 벽 바로 바깥은 숙소가 아니다" % label)
	# The door is on open ground, below the middle of the hut, and warm.
	var door: Vector2 = sim.shelter_doorstep()
	_assert(not Grid.rect_px(rect).has_point(door), "%s: 문간은 숙소 바깥이다" % label)
	_assert(not sim.blocks_player(sim.cell_of(door)), "%s: 문간은 서 있을 수 있는 땅이다" % label)
	_assert(absf(door.x - Grid.rect_px(rect).get_center().x) < 0.01, "%s: 문간은 숙소 가운데 아래" % label)
	_assert(sim.is_warm_at(sim.shelter_centre()), "%s: 숙소는 온기 안에 있다" % label)

## What the hut draws covers no more than what it blocks, and fills it: the old
## picture was square on a six by eight and left a strip of "hut" nobody could
## see. Measured on the source PNG's opaque pixels, drawn the way `_draw_shelter`
## draws it.
func _test_picture_stays_on_its_cells() -> void:
	var footprint: Vector2 = Grid.rect_px(Grid.footprint(Vector2i.ZERO, Defs.SHELTER_SIZE)).size
	var drawn: float = MachineLayer.SHELTER_DRAW * MachineLayer._k(minf(footprint.x, footprint.y))
	var image: Image = Image.load_from_file(
		ProjectSettings.globalize_path(MachineLayer.SHELTER_ART.resource_path))
	_assert(image != null, "숙소 그림을 읽는다")
	if image == null:
		return
	var used: Rect2i = image.get_used_rect()
	var per_pixel: float = drawn / float(image.get_width())
	var opaque := Rect2(Vector2.ONE * -drawn * 0.5 + Vector2(used.position) * per_pixel,
		Vector2(used.size) * per_pixel)
	var cells := Rect2(-footprint * 0.5, footprint)
	_assert(cells.grow(0.01).encloses(opaque), "숙소 그림이 4x4 발자국 안에 그려진다 (%s / %s)" % [opaque, cells])
	_assert(opaque.size.x >= footprint.x * 0.8 and opaque.size.y >= footprint.y * 0.8,
		"그리고 발자국을 채운다 (%s)" % opaque.size)
