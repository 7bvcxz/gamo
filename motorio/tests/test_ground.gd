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
	_variants()
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
	_check(cell == 64, "타일 한 칸이 64픽셀이다: %d" % cell)
	# A tile is 32 world pixels and the camera stops at 2.56, so 82 device pixels
	# is the most one is ever drawn at in ordinary play. The source has to cover
	# that without being paid for twice over.
	_check(cell >= 64, "화면 최대 82px를 감당할 해상도다")
	_check(GroundLayer.TILE_VARIANTS
		== GroundLayer.TILE_COLUMNS * GroundLayer.TILE_COLUMNS,
		"변형 수가 4x4다: %d" % GroundLayer.TILE_VARIANTS)

## Every region inside the atlas, none overlapping, all the same size. The seam
## this guards against is a half-pixel one, so the arithmetic is what gets
## checked rather than the picture.
func _regions() -> void:
	var atlas: Texture2D = GroundLayer.TILE_ATLAS
	if atlas == null:
		return
	var bounds := Rect2(0.0, 0.0, float(atlas.get_width()), float(atlas.get_height()))
	var seen: Dictionary = {}
	var size: Vector2 = GroundLayer.tile_region(0).size
	for variant in GroundLayer.TILE_VARIANTS:
		var region: Rect2 = GroundLayer.tile_region(variant)
		_check(bounds.encloses(region),
			"%d번 영역이 아틀라스 안에 있다: %s" % [variant, region])
		_check(region.size.is_equal_approx(size), "%d번 영역 크기가 같다" % variant)
		var key: String = "%d,%d" % [int(region.position.x), int(region.position.y)]
		_check(not seen.has(key), "%d번 영역이 겹치지 않는다" % variant)
		seen[key] = true
	_check(seen.size() == GroundLayer.TILE_VARIANTS,
		"열여섯 자리를 전부 쓴다: %d" % seen.size())
	# Out of range clamps rather than reading past the atlas.
	_check(GroundLayer.tile_region(-5) == GroundLayer.tile_region(0), "범위 아래는 0번으로")
	_check(GroundLayer.tile_region(999)
		== GroundLayer.tile_region(GroundLayer.TILE_VARIANTS - 1), "범위 위는 마지막으로")

## The variant a cell gets. Three things matter and none of them show up in a
## still: it must be the same every time (the map is regenerated from a seed, not
## stored), it must use all sixteen, and it must not line up into stripes.
func _variants() -> void:
	var counts: Array[int] = []
	for _variant in GroundLayer.TILE_VARIANTS:
		counts.append(0)
	for y in range(-40, 40):
		for x in range(-40, 40):
			var variant: int = GroundLayer.tile_variant(Vector2i(x, y))
			_check(variant >= 0 and variant < GroundLayer.TILE_VARIANTS,
				"%s 칸의 변형 번호가 범위 안이다: %d" % [Vector2i(x, y), variant])
			counts[variant] += 1
	var used: int = 0
	var low: int = 999999
	var high: int = 0
	for count: int in counts:
		if count > 0:
			used += 1
		low = mini(low, count)
		high = maxi(high, count)
	_check(used == GroundLayer.TILE_VARIANTS, "6400칸에서 열여섯 변형이 모두 나온다: %d" % used)
	# Not a uniform distribution test -- a hash is allowed to be lumpy -- but a
	# variant that almost never appears is sixteen tiles' worth of art nobody sees.
	_check(low * 4 >= high, "가장 드문 변형도 가장 흔한 것의 4분의 1 이상이다: %d ~ %d" % [low, high])

	# Same answer every time, which is what makes the floor stable when the camera
	# comes back to it.
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(-7, 13), Vector2i(120, -85)]:
		var first: int = GroundLayer.tile_variant(cell)
		var stable := true
		for _repeat in 8:
			if GroundLayer.tile_variant(cell) != first:
				stable = false
		_check(stable, "%s 칸은 몇 번을 물어도 같은 변형이다: %d" % [cell, first])

	# Stripes: a row or a column that repeats one variant is what two even
	# multipliers produce immediately, and it reads as tiled wallpaper.
	for y in [-3, 0, 11]:
		var row: Dictionary = {}
		for x in range(0, 40):
			row[GroundLayer.tile_variant(Vector2i(x, y))] = true
		_check(row.size() >= 8, "y=%d 행이 한 변형으로 줄서지 않는다: %d종" % [y, row.size()])
	for x in [-3, 0, 11]:
		var column: Dictionary = {}
		for y in range(0, 40):
			column[GroundLayer.tile_variant(Vector2i(x, y))] = true
		_check(column.size() >= 8, "x=%d 열이 한 변형으로 줄서지 않는다: %d종" % [x, column.size()])

	# Periodicity, which "how many distinct variants" cannot see. The first hash
	# used all sixteen variants in every row and still laid them out as a lattice
	# that restarted every sixteen tiles -- 0, 13, 10, 7, 4, 1, and round again.
	# A repeating floor is the thing tile variety exists to prevent, so the
	# repeat itself is what gets tested.
	for period in [2, 4, 8, 16, 32]:
		for y in [-5, 0, 7]:
			var repeats: int = 0
			for x in range(0, 60):
				if GroundLayer.tile_variant(Vector2i(x, y)) \
						== GroundLayer.tile_variant(Vector2i(x + period, y)):
					repeats += 1
			_check(repeats < 45,
				"행이 %d칸마다 반복되지 않는다 (y=%d): 60칸 중 %d칸 일치" % [period, y, repeats])
		for x in [-5, 0, 7]:
			var down: int = 0
			for y in range(0, 60):
				if GroundLayer.tile_variant(Vector2i(x, y)) \
						== GroundLayer.tile_variant(Vector2i(x, y + period)):
					down += 1
			_check(down < 45,
				"열이 %d칸마다 반복되지 않는다 (x=%d): 60칸 중 %d칸 일치" % [period, x, down])

