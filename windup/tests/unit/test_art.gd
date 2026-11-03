extends "res://tests/framework/test_case.gd"

## The art the game ships (design/ART_GUIDE.md): every file imports, at the
## size the view expects; and the raster route's processing (build_art.gd)
## keys green and splits a storyboard into its poses.

const BuildArt := preload("res://tools/art/build_art.gd")


func test_every_art_file_imports_at_its_size() -> void:
	var expect := {
		"res://assets/art/backdrop.svg": Vector2i(1440, 960),
		"res://assets/art/key.svg": Vector2i(256, 256),
		"res://assets/art/doll/atlas.svg": Vector2i(556, 144),
	}
	for path: String in expect:
		var tex: Texture2D = load(path)
		assert_true(tex != null, "loads " + path)
		if tex != null:
			assert_eq(Vector2i(tex.get_size()), expect[path], "size of " + path)
	assert_true(DollRig.art_present(), "doll atlas present")
	var parts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DollRig.ATLAS_JSON))["parts"]
	for p: String in ["head", "torso", "arm", "leg", "back_key", "eye_closed", "eye_half", "eye_open"]:
		assert_true(parts.has(p), "atlas has " + p)


func test_atlas_is_built_from_the_sources() -> void:
	# The atlas is generated from art/svg/doll/ (node windup/tools/art/build_doll_atlas.mjs):
	# a source added or removed without rebuilding shows up here.
	assert_true(FileAccess.get_file_as_string(DollRig.ATLAS).contains("GENERATED"), "atlas.svg is the generated file")
	var parts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DollRig.ATLAS_JSON))["parts"]
	var sources: Array[String] = []
	for f: String in DirAccess.get_files_at("res://art/svg/doll"):
		if f.ends_with(".svg"):
			sources.append(f.get_basename())
	sources.sort()
	var names: Array[String] = []
	for k: String in parts:
		names.append(k)
	names.sort()
	assert_eq(names, sources, "atlas parts == source files")


func test_green_keys_out_and_figure_stays() -> void:
	var img := Image.create(40, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color8(2, 250, 3))
	img.fill_rect(Rect2i(10, 5, 8, 10), Color8(200, 60, 70))
	BuildArt._key_green(img)
	assert_eq(img.get_pixel(1, 1).a, 0.0, "green is clear")
	assert_eq(img.get_pixel(12, 8).a, 1.0, "figure is opaque")
	assert_true(img.get_pixel(12, 8).r > 0.7, "figure colour kept")


func test_storyboard_splits_into_poses() -> void:
	var img := Image.create(400, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color8(0, 255, 0))
	# Three figures of different heights, one with a detached raised hand.
	img.fill_rect(Rect2i(20, 40, 50, 60), Color8(120, 40, 50))
	img.fill_rect(Rect2i(150, 20, 40, 80), Color8(120, 40, 50))
	img.fill_rect(Rect2i(280, 10, 60, 90), Color8(120, 40, 50))
	img.fill_rect(Rect2i(300, 0, 8, 6), Color8(220, 180, 140))
	BuildArt._key_green(img)
	var parts: Array[Rect2i] = BuildArt._split_columns(img)
	assert_eq(parts.size(), 3, "three poses")
	if parts.size() == 3:
		assert_eq(parts[0], Rect2i(20, 40, 50, 60), "first pose box")
		assert_eq(parts[2].position.y, 0, "the raised hand belongs to the third pose")
