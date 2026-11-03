extends "res://tests/framework/test_case.gd"

## This game keeps to itself (README.md): no saves (on the web user:// is one
## folder for every Godot game on the origin), no browser storage outside
## `popcorn-glory.*`, no network, and no path into another game.

const SOURCE_DIRS := ["res://app", "res://core", "res://art", "res://variants"]
const FORBIDDEN := ["user://", "FileAccess.WRITE", "HTTPRequest", "HTTPClient", "WebSocket", "localStorage",
	"indexedDB", "momonium", "motorio", "windup", "../"]


func test_no_storage_network_or_other_games_in_the_source() -> void:
	var files: Array[String] = []
	for d: String in SOURCE_DIRS:
		_collect(d, files)
	assert_true(files.size() >= 10, "found the sources (%d)" % files.size())
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		for word: String in FORBIDDEN:
			assert_false(text.contains(word), "%s mentions %s" % [path, word])


func test_no_autoloads() -> void:
	for prop: Dictionary in ProjectSettings.get_property_list():
		assert_false(String(prop["name"]).begins_with("autoload/"), "autoload %s" % prop["name"])


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
