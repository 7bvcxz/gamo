extends SceneTree

## Grid v2: the same orthogonal grid, twice as fine.
##
## A cell is half a tile each way, so what was one cell is a block of two by two.
## The grid's direction is not what changed -- rows and columns stay square to
## the screen, never a diamond -- and every conversion between a cell and pixels
## goes through Grid.gd, so this file pins Grid.gd.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_sizes()
	_test_orthogonal()
	_test_round_trip()
	_test_tiles_are_blocks()
	_test_footprints()
	_test_reach_is_a_tile()
	_test_no_second_tile_constant()
	if failures == 0:
		print("PASS test_grid_v2_cell_scale")
	else:
		print("FAIL test_grid_v2_cell_scale (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_sizes() -> void:
	_assert(Grid.TILE == 32, "거리 단위(옛 칸)는 32px 그대로다 (%d)" % Grid.TILE)
	_assert(Grid.CELL == 16, "새 칸은 16px — 가로세로 절반 (%d)" % Grid.CELL)
	_assert(Grid.SCALE == 2, "옛 칸 하나 = 새 칸 2x2 (%d)" % Grid.SCALE)
	_assert(Grid.CELL * Grid.SCALE == Grid.TILE, "칸 크기 x 배율 = 타일")
	# Resolution: four times as many cells in the same ground.
	var ground := Rect2(Vector2.ZERO, Vector2(320.0, 320.0))
	var cells: int = int(ground.size.x / Grid.CELL) * int(ground.size.y / Grid.CELL)
	var tiles: int = int(ground.size.x / Grid.TILE) * int(ground.size.y / Grid.TILE)
	_assert(cells == tiles * 4, "같은 땅에 칸이 네 배다 (%d vs %d)" % [cells, tiles])

## Neighbouring cells differ along exactly one screen axis. A diamond grid would
## move both x and y for a step along one grid axis.
func _test_orthogonal() -> void:
	var step_x: Vector2 = Grid.origin(Vector2i(1, 0)) - Grid.origin(Vector2i.ZERO)
	var step_y: Vector2 = Grid.origin(Vector2i(0, 1)) - Grid.origin(Vector2i.ZERO)
	_assert(step_x == Vector2(Grid.CELL, 0.0), "가로 한 칸은 화면 가로로만 간다: %s" % step_x)
	_assert(step_y == Vector2(0.0, Grid.CELL), "세로 한 칸은 화면 세로로만 간다: %s" % step_y)
	_assert(is_zero_approx(step_x.dot(step_y)), "두 축은 직교한다 (마름모가 아니다)")
	var rect: Rect2 = Grid.rect_px(Rect2i(Vector2i(2, 3), Vector2i(4, 4)))
	_assert(rect == Rect2(Vector2(32, 48), Vector2(64, 64)), "칸 사각형은 화면 사각형이다: %s" % rect)

func _test_round_trip() -> void:
	var bad := 0
	for y in range(-40, 41, 3):
		for x in range(-40, 41, 3):
			var cell := Vector2i(x, y)
			if Grid.cell_at(Grid.centre(cell)) != cell:
				bad += 1
			# Every pixel of a cell answers with that cell, negatives included.
			if Grid.cell_at(Grid.origin(cell) + Vector2(0.01, 0.01)) != cell:
				bad += 1
			if Grid.cell_at(Grid.origin(cell) + Vector2(15.99, 15.99)) != cell:
				bad += 1
	_assert(bad == 0, "칸 <-> 픽셀이 음수 좌표까지 왕복한다 (%d건 어긋남)" % bad)

## A tile of distance is a block of SCALE x SCALE cells, lying exactly where the
## old cell lay.
func _test_tiles_are_blocks() -> void:
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(-3, 5), Vector2i(7, -2)]:
		var block: Rect2i = Grid.tile_rect(tile)
		_assert(block.size == Vector2i(2, 2), "옛 칸 %s 은 새 칸 2x2 다" % tile)
		_assert(Grid.rect_px(block) == Rect2(Vector2(tile) * 32.0, Vector2(32, 32)),
			"그리고 같은 자리 같은 크기다")
		_assert(Grid.rect_centre(block) == Grid.tile_centre(tile), "가운데도 같다")
		for cell: Vector2i in Grid.cells_in(block):
			_assert(Grid.tile_of(cell) == tile, "그 네 칸은 모두 그 타일에 속한다 %s" % cell)

