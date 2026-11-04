extends "res://tests/framework/test_case.gd"

## This game keeps to itself (README.md): storage only through
## app/save_store.gd (the stand's save, Step 12) and only under its own names
## (localStorage `popcorn-glory.*`, user://popcorn_glory_*), no network, and
## no path into another game.

const SOURCE_DIRS := ["res://app", "res://core", "res://art", "res://variants"]
const STORE := "res://app/save_store.gd"
const STORAGE_WORDS := ["user://", "FileAccess.WRITE", "localStorage", "indexedDB"]
const FORBIDDEN := ["HTTPRequest", "HTTPClient", "WebSocket", "momonium", "motorio", "windup", "../"]


func test_no_storage_network_or_other_games_in_the_source() -> void:
	var files: Array[String] = []
	for d: String in SOURCE_DIRS:
		_collect(d, files)
	assert_true(files.size() >= 10, "found the sources (%d)" % files.size())
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		for word: String in FORBIDDEN:
			assert_false(text.contains(word), "%s mentions %s" % [path, word])
		if path != STORE:
			for word: String in STORAGE_WORDS:
				assert_false(text.contains(word), "%s mentions %s (storage goes through save_store.gd)" % [path, word])


func test_the_save_store_uses_only_this_games_names() -> void:
	var text := FileAccess.get_file_as_string(STORE)
	assert_true(text.contains('const KEY_PREFIX := "popcorn-glory."'), "localStorage keys under popcorn-glory.")
	assert_true(text.contains('const FILE_PREFIX := "user://popcorn_glory_"'), "files under user://popcorn_glory_")
	for line: String in text.split("\n"):
		if line.contains("user://"):
			assert_true(line.strip_edges().begins_with("#") or line.contains("const FILE_PREFIX"), "user:// only in comments and the prefix: %s" % line.strip_edges())
	for line: String in text.split("\n"):
		if line.contains("localStorage.") and not line.strip_edges().begins_with("#"):
			assert_true(line.contains("KEY_PREFIX + name"), "every localStorage call uses the prefix: %s" % line.strip_edges())


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
