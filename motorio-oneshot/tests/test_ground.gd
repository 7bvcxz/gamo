extends SceneTree

## The ground tiles: the atlas, and which of the sixteen a cell gets.
##
## None of this is visible in a screenshot at the size the game draws it. A
## region that runs half a pixel off the edge of the atlas shows as a hairline
## seam nobody attributes to arithmetic, and a variant hash that falls into
## stripes reads as "the artist repeated themselves" rather than as a bug.

var failures := 0

func _init() -> void:
	_atlas()
	_regions()
	_rock_mask()
	_rock_atlas()
	_rock_field()
	print("GROUND: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _atlas() -> void:
	var atlas: Texture2D = GroundLayer.TILE_ATLAS
	_check(atlas != null, "타일 아틀라스가 로드된다")
	if atlas == null:
		return
	_check(atlas.get_width() == atlas.get_height(), "아틀라스가 정사각형이다")
	var cell: int = atlas.get_width() / GroundLayer.TILE_COLUMNS
	_check(atlas.get_width() % GroundLayer.TILE_COLUMNS == 0,
		"폭이 열 수로 나누어떨어진다: %d / %d" % [atlas.get_width(), GroundLayer.TILE_COLUMNS])
	# A tile is 32 world pixels and the camera stops at 2.56, so 82 device pixels
	# is the most one is ever drawn at in ordinary play. The source has to cover
	# that without being paid for twice over.
	_check(cell == 64, "타일 한 칸이 64픽셀이다: %d" % cell)

## Regions inside the atlas, and the property that replaced variety.
##
## The floor is one continuous picture now, so what has to be true is not that
## sixteen variants all get used and none falls into stripes -- it is that a cell
## reads the part of the picture at its own coordinates. Everything else follows:
## neighbouring cells read neighbouring parts, which is why there is no seam, and
## the repeat is the field's own size rather than something a hash decided.
func _regions() -> void:
	var atlas: Texture2D = GroundLayer.TILE_ATLAS
	var size: float = float(atlas.get_width()) / float(GroundLayer.TILE_COLUMNS)
	var bounds := Rect2(0.0, 0.0, float(atlas.get_width()), float(atlas.get_height()))
	var seen: Dictionary[String, bool] = {}
	for y in GroundLayer.TILE_COLUMNS:
		for x in GroundLayer.TILE_COLUMNS:
			var region: Rect2 = GroundLayer.tile_region(Vector2i(x, y))
			_check(bounds.encloses(region), "%s 영역이 아틀라스 안이다: %s" % [Vector2i(x, y), region])
			_check(region.size == Vector2(size, size), "영역 크기가 한 칸이다: %s" % region)
			seen["%d,%d" % [int(region.position.x), int(region.position.y)]] = true
	_check(seen.size() == GroundLayer.TILE_COLUMNS * GroundLayer.TILE_COLUMNS,
		"16x16 자리를 전부 쓴다: %d" % seen.size())

	# Adjacent cells read adjacent parts of the field. This is the whole point:
	# the sixteen hashed variants were replaced because scrambling which patch
	# lands where is exactly what puts a seam between two cells.
	for cell: Vector2i in [Vector2i(3, 4), Vector2i(0, 0), Vector2i(15, 15)]:
		var here: Rect2 = GroundLayer.tile_region(cell)
		var right: Rect2 = GroundLayer.tile_region(cell + Vector2i(1, 0))
		var down: Rect2 = GroundLayer.tile_region(cell + Vector2i(0, 1))
		var wrapped: bool = cell.x == GroundLayer.TILE_COLUMNS - 1
		_check(wrapped or is_equal_approx(right.position.x, here.position.x + size),
			"%s 오른쪽 칸이 오른쪽 조각을 읽는다" % cell)
		var wrapped_down: bool = cell.y == GroundLayer.TILE_COLUMNS - 1
		_check(wrapped_down or is_equal_approx(down.position.y, here.position.y + size),
			"%s 아래 칸이 아래 조각을 읽는다" % cell)

	# Negative coordinates. The world has them, and `%` in GDScript keeps the
	# sign, so a plain modulo reads a negative offset -- off the atlas entirely,
	# which draws nothing at all rather than something slightly wrong.
	for pair: Array in [[Vector2i(-1, -1), Vector2i(15, 15)],
			[Vector2i(-16, -16), Vector2i(0, 0)], [Vector2i(-17, 3), Vector2i(15, 3)]]:
		_check(GroundLayer.tile_region(pair[0]) == GroundLayer.tile_region(pair[1]),
			"%s 와 %s 가 같은 조각을 읽는다" % [pair[0], pair[1]])
	for cell: Vector2i in [Vector2i(-1, -1), Vector2i(-40, 7), Vector2i(1000, -1000)]:
		_check(bounds.encloses(GroundLayer.tile_region(cell)),
			"%s 도 아틀라스 안을 읽는다" % cell)

## Boulders autotile, so which of the forty-seven a cell draws is decided by its
## neighbours. The mask is the part that can be wrong in a way nothing else
## catches: a bit in the wrong place still draws a rock tile, just not the one
## whose edges match the rock beside it.
func _rock_mask() -> void:
	var alone: Dictionary[Vector2i, bool] = {}
	alone[Vector2i(5, 5)] = true
	_check(GroundLayer.rock_mask(alone, Vector2i(5, 5)) == 0, "혼자면 마스크가 0")

	# One neighbour at a time, in the bit order the generated table was built
	# with. Written out rather than looped over ROCK_NEIGHBOURS, because looping
	# over the same list the code uses would only prove the list equals itself.
	var expected: Array = [
		[Vector2i(0, -1), 1], [Vector2i(1, 0), 2], [Vector2i(0, 1), 4],
		[Vector2i(-1, 0), 8], [Vector2i(1, -1), 16], [Vector2i(1, 1), 32],
		[Vector2i(-1, 1), 64], [Vector2i(-1, -1), 128],
	]
	for entry: Array in expected:
		var field: Dictionary[Vector2i, bool] = {}
		field[Vector2i(5, 5)] = true
		field[Vector2i(5, 5) + (entry[0] as Vector2i)] = true
		_check(GroundLayer.rock_mask(field, Vector2i(5, 5)) == int(entry[1]),
			"%s 이웃의 비트가 %d" % [entry[0], entry[1]])

	# A diagonal only counts when both of its orthogonals are rock -- a corner
	# touching only at a point has nothing to round off. The table folds that in,
	# so two masks that must look the same land on the same tile.
	_check(GroundLayer.rock_region(16) == GroundLayer.rock_region(0),
		"대각선만 있으면 고립된 타일과 같다")
	_check(GroundLayer.rock_region(1 | 2 | 16) != GroundLayer.rock_region(1 | 2),
		"두 직교 이웃이 다 있으면 대각선이 구분된다")
	for mask in 256:
		var region: Rect2 = GroundLayer.rock_region(mask)
		_check(region.size == Vector2(RockTiles.CELL, RockTiles.CELL),
			"마스크 %d 의 영역 크기" % mask)
	_check(GroundLayer.rock_region(-5) == GroundLayer.rock_region(0), "범위 밖은 0으로")
	_check(GroundLayer.rock_region(999) == GroundLayer.rock_region(255), "범위 위는 255로")

func _rock_atlas() -> void:
	var atlas: Texture2D = GroundLayer.ROCK_ATLAS
	_check(atlas != null, "돌 아틀라스가 로드된다")
	if atlas == null:
		return
	_check(atlas == RockTiles.ATLAS, "GroundLayer 가 생성된 표와 같은 아틀라스를 쓴다")
	_check(int(RockTiles.CELL) == 64, "돌 타일 한 칸이 64픽셀이다: %d" % int(RockTiles.CELL))
	_check(atlas.get_width() == RockTiles.ATLAS_COLUMNS * int(RockTiles.CELL),
		"아틀라스 폭이 열 수와 맞는다: %d" % atlas.get_width())
	var bounds := Rect2(0.0, 0.0, float(atlas.get_width()), float(atlas.get_height()))
	var seen: Dictionary[String, bool] = {}
	for mask in 256:
		var region: Rect2 = GroundLayer.rock_region(mask)
		_check(bounds.encloses(region), "마스크 %d 의 영역이 아틀라스 안이다: %s" % [mask, region])
		seen["%d,%d" % [int(region.position.x), int(region.position.y)]] = true
	# 47 distinct pictures out of 256 masks: that is what folding the diagonal
	# rule in buys, and if the table ever stopped folding it the count would rise.
	_check(seen.size() == 47, "서로 다른 타일이 47개다: %d" % seen.size())

## Where the boulders land. The two numbers the request pinned down were a
## twentieth of the ground and clumps of one to twelve, and neither is visible in
## a screenshot: a floor that is 2% rock and one that is 9% rock both look like
## "some rocks".
func _rock_field() -> void:
	var ground := GroundLayer.new()
	var span: int = 220
	ground._ensure_rock(Vector2i(-span / 2, -span / 2), Vector2i(span / 2, span / 2))
	var inside: Dictionary[Vector2i, bool] = {}
	for y in range(-span / 2, span / 2):
		for x in range(-span / 2, span / 2):
			if ground.is_rock(Vector2i(x, y)):
				inside[Vector2i(x, y)] = true
	var share: float = float(inside.size()) * 100.0 / float(span * span)
	_check(share >= 3.5 and share <= 6.5, "돌이 바닥의 5%% 안팎이다: %.1f%%" % share)

	var seen: Dictionary[Vector2i, bool] = {}
	var sizes: Array[int] = []
	var steps: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for cell: Vector2i in inside:
		if seen.has(cell):
			continue
		var queue: Array[Vector2i] = [cell]
		seen[cell] = true
		var count: int = 0
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			count += 1
			for step: Vector2i in steps:
				var next: Vector2i = at + step
				if inside.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		sizes.append(count)
	sizes.sort()
	var median: int = sizes[sizes.size() / 2]
	_check(sizes.size() > 80, "덩어리가 충분히 많다: %d개" % sizes.size())
	_check(median >= 2 and median <= 12, "덩어리 중앙값이 1~12 안이다: %d" % median)
	var over: int = 0
	for size: int in sizes:
		if size > 12:
			over += 1
	# Clumps from neighbouring blocks can touch and merge. That is not a bug, but
	# a field where it is the norm is not "clumps of one to twelve" any more.
	_check(float(over) / float(sizes.size()) < 0.2,
		"12칸을 넘는 덩어리는 드물다: %d / %d (최대 %d)"
		% [over, sizes.size(), sizes[sizes.size() - 1]])

	# What a real field asks the tileset for. A blob set is only worth having if
	# the shapes it draws are the shapes that occur, and this is the one place
	# that can answer: 220 squares of actual boulders, every mask they produce.
	var used: Dictionary[int, bool] = {}
	for cell: Vector2i in inside:
		used[GroundLayer.rock_mask(ground._rock, cell)] = true
	var pictures: Dictionary[String, bool] = {}
	for mask: int in used:
		var region: Rect2 = GroundLayer.rock_region(mask)
		pictures["%d,%d" % [int(region.position.x), int(region.position.y)]] = true
	# Not all 47 -- some configurations need a clump shape this generator does
	# not make -- but far more than the six unrelated stamps this replaced, and
	# the edge cases have to be among them or clumps would have no outline.
	_check(pictures.size() >= 20,
		"실제 지형이 요구하는 타일이 충분히 많다: %d종" % pictures.size())
	_check(used.has(0), "고립된 바위가 나온다")
	print("GROUND: 마스크 %d종 · 그림 %d종" % [used.size(), pictures.size()])
	print("GROUND: 돌 %.1f%% · 덩어리 %d개 · 중앙값 %d · 최대 %d"
		% [share, sizes.size(), median, sizes[sizes.size() - 1]])
	ground.free()

	# --- Every ore that has a sheet draws from it -------------------------------
	# Crystal moved to a tile first and copper kept the painted shard for a
	# version, which is the state this checks against: an ore in the world must
	# have a sheet, or its seams are a hole in the floor that only shows up on a
	# map where that ore happens to be near the camera.
	var world := Sim.new()
	world.setup(4242)
	var ore_kinds: Dictionary[int, bool] = {}
	for cell: Vector2i in world.ore:
		var kind: int = int(world.ore[cell])
		ore_kinds[kind] = true
		var atlas: Texture2D = GroundLayer.ore_atlas_at(world, cell)
		_check(atlas != null, "%s 광맥에 시트가 있다" % Defs.ITEM_NAMES[kind])
		if atlas != null:
			_check(atlas.get_width() == GroundLayer.ORE_COLUMNS * 64,
				"시트가 3열 64px이다: %d" % atlas.get_width())
	_check(ore_kinds.has(Defs.ITEM_CRYSTAL) and ore_kinds.has(Defs.ITEM_COPPER),
		"월드에 수정과 구리가 모두 있다")
	_check(GroundLayer.ore_atlas_at(world, Vector2i(9999, 9999)) == null,
		"광맥이 없는 칸은 시트도 없다")
	var variants: Dictionary[int, bool] = {}
	for vx in range(-40, 40):
		for vy in range(-40, 40):
			variants[GroundLayer.ore_variant(Vector2i(vx, vy))] = true
	_check(variants.size() == GroundLayer.ORE_VARIANTS,
		"광맥 여섯 변형이 모두 나온다 (%d)" % variants.size())
	world.free()

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	print("  FAIL: ", message)
	failures += 1
