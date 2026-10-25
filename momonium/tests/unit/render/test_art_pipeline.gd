extends "res://tests/framework/test_case.gd"

## The atlas is built from its sources, fits the mobile budgets, and every
## sprite carries the pivots the renderers rely on.

var manifest: Dictionary
var atlas: Dictionary
var budgets: Dictionary


func before_each() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	atlas = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlas/sprites.json"))
	budgets = GameData.load_default().table("art")["budgets"]


func test_atlas_is_up_to_date_with_sources() -> void:
	for name: String in manifest["sprites"]:
		assert_true(atlas["sprites"].has(name), "%s is in the built atlas (run tools/art/build_atlas.gd)" % name)
		if not atlas["sprites"].has(name):
			continue
		var svg := FileAccess.get_file_as_string("res://assets/src/" + manifest["sprites"][name]["source"])
		assert_eq(atlas["sprites"][name]["source_sha"], svg.sha256_text().substr(0, 16), "%s atlas matches its SVG (rebuild the atlas)" % name)
	for name: String in atlas["sprites"]:
		assert_true(manifest["sprites"].has(name), "%s in the atlas has a source" % name)


func test_atlas_fits_the_budget() -> void:
	var size: Array = atlas["size"]
	assert_true(int(size[0]) <= int(budgets["atlas_max_size"]) and int(size[1]) <= int(budgets["atlas_max_size"]), "atlas %s within %d" % [size, budgets["atlas_max_size"]])
	var texture: Texture2D = load("res://assets/atlas/sprites.png")
	assert_eq(Vector2i(texture.get_width(), texture.get_height()), Vector2i(int(size[0]), int(size[1])), "png matches json size")
	var total_bytes := texture.get_width() * texture.get_height() * 4
	for path: String in _textures():
		var t: Texture2D = load(path)
		assert_true(t.get_width() <= int(budgets["texture_max_size"]) and t.get_height() <= int(budgets["texture_max_size"]), "%s within %d" % [path, budgets["texture_max_size"]])
		total_bytes += t.get_width() * t.get_height() * 4
	assert_true(total_bytes <= int(budgets["atlas_total_mb"]) * 1024 * 1024, "texture memory %d bytes within budget" % total_bytes)


func test_pivots_are_inside_their_sprite() -> void:
	for name: String in atlas["sprites"]:
		var s: Dictionary = atlas["sprites"][name]
		var r: Array = s["region"]
		for pivot: String in s["pivots"]:
			var p: Array = s["pivots"][pivot]
			# A pivot may sit a few pixels outside the trimmed art (feet resting on it).
			assert_between(float(p[0]), -8.0, float(r[2]) + 8.0, "%s.%s x" % [name, pivot])
			assert_between(float(p[1]), -8.0, float(r[3]) + 8.0, "%s.%s y" % [name, pivot])


func test_world_sprites_have_an_origin() -> void:
	for name: String in manifest["sprites"]:
		var spec: Dictionary = manifest["sprites"][name]
		if spec.has("world_scale"):
			assert_true(spec["pivots"].has("origin"), "%s stands in the world, so it needs an origin pivot" % name)


func test_library_places_sprites_by_pivot() -> void:
	var lib := SpriteLibrary.load_atlas()
	var sprite := lib.make_sprite("momo_front")
	assert_eq(sprite.offset, -lib.pivot("momo_front", "origin"), "origin pivot sits at the node position")
	assert_true(sprite.region_enabled, "draws a region of the shared atlas")
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "downscaled art is filtered with mipmaps")
	sprite.free()


func test_imports_generate_mipmaps() -> void:
	# LINEAR_WITH_MIPMAPS without mipmaps silently falls back to plain linear.
	for path: String in ["res://assets/atlas/sprites.png"] + _textures():
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(path + ".import"), OK, "%s has import settings" % path)
		assert_true(bool(cfg.get_value("params", "mipmaps/generate", false)), "%s generates mipmaps" % path)


func test_ground_textures_wrap_seamlessly() -> void:
	# The step across the wrap edge should look like any other step.
	var img: Image = (load("res://assets/textures/grass.png") as Texture2D).get_image()
	img.decompress()
	var inner := 0.0
	var wrap := 0.0
	for y in img.get_height():
		inner += _diff(img.get_pixel(127, y), img.get_pixel(128, y))
		wrap += _diff(img.get_pixel(img.get_width() - 1, y), img.get_pixel(0, y))
	assert_true(wrap < inner * 2.5 + 1.0, "grass wraps horizontally (wrap %.1f vs inner %.1f)" % [wrap, inner])


func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _textures() -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at("res://assets/textures"):
		if f.ends_with(".png"):
			out.append("res://assets/textures/" + f)
	return out
