extends "res://tests/framework/test_case.gd"

## Every script and scene in the game parses and loads. A file nothing has
## loaded yet can hide a parse error until the moment a player reaches it.


func test_every_script_compiles() -> void:
	var count := 0
	for path: String in _files("res://src", ".gd"):
		var script: Script = load(path)
		assert_true(script != null and script.can_instantiate(), "%s loads" % path)
		count += 1
	assert_true(count > 5, "found the game scripts (%d)" % count)


func test_every_scene_loads() -> void:
	for path: String in _files("res://scenes", ".tscn"):
		var packed: PackedScene = load(path)
		assert_true(packed != null and packed.can_instantiate(), "%s loads" % path)


func _files(dir_path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(_files(dir_path.path_join(sub), ext))
	for file: String in dir.get_files():
		if file.ends_with(ext):
			out.append(dir_path.path_join(file))
	return out
