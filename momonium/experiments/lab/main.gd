class_name LabApp
extends Node

## The Fun Lab: the launcher or one experiment, chosen by the address
## (LabRoute) and kept in it -- opening an experiment puts `#<id>` in the
## address, Back takes it out, the browser's back button and an edited link
## are followed. One experiment at a time, each run from nothing.
##
## Nothing is stored: no save, no settings, no browser storage. The page's
## visibility and focus pause the running experiment (LabHost.set_pause).

const VERSION_SETTING := "application/config/version"

var route: Dictionary = {}
var launcher: LabLauncher
var host: LabHost
var audio: LabAudio
var web := LabWeb.new()
var bridge := LabBridge.new()
var reduced_motion := false
## Summaries of runs finished this visit (Back or Restart), newest last.
var history: Array[Dictionary] = []

var _ui: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = Control.new()
	_ui.name = "UI"
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.add_child(_ui)
	add_child(layer)
	audio = LabAudio.new()
	audio.name = "Audio"
	add_child(audio)
	route = LabRoute.parse(LabWeb.location_hash(), LabWeb.location_search(), OS.get_cmdline_user_args())
	reduced_motion = String(route["motion"]) == "reduce" or (String(route["motion"]) == "" and LabWeb.reduced_motion())
	audio.muted = not bool(route["sound"])
	web.attach(_on_hash, func(hidden: bool) -> void: _pause("hidden", hidden), func(focused: bool) -> void: _pause("focus", not focused))
	bridge.attach(self)
	get_viewport().size_changed.connect(_fit)
	_fit()
	show_route(String(route["exp"]))


## A wide window (a desktop browser) shows the portrait layout 1.3 times as
## big: at 1280x800 the 720x1280 canvas would otherwise draw everything at
## 0.63 -- tiles, numbers and buttons too small to read at a glance.
func _fit() -> void:
	var win := get_window()
	if win == null:
		return
	var s := Vector2(win.size)
	var k := 1.3 if s.x > s.y * 1.05 else 1.0
	if not is_equal_approx(win.content_scale_factor, k):
		win.content_scale_factor = k


func version() -> String:
	return String(ProjectSettings.get_setting(VERSION_SETTING, "0"))


## Shows `id`'s experiment, or the launcher for "".
func show_route(id: String) -> void:
	if host != null and host.exp_id == id:
		return
	if host == null and launcher != null and id == "":
		return
	_clear()
	if id == "":
		launcher = LabLauncher.new()
		launcher.name = "Launcher"
		launcher.reduced_motion = reduced_motion
		launcher.open_requested.connect(open)
		_ui.add_child(launcher)
		audio.stop_ambience()
	else:
		host = LabHost.new()
		host.name = "Host"
		host.setup(id, version(), audio, bool(route["dev"]), reduced_motion)
		host.back_requested.connect(back)
		_ui.add_child(host)


## Opens an experiment and puts its direct link in the address.
func open(id: String) -> void:
	if not LabRegistry.has(id):
		return
	LabWeb.set_route(id)
	show_route(id)


func back() -> void:
	LabWeb.set_route("")
	show_route("")


func _clear() -> void:
	if host != null:
		history.append(host.session.summary())
		history.append_array(host.finished)
		host.queue_free()
		_ui.remove_child(host)
		host = null
		get_tree().paused = false
	if launcher != null:
		launcher.queue_free()
		_ui.remove_child(launcher)
		launcher = null


## One finger, one press. Touches are turned into mouse events (the project
## setting), and Godot's buttons answer a touch as well as its mouse copy: a
## press-mode button fired twice for one tap. The Lab's controls listen to the
## mouse copy alone, so the touch itself stops here, before the UI sees it.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()


func _on_hash() -> void:
	var r := LabRoute.parse(LabWeb.location_hash(), LabWeb.location_search())
	show_route(String(r["exp"]))


func _pause(reason: String, on: bool) -> void:
	if host != null:
		host.set_pause(reason, on)


func _notification(what: int) -> void:
	# Desktop and Android say the same through the engine.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not LabWeb.available():
		_pause("focus", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not LabWeb.available():
		_pause("focus", false)


func state() -> Dictionary:
	return {
		"version": version(),
		"route": host.exp_id if host != null else "",
		"screen": "experiment" if host != null else "launcher",
		"dev": bool(route["dev"]),
		"reduced_motion": reduced_motion,
		"window": [_ui.size.x, _ui.size.y],
		"tiles": launcher.rects() if launcher != null else {},
		"host": host.state() if host != null else {},
		"history": history.size(),
	}
