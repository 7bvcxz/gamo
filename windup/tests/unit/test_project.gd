extends "res://tests/framework/test_case.gd"

## The project's own settings, and that it stays a game of its own: no path
## into another game, nothing stored outside its own user:// folder.


func test_settings() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Windup", "name decides the user:// folder")
	var version := str(ProjectSettings.get_setting("application/config/version"))
	assert_true(RegEx.create_from_string("^0\\.\\d+\\.\\d+$").search(version) != null, "version 0.<step>.<n>: " + version)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280, "PC first width")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720, "PC first height")
	assert_true(ResourceLoader.exists(ProjectSettings.get_setting("application/run/main_scene")), "main scene exists")


func test_audio_buses_are_declared_not_added_at_runtime() -> void:
	# Godot 4.7 web plays sound as browser samples; a bus added at runtime is not
	# in that graph and its players are silent (AGENTS.md, 2026-10-27).
	for bus: String in ["Music", "Ambience", "Effects"]:
		assert_true(AudioServer.get_bus_index(bus) > 0, "bus %s in default_bus_layout.tres" % bus)


func test_web_preset_exists_and_excludes_non_game_folders() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg")
	assert_eq(cfg.get_value("preset.0", "platform"), "Web", "Web preset")
	var exclude: String = cfg.get_value("preset.0", "exclude_filter")
	for dir: String in ["tests/*", "tools/*", "design/*", "evidence/*"]:
		assert_true(exclude.contains(dir), "excludes " + dir)


func test_source_never_reaches_outside_the_game() -> void:
	var offenders: Array[String] = []
	for path: String in _gd_files("res://src"):
		var text := FileAccess.get_file_as_string(path)
		for needle: String in ["res://../", "momonium", "motorio", "popcorn"]:
			if text.contains(needle):
				offenders.append("%s: %s" % [path, needle])
	assert_eq(offenders, [] as Array[String], "isolation")


func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(_gd_files(dir_path.path_join(sub)))
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	return out
