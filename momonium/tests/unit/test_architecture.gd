extends "res://tests/framework/test_case.gd"

## The layering rule, checked on the source rather than trusted: game logic
## never depends on presentation. Logic folders hold RefCounted rules and data;
## presentation folders hold nodes that read the simulation and send commands.

const LOGIC := ["core", "data", "sim", "world", "buildings", "economy", "progression", "research", "persistence", "agents"]
const PRESENTATION := ["render", "input", "ui", "actors", "audio", "app", "platform"]
const NODE_BASES := ["extends Node", "extends Control", "extends CanvasItem", "extends Sprite2D", "extends CanvasLayer", "extends Camera2D"]
const PRESENTATION_APIS := ["get_tree()", "get_viewport()", "Input.", "queue_redraw", "DisplayServer.", "JavaScriptBridge"]


func test_logic_does_not_depend_on_presentation() -> void:
	var presentation_classes := _class_names(PRESENTATION)
	for folder: String in LOGIC:
		for path: String in _scripts("res://src/" + folder):
			var source := FileAccess.get_file_as_string(path)
			for base: String in NODE_BASES:
				assert_false(source.contains(base), "%s must not be a node (%s)" % [path, base])
			for api: String in PRESENTATION_APIS:
				assert_false(source.contains(api), "%s must not touch %s" % [path, api])
			for folder_p: String in PRESENTATION:
				assert_false(source.contains("res://src/%s/" % folder_p), "%s must not load presentation code" % path)
			for cls: String in presentation_classes:
				var regex := RegEx.create_from_string("\\b%s\\b" % cls)
				assert_true(regex.search(source) == null, "%s must not reference presentation class %s" % [path, cls])


func test_no_autoload_singletons() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://project.godot")
	assert_false(cfg.has_section("autoload"), "state is passed explicitly, not through autoloads")


func _class_names(folders: Array) -> Array[String]:
	var out: Array[String] = []
	var regex := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for folder: String in folders:
		for path: String in _scripts("res://src/" + folder):
			var m := regex.search(FileAccess.get_file_as_string(path))
			if m:
				out.append(m.get_string(1))
	return out


func _scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(_scripts(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	return out
