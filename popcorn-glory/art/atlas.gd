class_name PopAtlas
extends RefCounted

## The sprite atlas made by tools/build_atlas.gd from the hand-written SVGs in
## art_src/: one texture, so every popcorn piece, coin and kernel on screen is
## drawn from the same image (one texture keeps the renderer's batches whole).
## If the atlas is missing the callers fall back to their shapes.

const PNG := "res://assets/atlas/sprites.png"
const JSON_PATH := "res://assets/atlas/sprites.json"

## The texture is held here. A version that called load() at each draw, with
## nothing holding the result, drew every sprite as a WHITE SQUARE: the texture
## was freed as soon as the draw command was queued, and the canvas drew a
## dead texture (Step 04, caught in a capture; the 'resources still in use at
## exit' it was meant to fix came from sounds still playing in the capture
## tool, not from this).
static var _texture: Texture2D
static var _regions: Dictionary = {}
static var _loaded := false
static var _has_png := false


static func ready() -> bool:
	if not _loaded:
		_loaded = true
		_has_png = ResourceLoader.exists(PNG)
		if _has_png:
			_texture = load(PNG)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			for name: String in parsed["regions"]:
				var r: Array = parsed["regions"][name]["rect"]
				_regions[name] = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	return _texture != null and not _regions.is_empty()


static func texture() -> Texture2D:
	ready()
	return _texture


static func region(name: String) -> Rect2:
	ready()
	return _regions.get(name, Rect2())


static func has(name: String) -> bool:
	return ready() and _regions.has(name)


## Draws `name` centred on `p`, its larger side `size` pixels, untransformed.
static func draw(ci: CanvasItem, name: String, p: Vector2, size: float, modulate: Color = Color.WHITE) -> void:
	if not has(name):
		return
	var r := region(name)
	var k := size / maxf(r.size.x, r.size.y)
	var s := r.size * k
	ci.draw_texture_rect_region(texture(), Rect2(p - s / 2, s), r, modulate)
