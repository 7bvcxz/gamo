extends SceneTree

## Renders the Lab in a real window and saves what the player would see
## (momonium/tools/capture.gd's way: Xvfb, frames at a pinned 60 fps).
##
##   xvfb-run -a -s "-screen 0 1280x1600x24" godot --path momonium/experiments \
##     --audio-driver Dummy --script res://tools/capture.gd -- \
##     --out /abs/shot.png [--size 720x1280] [--exp island] [--seconds 1.0] \
##     [--advance 30] [--call level:4] [--setup res://tools/scenarios/foo.gd]
##
## --exp opens an experiment as its direct link would; --advance skips that
## many seconds of play time before the wait; --setup runs a script's
## setup(app) first (to buy upgrades, tap, ...).

var _args := {}
var _frames_left := 0
var _app: Node
var _setup_done := false


func _init() -> void:
	Engine.max_fps = 60
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var key: String = raw[i].trim_prefix("--")
		var value: String = raw[i + 1] if i + 1 < raw.size() and not raw[i + 1].begins_with("--") else ""
		_args[key] = value
		i += 2 if value != "" else 1
	if not _args.has("out"):
		push_error("capture: --out <absolute png path> is required")
		quit(2)
		return
	var size := Vector2i(720, 1280)
	if _args.has("size"):
		var parts: PackedStringArray = String(_args["size"]).split("x")
		size = Vector2i(int(parts[0]), int(parts[1]))
	root.size = size
	DisplayServer.window_set_size(size)
	var packed: PackedScene = load("res://lab/main.tscn")
	_app = packed.instantiate()
	root.add_child(_app)
	_frames_left = int(float(_args.get("seconds", "1.0")) * 60.0)
	process_frame.connect(_tick)


func _tick() -> void:
	if not _setup_done:
		_setup_done = true
		if _args.has("setup"):
			var setup: Script = load(_args["setup"])
			await setup.new().call("setup", _app)
		if _args.has("call") and _app.get("host") != null:
			# --call name:arg[,name:arg] -> the experiment's dev hooks (e.g. level:4).
			for part: String in String(_args["call"]).split(","):
				var kv := part.split(":")
				(_app.get("host") as LabHost).experiment.dev(kv[0], kv[1] if kv.size() > 1 else null)
		if _args.has("advance") and _app.get("host") != null:
			(_app.get("host") as LabHost).step(float(_args["advance"]))
	_frames_left -= 1
	if _frames_left > 0:
		return
	process_frame.disconnect(_tick)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err := image.save_png(_args["out"])
	print("capture: %s %dx%d err=%d" % [_args["out"], image.get_width(), image.get_height(), err])
	quit(0 if err == OK else 1)
