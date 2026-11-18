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
## (the stand: a (buy automation), s (shake), k<recipe> (choose it), m<N> (add
## money to buy what the picture shows -- setup, not play))
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
	# Pictures never read or write a player's save (Step 12).
	_app.set("save_prefix", "capture.")
	PopSaveStore.clear("capture.stand.v1")
	PopSaveStore.clear("capture.factory.v1")   # Step 22: the factory is saved too
	root.add_child(_app)
	_frames_left = int(float(_args.get("seconds", "1.0")) * 60.0)
	process_frame.connect(_tick)


func _tick() -> void:
	if not _setup_done:
		_setup_done = true
		if _args.has("burst"):
			_app.set("burst", true)   # Step 14: the stand's crescendo
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
					"a":
						_app.buy_auto()
					"s":
						_app.on_command("shake", {"type": "shake"})
					"k":
						_app.on_command("recipe", {"type": "recipe", "id": step.substr(1)})
					"m":
						# Picture setup (not a play): money to buy what is shown.
						_app.rules.money += int(step.substr(1))
						_app.rules.earned += int(step.substr(1))
					"c":
						# Step 26: build a machine, `c<type>@<slot>` (e.g. ccooker@0).
						var bits := step.substr(1).split("@")
						_app.on_command("build", {"type": "build", "machine": bits[0], "slot": int(bits[1]) if bits.size() > 1 else -1})
					"S":
						# Step 26: choose machine id N on screen (its buttons and detail).
						var v = _app.frame.play
						v.sel_machine = int(step.substr(1))
						var mm: Dictionary = _app.rules.machine(v.sel_machine)
						if not mm.is_empty():
							v.selected = int(v.FLOOR_INDEX[String(mm["floor"])])
					"x":
						# Picture setup (Step 20): a factory with no customers (to show a full shelf).
						if "queue" in _app.rules:
							_app.rules.queue.clear()
							_app.rules.next_arrival_ms = 1 << 40
					"F":
						# Step 33 (picture setup): the 44-machine plan of the unit test, `F<n>` its
						# first n, the lines bought as each floor fills -- through the app's commands.
						var rr = _app.rules
						rr.sign_tier = 6
						rr.packer_tier = 3
						rr.level = maxi(int(rr.level), 6)
						rr.stats["packed"] = maxi(1, int(rr.stats["packed"]))
						rr.stats["sold"] = maxi(1, int(rr.stats["sold"]))
						rr.money += 1 << 24
						var n := int(step.substr(1)) if step.length() > 1 else 44
						for row: Array in preload("res://tests/unit/test_factory_rules.gd").FORTY_PLAN:
							if (rr.machines as Array).size() >= n:
								break
							var fl := String(row[1])
							if rr.floor_full(fl) and int(rr.line_cost(fl)) >= 0:
								_app.on_command("buy_line", {"type": "buy_line", "floor": fl})
							_app.on_command("build", {"type": "build", "machine": row[0], "floor": fl})
						rr.money = 3000
					"V":
						# Step 34 (picture setup): the flavor factory -- three kettles, a hopper, the flavor
						# base mixer; packing: a filler, the sprayer on cheese, the coater on caramel, the
						# sprayer on spicy, the second line with its filler and the coater on cocoa.
						var rv = _app.rules
						rv.sign_tier = 6
						rv.packer_tier = 3
						rv.level = maxi(int(rv.level), 6)
						rv.stats["packed"] = maxi(1, int(rv.stats["packed"]))
						rv.stats["sold"] = maxi(1, int(rv.stats["sold"]))
						rv.money += 1 << 24
						for id in ["cooker", "cooker", "cooker", "M01", "M12"]:
							_app.on_command("build", {"type": "build", "machine": id, "floor": "kitchen"})
						for row: Array in [["bagger", ""], ["P05", "cheese"], ["P06", "caramel"], ["P05", "spicy"], ["line", ""], ["bagger", ""], ["P06", "cocoa"]]:
							if String(row[0]) == "line":
								_app.on_command("buy_line", {"type": "buy_line", "floor": "packing"})
								continue
							_app.on_command("build", {"type": "build", "machine": row[0], "floor": "packing"})
							if String(row[1]) != "":
								var last: Dictionary = (rv.machines as Array)[(rv.machines as Array).size() - 1]
								_app.on_command("set_flavor", {"type": "set_flavor", "id": last["id"], "flavor": row[1]})
						rv.money = 3000
					"Q":
						# Step 34 (picture setup): every coater paused -- the same factory with no flavor offered.
						for qm: Dictionary in _app.rules.machines:
							if String(qm["type"]) in ["P05", "P06"]:
								_app.on_command("pause_machine", {"type": "pause_machine", "id": qm["id"], "paused": true})
					"H":
						# Step 35 (picture setup): the hand has cooked comfortably (the spoon is open).
						_app.rules.presses = maxi(int(_app.rules.presses), 30)
					"J":
						# Step 35: hold the spoon of the first coater with a batch on its drum for N ms
						# (`J<ms>`; R lets go) -- through the app, as the hand would.
						for fm: Dictionary in _app.rules.machines:
							if _app.rules.can_finish(fm):
								_app.on_command("finish_press", {"type": "finish_press", "id": fm["id"]})
								break
						_app.dev_advance(int(step.substr(1)))
						print("capture: spoon %s on %s" % [_app.rules.finishing, (_app.rules.machines as Array).filter(func(x: Dictionary) -> bool: return String(x["type"]) in ["P05", "P06"]).map(func(x: Dictionary) -> String: return "%d:%s:%s" % [x["id"], x["state"], (x["held"] as Dictionary).get("left_ms", -1)])])
					"R":
						_app.on_command("finish_release", {"type": "finish_release"})
					"N":
						# Step 37: `N<id>` starts that news event now (only one the shop can answer).
						_app.dev_news(step.substr(1))
					"P":
						# Step 37: the paper opens (as a tap on its icon).
						_app.frame.play.toggle_news()
					"K":
						# Step 38: `K<id>` posts that contest now; `E<id>` enters it (as the Enter button);
						# `T` shows the paper's contests page; `X` taps cancel (twice: cancels).
						_app.dev_contest(step.substr(1))
					"E":
						_app.on_command("contest_enter", {"type": "contest_enter", "id": step.substr(1)})
					"T":
						_app.frame.play.open_contests()
					"X":
						_app.on_command("contest_cancel", {"type": "contest_cancel"})
					"A":
						# Step 35: `A<id>` sets that coater to AUTO.
						_app.on_command("set_flavor", {"type": "set_flavor", "id": int(step.substr(1)), "flavor": "auto"})
					"O":
						# Step 33: the overview card (`O<id>` with that machine's diagnostics).
						var vo = _app.frame.play
						vo.overview = true
						if step.length() > 1:
							vo.ov_machine = int(step.substr(1))
					"w":
						_app.dev_advance(int(step.substr(1)))
					"f":
						# Step 16: open a floor's detail (0 top, 1 middle, 2 bottom).
						if _app.frame.play.has_method("toggle_floor"):
							_app.frame.play.toggle_floor(int(step.substr(1)))
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
	if _args.has("draws"):
		# Step 33: draw calls with each of the play view's layers hidden in turn -- what each costs.
		var v: Node = _app.frame.play
		var info := func() -> int: return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		for q in 3:
			await RenderingServer.frame_post_draw
		var all := int(info.call())
		print("draws: all %d (objects %d)" % [all, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
		for c: Node in v.get_children():
			if not c is CanvasItem or not (c as CanvasItem).visible:
				continue
			(c as CanvasItem).visible = false
			for q in 3:
				await RenderingServer.frame_post_draw
			print("draws: without %s (%d children): %d (-%d)" % [c.name, c.get_child_count(), int(info.call()), all - int(info.call())])
			(c as CanvasItem).visible = true
			for q in 2:
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
