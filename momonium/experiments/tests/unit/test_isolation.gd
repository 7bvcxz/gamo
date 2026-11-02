extends "res://tests/framework/test_case.gd"

## The Lab must never touch the game: not its saves or settings (it stores
## nothing at all), not its project, not its published build.

const FORBIDDEN := ["momonium_save", "momonium_settings", "user://", "localStorage", "sessionStorage",
	"indexedDB", "ConfigFile", "FileAccess.WRITE", "FileAccess.READ_WRITE", "DirAccess.make_dir", "save_png",
	"XMLHttpRequest", "HTTPRequest", "fetch(", "navigator.sendBeacon"]


func _lab() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


func _game() -> String:
	return _lab().get_base_dir()


func test_its_own_name_so_its_own_user_folder() -> void:
	var name := String(ProjectSettings.get_setting("application/config/name"))
	assert_eq(name, "Momonium Fun Lab", "the Lab's name")
	assert_ne(name, "Momonium", "not the game's (that would be the game's user:// folder)")


func test_the_lab_stores_and_sends_nothing() -> void:
	var hits: Array[String] = []
	for path: String in _sources("res://lab") + _sources("res://experiments"):
		var text := FileAccess.get_file_as_string(path)
		for word: String in FORBIDDEN:
			if text.contains(word):
				hits.append("%s: %s" % [path, word])
	assert_eq(hits, [] as Array[String], "no storage, no network, no game save names")


func test_the_game_project_is_untouched() -> void:
	var cfg := FileAccess.get_file_as_string(_game().path_join("project.godot"))
	assert_true(cfg.contains("config/name=\"Momonium\""), "the game is still Momonium")
	assert_true(cfg.contains("run/main_scene=\"res://scenes/main.tscn\""), "its main scene is its own")
	assert_false(cfg.contains("experiments"), "the game's project does not mention the Lab")
	var presets := FileAccess.get_file_as_string(_game().path_join("export_presets.cfg"))
	assert_false(presets.contains("experiments"), "nor its export presets")


## Godot skips a folder holding another project.godot, so the game's export
## never sees the Lab. The published pack says so.
func test_the_published_game_pack_has_no_lab() -> void:
	var repo := _game().get_base_dir()
	var manifest := repo.path_join("docs/momonium/version.json")
	if not DirAccess.dir_exists_absolute(repo.path_join("docs")):
		# CI's sparse checkout has no docs/: there the game's own
		# tools/check.sh --export greps its fresh pack for the same thing.
		print("  (no docs/ here: the published pack is checked where it exists)")
		return
	if not FileAccess.file_exists(manifest):
		fail("no published game at " + manifest)
		return
	var v: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	var pack := FileAccess.get_file_as_bytes(repo.path_join("docs/momonium").path_join(String(v["pack"])))
	assert_true(pack.size() > 100000, "the game's pack was read (%d bytes)" % pack.size())
	assert_eq(_find(pack, "res://experiments".to_utf8_buffer()), -1, "no res://experiments in it")
	assert_eq(_find(pack, "Momonium Fun Lab".to_utf8_buffer()), -1, "nor the Lab's name")


func test_deploy_writes_only_the_labs_folder() -> void:
	var script := FileAccess.get_file_as_string("res://tools/deploy.sh")
	assert_true(script.contains("docs/momonium-experiments"), "deploys to its own folder")
	var game_folder := RegEx.create_from_string("docs/momonium/")
	assert_true(game_folder.search(script) == null, "never names the game's folder")


func _sources(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".gdshader"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_sources(dir.path_join(sub)))
	return out


static func _find(hay: PackedByteArray, needle: PackedByteArray) -> int:
	var first := needle[0]
	var i := hay.find(first)
	while i >= 0 and i + needle.size() <= hay.size():
		if hay.slice(i, i + needle.size()) == needle:
			return i
		i = hay.find(first, i + 1)
	return -1
