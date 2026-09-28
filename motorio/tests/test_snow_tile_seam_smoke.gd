extends SceneTree

## No seam between any two snow tiles, in any order (World Visual Pass 01).
##
## Measured on the atlas itself, the way the floor is laid: every variant's
## right edge against every variant's left edge, and bottom against top, differ
## by less than the grain inside a tile. Then an 8x8 and a 16x16 floor are laid
## out with the game's own variant choice, and the steps across tile boundaries
## are no bigger than the steps inside tiles -- a seam or a drawn grid would
## show as boundary steps standing out. The 16x16 floor is written to
## user://snow_seam_16x16.png (and to --out, if given) to look at.
##
## Also the brief's "no big blotches": the whole tile stays within a few
## percent of its mean.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var atlas: Image = Image.load_from_file(ProjectSettings.globalize_path(GroundLayer.TILE_ATLAS.resource_path))
	_assert(atlas != null, "눈 아틀라스를 읽는다")
	if atlas != null:
		atlas.convert(Image.FORMAT_RGB8)
		_test_edges(atlas)
		_test_floor(atlas, 8)
		_test_floor(atlas, 16)
		_test_low_contrast(atlas)
	if failures == 0:
		print("PASS test_snow_tile_seam_smoke")
	else:
		print("FAIL test_snow_tile_seam_smoke (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _tile(atlas: Image, variant: int) -> Rect2i:
	var region: Rect2 = GroundLayer.tile_region(variant)
	return Rect2i(region)

func _luma(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114

func _test_edges(atlas: Image) -> void:
	var worst := 0.0
	for a in GroundLayer.TILE_VARIANTS:
		for b in GroundLayer.TILE_VARIANTS:
			var ra: Rect2i = _tile(atlas, a)
			var rb: Rect2i = _tile(atlas, b)
			for i in ra.size.y:
				var right: Color = atlas.get_pixel(ra.end.x - 1, ra.position.y + i)
				var left: Color = atlas.get_pixel(rb.position.x, rb.position.y + i)
				worst = maxf(worst, absf(_luma(right) - _luma(left)))
				var bottom: Color = atlas.get_pixel(ra.position.x + i, ra.end.y - 1)
				var top: Color = atlas.get_pixel(rb.position.x + i, rb.position.y)
				worst = maxf(worst, absf(_luma(bottom) - _luma(top)))
	_assert(worst <= 3.0 / 255.0, "어느 두 변형을 붙여도 이음매 차이가 3/255 이하 (%.1f/255)" % (worst * 255.0))

## Lays a floor of `n` by `n` cells from the game's own variant choice and
## compares the step across tile edges with the step inside tiles.
func _test_floor(atlas: Image, n: int) -> void:
	var size: int = int(GroundLayer.tile_region(0).size.x)
	var floor := Image.create(n * size, n * size, false, Image.FORMAT_RGB8)
	for cy in n:
		for cx in n:
			floor.blit_rect(atlas, _tile(atlas, GroundLayer.tile_variant(Vector2i(cx, cy) + Vector2i(37, -11))),
				Vector2i(cx * size, cy * size))
	var across := 0.0
	var across_n := 0
	var inside := 0.0
	var inside_n := 0
	for y in floor.get_height():
		for x in range(1, floor.get_width()):
			var step: float = absf(_luma(floor.get_pixel(x, y)) - _luma(floor.get_pixel(x - 1, y)))
			if x % size == 0:
				across += step
				across_n += 1
			else:
				inside += step
				inside_n += 1
	var mean_across: float = across / float(maxi(across_n, 1))
	var mean_inside: float = inside / float(maxi(inside_n, 1))
	_assert(mean_across <= mean_inside * 1.5 + 0.0005,
		"%dx%d: 타일 경계의 변화가 타일 안보다 크지 않다 (경계 %.4f, 안 %.4f)" % [n, n, mean_across, mean_inside])
	if n == 16:
		floor.save_png(ProjectSettings.globalize_path("user://snow_seam_16x16.png"))
		var args := OS.get_cmdline_user_args()
		for i in args.size():
			if args[i] == "--out" and i + 1 < args.size():
				floor.save_png(args[i + 1])

func _test_low_contrast(atlas: Image) -> void:
	var low := 1.0
	var high := 0.0
	for y in atlas.get_height():
		for x in atlas.get_width():
			var l: float = _luma(atlas.get_pixel(x, y))
			low = minf(low, l)
			high = maxf(high, l)
	_assert(high - low <= 0.12, "눈의 밝기 폭이 좁다 — 큰 얼룩이 없다 (%.3f)" % (high - low))
	_assert(low >= 0.85, "어두운 곳도 밝다 — 돌·발자국 같은 짙은 점이 없다 (%.3f)" % low)
