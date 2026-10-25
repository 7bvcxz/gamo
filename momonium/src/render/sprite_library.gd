class_name SpriteLibrary
extends RefCounted

## Runtime access to the sprite atlas built by tools/art/build_atlas.gd.
##
## A sprite is a region of one atlas texture plus named pivots in pixels
## relative to that region. `place` positions a Sprite2D so that a pivot (by
## default `origin`, where the thing touches the ground) sits at the node's
## position -- callers place things by where they stand, never by their
## top-left corner, which is what keeps depth sorting and tile alignment right.

const DEFAULT_ATLAS := "res://assets/atlas/sprites"

var texture: Texture2D
var sprites: Dictionary = {}
var size: Vector2i


static func load_atlas(base_path: String = DEFAULT_ATLAS) -> SpriteLibrary:
	var lib := SpriteLibrary.new()
	lib.texture = load(base_path + ".png")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base_path + ".json"))
	lib.sprites = meta.get("sprites", {})
	var s: Array = meta.get("size", [0, 0])
	lib.size = Vector2i(int(s[0]), int(s[1]))
	return lib


func has(name: String) -> bool:
	return sprites.has(name)


func region(name: String) -> Rect2:
	var r: Array = sprites[name]["region"]
	return Rect2(r[0], r[1], r[2], r[3])


func pivot(name: String, pivot_name: String = "origin") -> Vector2:
	var p: Array = sprites[name]["pivots"].get(pivot_name, [0, 0])
	return Vector2(p[0], p[1])


## Texels per world pixel are fixed by the source scale; this is the node scale
## that draws the sprite at its intended world size.
func world_scale(name: String) -> float:
	return float(sprites[name].get("world_scale", 1.0))


## Free-form data the manifest attached to a sprite (e.g. a rig part's joint
## position in its source frame).
func meta(name: String) -> Dictionary:
	return sprites[name].get("meta", {})


## Texels per source unit the sprite was rasterised at.
func source_scale(name: String) -> float:
	return float(sprites[name].get("scale", 1.0))


func atlas_texture(name: String) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = texture
	t.region = region(name)
	return t


## Configures `sprite` to draw `name` with `pivot_name` at its position.
func place(sprite: Sprite2D, name: String, pivot_name: String = "origin") -> void:
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region(name)
	sprite.centered = false
	sprite.offset = -pivot(name, pivot_name)
	var s := world_scale(name)
	sprite.scale = Vector2(s, s)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func make_sprite(name: String, pivot_name: String = "origin") -> Sprite2D:
	var sprite := Sprite2D.new()
	place(sprite, name, pivot_name)
	return sprite
