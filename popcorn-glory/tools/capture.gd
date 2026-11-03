extends SceneTree

## Renders the game in a real window and saves what the player would see
## (the Fun Lab's way: Xvfb, frames pinned at 60 fps). Headless cannot do
## this -- the dummy renderer has no texture (design/TOOLS.md).
##
##   xvfb-run -a -s "-screen 0 1280x1600x24" godot --path popcorn-glory \
##     --audio-driver Dummy --script res://tools/capture.gd -- \
##     --out /abs/shot.png [--size 720x1280] [--exp stub] [--presses 12] \
##     [--buy 2] [--advance 30] [--seconds 1.0]
##
## --presses taps the machine that many times (through the app, as a press
## would), --buy buys that many upgrades when affordable, --advance skips play
## seconds before the final wait. --steps runs a list first, comma separated:
## p (press), r (release), b (buy), w<ms> (play time), e.g. p,w1600,r,w500
## (B: hold into the gold). --level N starts the run at level N (a picture
## of a later machine; not a play).

var _args := {}
var _frames_left := 0
var _app: PopApp
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
	var packed: PackedScene = load("res://app/main.tscn")
	_app = packed.instantiate()
	root.add_child(_app)
	_frames_left = int(float(_args.get("seconds", "1.0")) * 60.0)
	process_frame.connect(_tick)


func _tick() -> void:
	if not _setup_done:
		_setup_done = true
		if _args.has("exp"):
			_app.open(String(_args["exp"]))
		if _app.rules != null and _args.has("level"):
			_app.rules.level = int(_args["level"])
			_app.dev_advance(1)
		if _app.rules != null and _args.has("steps"):
			for step: String in String(_args["steps"]).split(",", false):
				match step.substr(0, 1):
					"p":
						_app.on_command("press", {"type": "press"})
					"r":
						_app.on_command("release", {"type": "release"})
					"b":
						_app.buy()
					"w":
						_app.dev_advance(int(step.substr(1)))
		if _app.rules != null:
			var buys := int(_args.get("buy", "0"))
			for i in int(_args.get("presses", "0")):
				_app.on_command("press", {"type": "press"})
				if buys > 0 and _app.rules.can_buy():
					_app.buy()
					buys -= 1
			if _args.has("advance"):
				_app.dev_advance(int(float(_args["advance"]) * 1000.0))
	_frames_left -= 1
	if _frames_left > 0:
		return
	process_frame.disconnect(_tick)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err := image.save_png(_args["out"])
	print("capture: %s %dx%d err=%d" % [_args["out"], image.get_width(), image.get_height(), err])
	# Sounds still playing are let go on the audio thread's next mix: quitting
	# now reported them as resources in use (momonium's runner, Step 50).
	if _app.audio != null:
		_app.audio.stop_all()
	_app.queue_free()
	for i in 3:
		await process_frame
	await create_timer(0.25).timeout
	quit(0 if err == OK else 1)