## The boulder atlas. Six tiles with no relationship to each other, so the only
## things that can be wrong are arithmetic: a region off the edge shows as a
## hairline of the neighbouring tile, and a variant nobody picks is art that
## never appears.
func _rock_atlas() -> void:
	var atlas: Texture2D = GroundLayer.ROCK_ATLAS
	_check(atlas != null, "돌 아틀라스가 로드된다")
	if atlas == null:
		return
	var cell: int = atlas.get_width() / GroundLayer.ROCK_COLUMNS
	_check(cell == 64, "돌 타일 한 칸이 64픽셀이다: %d" % cell)
	_check(atlas.get_width() == GroundLayer.ROCK_COLUMNS * cell
		and atlas.get_height() == cell * 2, "3x2 아틀라스다: %dx%d"
		% [atlas.get_width(), atlas.get_height()])
	var bounds := Rect2(0.0, 0.0, float(atlas.get_width()), float(atlas.get_height()))
	var seen: Dictionary = {}
	for variant in GroundLayer.ROCK_VARIANTS:
		var region: Rect2 = GroundLayer.rock_region(variant)
		_check(bounds.encloses(region), "%d번 돌 영역이 아틀라스 안이다: %s" % [variant, region])
		seen["%d,%d" % [int(region.position.x), int(region.position.y)]] = true
	_check(seen.size() == GroundLayer.ROCK_VARIANTS, "여섯 자리를 전부 쓴다: %d" % seen.size())
	_check(GroundLayer.rock_region(-3) == GroundLayer.rock_region(0), "범위 아래는 0번으로")
	_check(GroundLayer.rock_region(99)
		== GroundLayer.rock_region(GroundLayer.ROCK_VARIANTS - 1), "범위 위는 마지막으로")

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

	# Every one of the six appears, and no cell is left without a tile.
	var used: Dictionary[int, bool] = {}
	for cell: Vector2i in inside:
		var variant: int = GroundLayer.rock_variant(cell)
		_check(variant >= 0 and variant < GroundLayer.ROCK_VARIANTS,
			"%s 돌 변형이 범위 안이다: %d" % [cell, variant])
		used[variant] = true
	_check(used.size() == GroundLayer.ROCK_VARIANTS,
		"여섯 종류가 모두 쓰인다: %d" % used.size())
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
	# Crystal is not a seam any more -- it lies in the snow in a fixed number and
	# there is no way to make more, which is what a rare material is.
	_check(ore_kinds.has(Defs.ITEM_HEATSTONE) and ore_kinds.has(Defs.ITEM_COPPER),
		"월드에 열석과 구리 광맥이 모두 있다")
	_check(not ore_kinds.has(Defs.ITEM_CRYSTAL), "수정 광맥은 없다")
	_check(world.shards.size() == Defs.CRYSTAL_SHARDS,
		"수정 조각은 정확히 %d개 놓인다 (%d)" % [Defs.CRYSTAL_SHARDS, world.shards.size()])
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
