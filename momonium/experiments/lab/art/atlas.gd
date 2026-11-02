class_name LabAtlas
extends RefCounted

## The game's sprite atlas (shared/atlas, a copy of momonium/assets/atlas):
## one texture, a region and pivots per sprite. `world_scale` is the size the
## game draws a sprite at beside a 128-pixel tile, so trees, rocks and houses
## keep the game's proportions to each other and to Momo.

const TEXTURE := preload("res://shared/atlas/sprites.png")
const DATA_PATH := "res://shared/atlas/sprites.json"

static var _sprites: Dictionary = {}
static var _cache: Dictionary = {}


static func sprites() -> Dictionary:
	if _sprites.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_sprites = (parsed as Dictionary)["sprites"]
	return _sprites


static func has(name: String) -> bool:
	return sprites().has(name)


static func texture(name: String) -> AtlasTexture:
	if _cache.has(name):
		return _cache[name]
	var r: Array = (sprites()[name] as Dictionary)["region"]
	var t := AtlasTexture.new()
	t.atlas = TEXTURE
	t.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	_cache[name] = t
	return t


## Where the sprite touches the ground (or its centre, for icons), in the
## region's pixels.
static func pivot(name: String) -> Vector2:
	var pivots: Dictionary = (sprites()[name] as Dictionary)["pivots"]
	var p: Array = pivots.get("origin", pivots.get("center", [0.0, 0.0]))
	return Vector2(float(p[0]), float(p[1]))


static func world_scale(name: String) -> float:
	return float((sprites()[name] as Dictionary).get("world_scale", 1.0))


static func size(name: String) -> Vector2:
	return texture(name).region.size