func _test_footprints() -> void:
	# The default anchor: top-left of the middle two-by-two for even sizes.
	_assert(Grid.default_anchor(Vector2i(8, 8)) == Vector2i(3, 3), "8x8 의 앵커는 (3,3)")
	_assert(Grid.default_anchor(Vector2i(4, 4)) == Vector2i(1, 1), "4x4 의 앵커는 (1,1)")
	_assert(Grid.default_anchor(Vector2i(6, 8)) == Vector2i(2, 3), "6x8 의 앵커는 (2,3)")
	_assert(Grid.default_anchor(Vector2i.ONE) == Vector2i.ZERO, "1x1 은 자기 자신")
	var rect: Rect2i = Grid.footprint(Vector2i(10, 10), Vector2i(4, 4))
	_assert(rect == Rect2i(Vector2i(9, 9), Vector2i(4, 4)), "앵커에서 발자국이 나온다: %s" % rect)
	_assert(Grid.cells_in(rect).size() == 16, "발자국의 칸을 전부 센다")
	# Rotation-ready: a 4x6 lies down as 6x4 facing north or south.
	_assert(Grid.rotated(Vector2i(4, 6), Vector2i.RIGHT) == Vector2i(4, 6), "동쪽이면 그대로")
	_assert(Grid.rotated(Vector2i(4, 6), Vector2i.DOWN) == Vector2i(6, 4), "돌리면 6x4")
	_assert(Grid.footprint(Vector2i.ZERO, Vector2i(4, 6), Vector2i.UP).size == Vector2i(6, 4),
		"발자국도 돌아간다")
	# An explicit anchor turns with the building.
	var local := Vector2i(0, 1)
	var turned: Vector2i = Grid.rotate_local(local, Vector2i(4, 6), Vector2i.DOWN)
	var east: Rect2i = Grid.footprint(Vector2i(20, 20), Vector2i(4, 6), Vector2i.RIGHT, local)
	var south: Rect2i = Grid.footprint(Vector2i(20, 20), Vector2i(4, 6), Vector2i.DOWN, local)
	_assert(east.has_point(Vector2i(20, 20)) and south.has_point(Vector2i(20, 20)),
		"앵커 칸은 어느 방향이든 발자국 안이다")
	_assert(south.position + turned == Vector2i(20, 20), "돌린 앵커 자리에 앵커가 온다")
	# Output: past the front edge, in the anchor's line.
	var post: Rect2i = Grid.footprint(Vector2i(10, 10), Vector2i(4, 4))
	_assert(Grid.front_cell(post, Vector2i.RIGHT, Vector2i(10, 10)) == Vector2i(13, 10), "동쪽 출구")
	_assert(Grid.front_cell(post, Vector2i.LEFT, Vector2i(10, 10)) == Vector2i(8, 10), "서쪽 출구")
	_assert(Grid.front_cell(post, Vector2i.UP, Vector2i(10, 10)) == Vector2i(10, 8), "북쪽 출구")
	_assert(Grid.front_cell(post, Vector2i.DOWN, Vector2i(10, 10)) == Vector2i(10, 13), "남쪽 출구")

## What she can reach is a tile deep and a tile wide -- the ground the old front
## cell covered -- in cells.
func _test_reach_is_a_tile() -> void:
	var at: Vector2 = Grid.centre(Vector2i(5, 5)) + Vector2(3.0, 2.0)
	var probe: Array[Vector2i] = Grid.probe(at, Vector2i.RIGHT)
	_assert(probe.size() == 4, "앞의 네 칸 (2깊이 x 2줄)")
	var span := Rect2i(probe[0], Vector2i.ONE)
	for cell: Vector2i in probe:
		span = span.expand(cell).expand(cell + Vector2i.ONE)
	_assert(span.size == Vector2i(2, 2), "그 네 칸이 타일 하나의 넓이다: %s" % span.size)
	_assert(probe[0] == Vector2i(6, 5), "가장 가까운 것은 바로 앞 칸이다")
	var block: Array[Vector2i] = Grid.near_block(at)
	_assert(block.size() == 4, "발밑은 2x2 칸")
	_assert(block[0] == Vector2i(5, 5), "가장 가까운 것은 그녀가 선 칸")

## `Defs.TILE` meant a cell and a distance at once. It is gone, so neither can be
## reached through it again.
func _test_no_second_tile_constant() -> void:
	var constants: Dictionary = (load("res://scripts/Defs.gd") as GDScript).get_script_constant_map()
	_assert(not constants.has("TILE"), "Defs.TILE 은 없다 — 칸과 거리를 한 이름이 뜻하지 않는다")
	var grid_constants: Dictionary = (load("res://scripts/Grid.gd") as GDScript).get_script_constant_map()
	_assert(grid_constants.has("CELL") and grid_constants.has("TILE"), "Grid 가 둘을 따로 가진다")
