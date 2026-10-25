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

const TEXELS_PER_TILE := 8
const MARGIN_TILES := 3
const MAX_SIZE := 512

var texture: ImageTexture
var image: Image
## Logical origin (x, y) and size (w, h) the texture covers.
var rect := Rect2()
var texels_per_tile := TEXELS_PER_TILE


func build(world: WorldSystem) -> void:
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


## Field value at a logical point (tests and tools; the shader samples the texture).
func sample(logical: Vector2) -> float:
	var uv := (logical - rect.position) / rect.size
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return 0.0
	return image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height())).r
