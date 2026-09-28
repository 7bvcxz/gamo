extends SceneTree

## The snow floor: four variants of one ground, cut as a 2x2 atlas
## (World Visual Pass 01).
##
##     godot --headless --path motorio --script res://tools/art/build_snow.gd
##
## Writes assets/tiles/snow_4.png. Deterministic: the same script writes the
## same bytes, so the picture is reproducible from this file and nothing else.
##
## What the floor has to be, from the brief and from how it is drawn:
##
## * It is drawn *multiplied* over the fire's pool and the cold fill
##   (GroundLayer), so the colour comes from them and this art only darkens where
##   the snow has shape. White is "no change"; the whole tile sits a breath under
##   it with a faint blue cast, so the ground reads bright, slightly blue and
##   soft.
## * Low contrast and soft grain: a few percent either way, nothing a player
##   reads as an object -- no stones, no footprints, no blotches (the last floor
##   had all three, and a border that drew the grid on the snow).
## * One ground, four faces, in any order with no seam. Every variant is the
##   same periodic base field at its edges and only differs in the middle: the
##   difference is faded in by a window that is zero on the border. So every
##   edge of every variant is the base's edge, and the base tiles with itself.
## * Drawn a cell (16 px) across from 64 px, so the grain is laid down at four
##   pixels and up -- a single-pixel speck is a quarter of a screen pixel and
##   would only shimmer.

const SIZE := 64
const COLUMNS := 2
const VARIANTS := 4
const OUT := "res://assets/tiles/snow_4.png"

## Multiplied colour at "flat snow": a breath under white, a touch cooler in red
## and green than in blue.
const BASE := Color(0.972, 0.980, 1.0)
## How far the shape moves it, either way. Low contrast is the brief.
const BASE_SWING := 0.012
const DETAIL_SWING := 0.03
## The border band, in pixels, where every variant is the base and nothing else.
const EDGE := 6.0

func _initialize() -> void:
	var atlas := Image.create(SIZE * COLUMNS, SIZE * COLUMNS, false, Image.FORMAT_RGB8)
	var base: PackedFloat32Array = _periodic_field(7001, [1, 2, 4], [0.55, 0.30, 0.15])
	for variant in VARIANTS:
		var detail: PackedFloat32Array = _periodic_field(8100 + variant * 37, [3, 5, 8], [0.45, 0.35, 0.20])
		var rng := RandomNumberGenerator.new()
		rng.seed = 9900 + variant
		var glints: Array[Vector2] = []
		for index in 3 + variant % 2:
			glints.append(Vector2(rng.randf_range(EDGE + 4.0, SIZE - EDGE - 4.0),
				rng.randf_range(EDGE + 4.0, SIZE - EDGE - 4.0)))
		var origin := Vector2i((variant % COLUMNS) * SIZE, (variant / COLUMNS) * SIZE)
		for y in SIZE:
			for x in SIZE:
				var window: float = _window(float(x) + 0.5) * _window(float(y) + 0.5)
				var value: float = base[y * SIZE + x] * BASE_SWING
				# The variant's own low grain, faded in from the border. No ripples,
				# no stripes: anything regular inside a tile repeats every cell, and
				# a floor that repeats every sixteen pixels is a pattern, not snow.
				value += window * detail[y * SIZE + x] * DETAIL_SWING
				# A few soft glints: bright, small, and blurred over five pixels, so
				# they are a catch of light and not a speck.
				for glint: Vector2 in glints:
					var d: float = glint.distance_to(Vector2(x, y))
					if d < 3.0:
						value += window * 0.012 * (1.0 - d / 3.0)
				var shade := Color(
					clampf(BASE.r + value, 0.0, 1.0),
					clampf(BASE.g + value, 0.0, 1.0),
					clampf(BASE.b + value * 0.6, 0.0, 1.0))
				atlas.set_pixel(origin.x + x, origin.y + y, shade)
	var error: int = atlas.save_png(ProjectSettings.globalize_path(OUT))
	print("SNOW: %s (%d)" % [OUT, error])
	quit(error)

## 0 on the border, rising smoothly to 1 at EDGE pixels in.
static func _window(at: float) -> float:
	var inside: float = minf(at, float(SIZE) - at)
	var t: float = clampf(inside / EDGE, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Value noise that tiles with itself every SIZE pixels: a sum of octaves, each a
## grid of random values `freq` cells across, wrapped, and smoothly interpolated.
## Roughly -1..1.
static func _periodic_field(seed_value: int, frequencies: Array, weights: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for octave in frequencies.size():
		var freq: int = int(frequencies[octave])
		var weight: float = float(weights[octave])
		var grid := PackedFloat32Array()
		grid.resize(freq * freq)
		for index in freq * freq:
			grid[index] = rng.randf_range(-1.0, 1.0)
		for y in SIZE:
			for x in SIZE:
				var fx: float = float(x) / float(SIZE) * float(freq)
				var fy: float = float(y) / float(SIZE) * float(freq)
				var x0: int = int(floor(fx)) % freq
				var y0: int = int(floor(fy)) % freq
				var x1: int = (x0 + 1) % freq
				var y1: int = (y0 + 1) % freq
				var tx: float = _smooth(fx - floor(fx))
				var ty: float = _smooth(fy - floor(fy))
				var top: float = lerpf(grid[y0 * freq + x0], grid[y0 * freq + x1], tx)
				var bottom: float = lerpf(grid[y1 * freq + x0], grid[y1 * freq + x1], tx)
				out[y * SIZE + x] += lerpf(top, bottom, ty) * weight
	return out

static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
