extends SceneTree

## Screenshots of the HUD in named situations -- for looking, not asserting.
##
## Every HUD pass in this repository has been checked by walking into the state
## by hand in a browser, and the walk is the expensive part: the base, a cat, a
## night, a phone-sized screen. This builds each one through the same calls the
## tests and debug keys use and saves what the screen shows, so a layout change
## can be looked at in all of them in one run.
##
## Needs a real renderer. The headless dummy cannot produce an image (AGENTS.md,
## 2026-07-22), so run it under a display -- Xvfb is enough:
##
##   DISPLAY=:99 godot --path motorio --audio-driver Dummy \
##     --script res://tools/hud_capture.gd -- --out /abs/dir [--only a,b] [--size 1280x720]
##
## It deletes the run's save slots (as every Main test does) and restores the
## settings file it found, because the scale sweep writes to it.

const SHOTS := [
	"start", "base", "quest", "cats", "gun", "torch", "prompt", "dusk", "night",
	"cold", "carry", "quests_open", "map_open", "base_menu",
]
const SCALES := [0.45, 0.7, 1.0, 1.6]
const SETTINGS := "user://motorio_settings.cfg"

var main: Node2D
var out_dir := ""
var only: Array[String] = []
var sizes: Array[Vector2i] = []
var settings_backup := ""

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--out": out_dir = args[index + 1]
			"--only":
				for name: String in args[index + 1].split(","):
					only.append(name)
			"--size":
				var parts: PackedStringArray = args[index + 1].split("x")
				sizes.append(Vector2i(int(parts[0]), int(parts[1])))
	if out_dir == "":
		push_error("hud_capture: --out <dir> is required")
		quit(2)
		return
	if sizes.is_empty():
		sizes = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(390, 844)]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# The pictures must never become game resources. Inside the project, Godot
	# imports every PNG it can see and the export packs it -- one capture run
	# once tripled the pack. A .gdignore beside them keeps the editor out.
	_ignore_for_godot(out_dir)
	if FileAccess.file_exists(SETTINGS):
		settings_backup = FileAccess.get_file_as_string(SETTINGS)
	_run.call_deferred()

func _ignore_for_godot(dir: String) -> void:
	var at: String = dir
	var project: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	# The first directory under the project on the way down to `dir`, so the
	# whole output tree is covered by one marker.
	while at.get_base_dir() != project and at.get_base_dir() != at and at.begins_with(project):
		at = at.get_base_dir()
	if at.begins_with(project) and at != project:
		FileAccess.open(at.path_join(".gdignore"), FileAccess.WRITE)

func _wanted(name: String) -> bool:
	return only.is_empty() or only.has(name)

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	for size: Vector2i in sizes:
		await _resize(size)
		var tag: String = "%dx%d" % [size.x, size.y]
		# A phone is a phone because the pad is up; without it the HUD lays out
		# for a desktop and the picture answers a question nobody asked.
		var phone: bool = size.x < size.y
		for name: String in SHOTS:
			if not _wanted(name):
				continue
			await _stage(name, phone)
			await _save("%s_%s" % [tag, name])
		if _wanted("scales") and not phone:
			await _stage("cats", phone)
			for value: float in SCALES:
				main.set_ui_scale(value)
				await _frames(3)
				await _save("%s_scale_%.2f" % [tag, value])
			main.set_ui_scale(Defs.UI_SCALE_DEFAULT)
	_restore_settings()
	main.clear_save()
	print("hud_capture: wrote %s" % out_dir)
	quit(0)

func _resize(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size
	await _frames(4)

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))

## A fresh run, then whatever the named situation needs on top of it.
func _stage(name: String, phone: bool) -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	# `debug_pad` toggles, so it is asked for the state rather than pressed.
	if main.touch != null and main.touch.visible != phone:
		main.debug_pad()
	main.messages.clear()
	match name:
		"start":
			pass
		"prompt":
			# Beside the case, facing it: the first key the game ever asks for.
			main.player.facing = Vector2i(0, -1)
		"base":
			main.sim.search_kit()
		"quest":
			main.finish_tutorial()
		"cats", "gun", "torch", "dusk", "night", "cold", "carry", "quests_open", \
				"map_open", "base_menu":
			main.debug_scenario()
			main.messages.clear()
	match name:
		"gun":
			main.tool_index = main.TOOL_BUILD_GUN
		"torch":
			main.tool_index = main.TOOL_TORCH
			main.sim.light_torch()
		"dusk":
			# Half way through the stretch that is dusk and not yet night.
			main.time_left = (Defs.DUSK_SECONDS + Defs.NIGHT_SECONDS) * 0.5
		"night":
			main.time_left = Defs.NIGHT_SECONDS * 0.5
		"cold":
			main.player.position += Vector2(Defs.TILE * 30.0, 0.0)
			main.player.warmth = 18.0
		"carry":
			main.debug_rescue()
			var ice: Vector2i = main.player.facing_cell()
			if main.sim.frozen_cats.has(ice):
				main.sim.carried_frozen = true
				main.sim.frozen_cats.erase(ice)
		"quests_open":
			main.toggle_quests()
		"map_open":
			main.toggle_map()
		"base_menu":
			main.base_menu_open = true
	# Long enough for the camera to arrive and the radius to finish spreading,
	# short enough that the opening's cold does not end the run.
	await _frames(20)

func _restore_settings() -> void:
	if settings_backup == "":
		return
	var file := FileAccess.open(SETTINGS, FileAccess.WRITE)
	file.store_string(settings_backup)
