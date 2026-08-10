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

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	print("  FAIL: ", message)
	failures += 1
