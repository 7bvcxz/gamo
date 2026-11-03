extends "res://tests/framework/test_case.gd"

## Asset and memory budgets (Step 03 V2): the textures the game loads, and the
## source art kept small. A budget that grows must be raised on purpose, here.

const TEXTURE_BUDGET_BYTES := 12 * 1024 * 1024   # decoded RGBA8, all game textures
const SOURCE_BUDGET_BYTES := 64 * 1024           # every SVG source together


func test_decoded_texture_memory_is_within_budget() -> void:
	var total := 0
	var lines: Array[String] = []
	for path: String in ["res://assets/art/backdrop.svg", "res://assets/art/key.svg", "res://assets/art/gear_big.svg",
			"res://assets/art/gear_small.svg", "res://assets/art/doll/atlas.svg"]:
		var t: Texture2D = load(path)
		var bytes := t.get_width() * t.get_height() * 4
		total += bytes
		lines.append("%s %dx%d %d KB" % [path.get_file(), t.get_width(), t.get_height(), bytes / 1024])
	print("  textures: %s = %d KB" % [", ".join(lines), total / 1024])
	assert_true(total <= TEXTURE_BUDGET_BYTES, "decoded textures %d KB <= %d KB" % [total / 1024, TEXTURE_BUDGET_BYTES / 1024])


func test_source_art_is_small() -> void:
	var total := 0
	for dir: String in ["res://assets/art", "res://assets/art/doll", "res://art/svg/doll"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".svg"):
				total += FileAccess.get_file_as_bytes(dir.path_join(f)).size()
	assert_true(total <= SOURCE_BUDGET_BYTES, "SVG sources %d KB <= %d KB" % [total / 1024, SOURCE_BUDGET_BYTES / 1024])
