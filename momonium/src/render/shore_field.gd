class_name ShoreField
extends RefCounted

## A small greyscale texture of "how close is land", in logical tile space:
## 1 on owned cells, 0.5 on the coastline, falling to 0 about a tile out.
## The ocean shader reads it for shallows and foam, so the coast's cost does
## not grow with the island -- a thousand cells is still one texture lookup.
##
## Built when land changes: one texel per tile of coverage, then a native cubic
## upscale (the smoothing is the interpolation itself), so even a 100x100
## island rebuilds in a few milliseconds. Capped at MAX_SIZE texels a side;
## a huge island just gets fewer texels per tile.
##
## Step 63: a City's bank reaches `apron` tiles into the water, so its coast
## -- where the field is 0.5 and the foam sits -- is that much further out.
## That field is built from the true distance to the land instead -- the
## Village's own fall (about 0.45 at the coast, gone 0.4 tile out), moved out
## by the apron, so the foam and shallows look as they did, at the bank's
## foot, round at outer corners as the bank is. A Village's field is built as it
## always was.

const TEXELS_PER_TILE := 8
const MARGIN_TILES := 3
const MAX_SIZE := 512

var texture: ImageTexture
var image: Image
## Logical origin (x, y) and size (w, h) the texture covers.
var rect := Rect2()
var texels_per_tile := TEXELS_PER_TILE


func build(world: WorldSystem, apron: float = 0.0) -> void:
	if apron > 0.0:
		_build_apron(world, apron)
		return
	var b := world.bounds()
	var origin := b.position - Vector2i(MARGIN_TILES, MARGIN_TILES)
	var tiles := b.size + Vector2i(MARGIN_TILES * 2, MARGIN_TILES * 2)
	var coverage := Image.create(tiles.x, tiles.y, false, Image.FORMAT_L8)
	for cell: Vector2i in world.land:
		coverage.set_pixel(cell.x - origin.x, cell.y - origin.y, Color.WHITE)
	texels_per_tile = maxi(2, mini(TEXELS_PER_TILE, MAX_SIZE / maxi(tiles.x, tiles.y)))
	coverage.resize(tiles.x * texels_per_tile, tiles.y * texels_per_tile, Image.INTERPOLATE_CUBIC)
	image = coverage
	if texture == null or texture.get_width() != image.get_width() or texture.get_height() != image.get_height():
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	rect = Rect2(Vector2(origin), Vector2(tiles))


## The field from the distance to the land, `apron` further out: computed at
## DIST_TEXELS a tile near the coast only (the rest is 1 on land, 0 at sea),
## then the same cubic upscale.
const DIST_TEXELS := 4
const FALL_AT_COAST := 0.45
const FALL_PER_TILE := 1.12


func _build_apron(world: WorldSystem, apron: float) -> void:
	var b := world.bounds()
	var origin := b.position - Vector2i(MARGIN_TILES, MARGIN_TILES)
	var tiles := b.size + Vector2i(MARGIN_TILES * 2, MARGIN_TILES * 2)
	var n := DIST_TEXELS
	var field := Image.create(tiles.x * n, tiles.y * n, false, Image.FORMAT_L8)
	for cell: Vector2i in world.land:
		field.fill_rect(Rect2i((cell - origin) * n, Vector2i(n, n)), Color.WHITE)
	# Only the water cells within reach of the land have a fall to compute.
	var reach := int(ceil(apron + 1.0))
	var done := {}
	for cell: Vector2i in world.land:
		if _inland(world, cell):
			continue
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				var w := cell + Vector2i(dx, dy)
				if done.has(w) or world.is_owned(w):
					continue
				done[w] = true
				var near: Array[Vector2i] = []
				for ax in range(-reach, reach + 1):
					for ay in range(-reach, reach + 1):
						if world.is_owned(w + Vector2i(ax, ay)):
							near.append(w + Vector2i(ax, ay))
				for ty in n:
					for tx in n:
						var p := Vector2(w) + (Vector2(tx, ty) + Vector2(0.5, 0.5)) / n
						var d := IslandRenderer._distance_to(p, near)
						# The Village's fall (measured off its field: 0.42 at the
						# coast, gone 0.4 tile out), moved out by the apron.
						var v := clampf(FALL_AT_COAST - FALL_PER_TILE * (d - apron), 0.0, 1.0)
						if v > 0.0:
							field.set_pixel((w.x - origin.x) * n + tx, (w.y - origin.y) * n + ty, Color(v, v, v))
	texels_per_tile = maxi(2, mini(TEXELS_PER_TILE, MAX_SIZE / maxi(tiles.x, tiles.y)))
	field.resize(tiles.x * texels_per_tile, tiles.y * texels_per_tile, Image.INTERPOLATE_CUBIC)
	image = field
	if texture == null or texture.get_width() != image.get_width() or texture.get_height() != image.get_height():
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	rect = Rect2(Vector2(origin), Vector2(tiles))


## Land on every side (8 neighbours): no water within reach of it to compute.
static func _inland(world: WorldSystem, cell: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if not world.is_owned(cell + Vector2i(dx, dy)):
				return false
	return true


## Field value at a logical point (tests and tools; the shader samples the texture).
func sample(logical: Vector2) -> float:
	var uv := (logical - rect.position) / rect.size
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return 0.0
	return image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height())).r
