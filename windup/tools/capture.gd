extends SceneTree

## A real-renderer screenshot of the game (needs a display; Xvfb is enough --
## the headless dummy renderer draws nothing):
##
##   xvfb-run -a -s "-screen 0 1600x1000x24" godot --path windup --audio-driver Dummy \
##     --resolution 1280x720 --script res://tools/capture.gd -- --out /abs/shot.png \
##     [--wait 1.0] [--winds 0] [--seed 1] [--slow-clicks 12 --then 1.0]
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
	main.config = RunConfig.from_pairs({"seed": args.get("seed", "1"), "fresh": "1", "variant": args.get("variant", "base")})
	root.add_child(main)
	await process_frame
	# --hold S: hold the key for S game seconds (the real hold path), then
	# --after S more seconds without input. Stepped at 1/60 s, so the dolls
	# walk and the lights fade as they would.
	if args.has("hold"):
		main.press("key")
		var held := float(args["hold"])
		var t := 0.0
		while t < held:
			main.advance(1.0 / 60.0)
			t += 1.0 / 60.0
		if not args.has("keep-holding"):
			main.release("key")
		var after := float(args.get("after", "0"))
		t = 0.0
		while t < after:
			main.advance(1.0 / 60.0)
			t += 1.0 / 60.0
	# --slow-clicks N: N presses 2 s apart through the real input path (the way
	# a slow clicker plays -- after 20 s the hold hint shows), then --then S
	# more seconds; stepped at 1/60 s.
	if args.has("slow-clicks"):
		for i in int(args["slow-clicks"]):
			main.press("click")
			main.release("click")
			for f in 120:
				main.advance(1.0 / 60.0)
		for f in int(float(args.get("then", "0")) * 60.0):
			main.advance(1.0 / 60.0)
		main.set_process(false)
		main.hud.advance(5.0)   # the counter eases in _process only; settle it for the picture
	for i in int(args.get("winds", "0")):
		main.wind("dev")
		await create_timer(0.12).timeout
	# --storyboard t1,t2,...: the doll's wake-up stepped to exact times, one
	# picture each (out.png -> out_t1.png ...), the doll's clock held still.
	if args.has("storyboard") and main.view.doll != null:
		main.set_process(false)
		var base := out.get_basename()
		var done := 0.0
		main.view.doll.start_wake()
		for t: String in String(args["storyboard"]).split(","):
			main.view.doll.advance(float(t) - done)
			done = float(t)
			main.view.queue_redraw()
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			var path := "%s_t%s.png" % [base, t]
			print("capture: %s pose=%s" % [path, JSON.stringify(main.view.doll.pose)])
			shot.save_png(path)
		quit(0)
		return
	var frames := int(float(args.get("wait", "1.0")) * 60.0)
	for i in maxi(frames, 2):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_png(out)
	print("capture: %s %dx%d err=%d state=%s" % [out, image.get_width(), image.get_height(), err, JSON.stringify(main.state())])
	quit(0 if err == OK else 1)
