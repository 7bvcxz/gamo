extends "res://tests/framework/test_case.gd"

## The project is what the steps say it is: a portrait Godot 4.7 game on the
## Compatibility renderer, with a Web export that leaves tests and docs out.


func test_portrait_design_resolution() -> void:
	var w: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var h: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_true(h > w, "design resolution is portrait (%dx%d)" % [w, h])
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "fills any phone shape")
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "handheld orientation portrait")


func test_compatibility_renderer() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "desktop/web renderer")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility", "mobile renderer")


func test_version_is_semver() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	var regex := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$")
	assert_true(regex.search(version) != null, "version %s is major.minor.patch" % version)


func test_main_scene_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var packed: PackedScene = load(path)
	assert_true(packed != null, "main scene %s loads" % path)
	var scene: Node = packed.instantiate()
	assert_true(scene != null, "main scene instantiates")
	scene.free()


func test_web_preset_excludes_tooling() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export presets readable")
	var found_web := false
	for section: String in cfg.get_sections():
		if cfg.get_value(section, "platform", "") == "Web":
			found_web = true
			var exclude: String = cfg.get_value(section, "exclude_filter", "")
			for folder: String in ["tests/*", "tools/*", "design/*", "web/*"]:
				assert_true(exclude.contains(folder), "web export excludes %s" % folder)
	assert_true(found_web, "a Web export preset exists")


## A scene node without a stored unique_id gets a random one each time a fresh
## checkout exports, so the same source would publish different packs (Step 43
## found it: only a long-lived import cache had hidden it). Every node keeps one.
func test_every_scene_node_has_a_fixed_id() -> void:
	var missing: Array = []
	var seen := {}
	for path: String in _scenes("res://scenes"):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if not line.begins_with("[node "):
				continue
			var m := RegEx.create_from_string("unique_id=(\\d+)").search(line)
			if m == null:
				missing.append("%s: %s" % [path, line])
			else:
				assert_false(seen.has(m.get_string(1)), "unique_id %s used once (%s)" % [m.get_string(1), path])
				seen[m.get_string(1)] = true
	assert_eq(missing, [], "every scene node stores its id")
	assert_true(seen.size() >= 3, "the scenes were read (%d nodes)" % seen.size())


func _scenes(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	for f: String in d.get_files():
		if f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for sub: String in d.get_directories():
		out.append_array(_scenes(dir + "/" + sub))
	return out
