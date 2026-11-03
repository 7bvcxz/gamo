extends SceneTree

## A real-renderer screenshot of the game (needs a display; Xvfb is enough --
## the headless dummy renderer draws nothing):
##
##   xvfb-run -a -s "-screen 0 1600x1000x24" godot --path windup --audio-driver Dummy \
##     --resolution 1280x720 --script res://tools/capture.gd -- --out /abs/shot.png \
##     [--wait 1.0] [--winds 0] [--seed 1]
##
## Boots the real main scene, optionally presses the key `--winds` times, waits
## `--wait` seconds of frames at 60 fps and saves what the window shows.

const MainScene := preload("res://scenes/main.tscn")


func _init() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	var args := RunConfig.parse_args(OS.get_cmdline_user_args())
	var out: String = args.get("out", "")
	if out == "":
		push_error("capture: --out /abs/path.png is required")
		quit(2)
		return
	var main: WindupMain = MainScene.instantiate()
	main.config = RunConfig.from_pairs({"seed": args.get("seed", "1"), "fresh": "1"})
	root.add_child(main)
	await process_frame
	for i in int(args.get("winds", "0")):
		main.wind("dev")
		await create_timer(0.12).timeout
	var frames := int(float(args.get("wait", "1.0")) * 60.0)
	for i in maxi(frames, 2):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_png(out)
	print("capture: %s %dx%d err=%d state=%s" % [out, image.get_width(), image.get_height(), err, JSON.stringify(main.state())])
	quit(0 if err == OK else 1)
