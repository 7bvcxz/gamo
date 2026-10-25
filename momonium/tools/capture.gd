extends SceneTree

## Renders a scene in a real window and saves what the player would see.
##
##   xvfb-run -a -s "-screen 0 1280x1600x24" godot --path momonium \
##     --audio-driver Dummy --script res://tools/capture.gd -- \
##     --out /abs/path/shot.png [--size 405x720] [--scene res://scenes/main.tscn] \
##     [--seconds 1.0] [--setup res://tools/scenarios/foo.gd]
##
## The headless dummy renderer has no viewport texture, so this needs a display
## (Xvfb is enough -- llvmpipe renders the Compatibility backend). Waiting is in
## frames at a pinned 60 fps: Xvfb renders far faster than real time, and a wait
## counted in frames would otherwise be a fraction of the time it claims.

var _args := {}
var _frames_left := 0
var _scene: Node


func _init() -> void:
	# Captures show the scenario's world, never the player's saved island.
	Engine.set_meta("momonium_no_save", true)
	Engine.max_fps = 60
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var key: String = raw[i].trim_prefix("--")
		var value: String = raw[i + 1] if i + 1 < raw.size() else ""
		_args[key] = value
		i += 2
	if not _args.has("out"):
		push_error("capture: --out <absolute png path> is required")
		quit(2)
		return
	var size := Vector2i(405, 720)
	if _args.has("size"):
		var parts: PackedStringArray = String(_args["size"]).split("x")
		size = Vector2i(int(parts[0]), int(parts[1]))
	root.size = size
	DisplayServer.window_set_size(size)
	var packed: PackedScene = load(_args.get("scene", "res://scenes/main.tscn"))
	_scene = packed.instantiate()
	root.add_child(_scene)
	_frames_left = int(float(_args.get("seconds", "1.0")) * 60.0)
	process_frame.connect(_tick)


var _setup_done := false


func _tick() -> void:
	# A scene added in _init is not in the tree until the first frame (root is
	# not inside the tree yet), so its _ready -- and the setup that relies on
	# it -- waits until here.
	if not _setup_done:
		_setup_done = true
		if _args.has("setup"):
			var setup: Script = load(_args["setup"])
			setup.new().call("setup", _scene)
	_frames_left -= 1
	if _frames_left > 0:
		return
	process_frame.disconnect(_tick)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err := image.save_png(_args["out"])
	print("capture: %s %dx%d err=%d" % [_args["out"], image.get_width(), image.get_height(), err])
	quit(0 if err == OK else 1)
