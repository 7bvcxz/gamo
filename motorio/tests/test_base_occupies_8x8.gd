extends SceneTree

## The base covers eight cells by eight -- four tiles across -- and every one of
## them is the base.
##
## Not a picture of a big building over one solid cell: each of the sixty-four
## answers "the core" to machine_at, blocks her, blocks the cats' pathing, and
## refuses a building. And the middle of the eight-by-eight is the point every
## ring in the world is measured from, so the fire did not move when it grew.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_generated_base()
	_test_unfolded_from_the_case()
	_test_hand_placed()
	if failures == 0:
		print("PASS test_base_occupies_8x8")
	else:
		print("FAIL test_base_occupies_8x8 (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_generated_base() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_assert(Defs.machine_size(Defs.M_CORE) == Vector2i(8, 8), "기지의 크기는 표에 적힌 8x8 이다")
	_check(sim, "생성된 기지")
	sim.free()

## The real opening: the case unfolds where it lay.
func _test_unfolded_from_the_case() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.begin_crash()
	var kit: Vector2i = sim.kit_cell
	sim.search_kit()
	_assert(sim.base_placed, "상자가 기지로 펼쳐진다")
	_assert(sim.core_cell == kit, "상자가 있던 칸이 기지의 앵커다")
	_check(sim, "펼쳐진 기지")
	sim.free()

## `place_base`, the hand-placed door the tests and the debug worlds use.
func _test_hand_placed() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.begin_crash()
	sim.carried_kit = Defs.KIT_BASE
	var anchor: Vector2i = sim.core_cell + Vector2i(2, 0)
	_assert(sim.place_base(anchor), "들고 온 기지를 내려놓는다")
	_check(sim, "손으로 놓은 기지")
	sim.free()

func _check(sim: Sim, label: String) -> void:
	var rect: Rect2i = sim.base_rect()
	_assert(rect.size == Vector2i(8, 8), "%s: 발자국이 8x8 이다 %s" % [label, rect.size])
	_assert(rect.position == sim.core_cell - Vector2i(3, 3),
		"%s: 앵커는 가운데 2x2 의 왼쪽 위 칸이다" % label)
	_assert(Grid.rect_px(rect).size == Vector2(128.0, 128.0),
		"%s: 월드에서 128px — 거리 단위로 4칸" % label)
	_assert(Grid.rect_centre(rect) == sim.core_centre(),
		"%s: 불의 가운데는 발자국의 가운데다" % label)
	var core: Sim.Machine = sim.machine_at(sim.core_cell)
	_assert(core != null and core.type == Defs.M_CORE, "%s: 앵커 칸에 코어가 있다" % label)
	# Every cell of the footprint, one by one.
	var covered := 0
	var solid := 0
	var refused := 0
	var pathed := 0
	sim._grid_dirty = true
	sim._refresh_grid()
	for cell: Vector2i in Grid.cells_in(rect):
		if sim.machine_at(cell) == core and sim.is_base(cell):
			covered += 1
		if sim.blocks_player(cell):
			solid += 1
		if sim.can_build(Defs.M_BELT, cell) == "이미 설비가 있습니다":
			refused += 1
		if sim._grid.is_point_solid(cell):
			pathed += 1
	_assert(covered == 64, "%s: 64칸 모두 코어다 (%d)" % [label, covered])
	_assert(solid == 64, "%s: 64칸 모두 그녀를 막는다 (%d)" % [label, solid])
	_assert(refused == 64, "%s: 64칸 어디에도 설비를 지을 수 없다 (%d)" % [label, refused])
	_assert(pathed == 64, "%s: 64칸 모두 고양이 길찾기에서 막혀 있다 (%d)" % [label, pathed])
	# And nothing past its walls is the base.
	var leaked := 0
	for cell: Vector2i in Grid.edge_cells(rect.grow(1)):
		if sim.is_base(cell):
			leaked += 1
	_assert(leaked == 0, "%s: 벽 바로 바깥은 기지가 아니다 (%d칸 샘)" % [label, leaked])
	# The fire cannot be taken down from any of its cells.
	var demolished := 0
	for cell: Vector2i in [rect.position, rect.end - Vector2i.ONE, sim.core_cell]:
		if sim.demolish(cell):
			demolished += 1
	_assert(demolished == 0, "%s: 어느 칸에서도 기지를 회수할 수 없다" % label)
