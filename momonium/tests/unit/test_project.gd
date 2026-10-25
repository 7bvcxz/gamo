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
			for folder: String in ["tests/*", "tools/*", "design/*"]:
				assert_true(exclude.contains(folder), "web export excludes %s" % folder)
	assert_true(found_web, "a Web export preset exists")
