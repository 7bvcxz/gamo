extends SceneTree
## Step 24 evidence: a 10-minute FAST-FORWARD (dev_advance, not real time) of the factory app,
## played by a bot that pops whenever the kettle is free and buys by a strategy:
##   good -- what relieves the current bottleneck (production: kettle, packaging: station,
##           demand: sign), whenever affordable;
##   bad  -- the packing station first (while customers are the limit), whenever
##           affordable; from minute 6 it recovers with `good`.
## Screenshots at 0, 3 and 10 minutes; a per-minute table on stdout.
## xvfb-run godot --path popcorn-glory --script res://tools/progress24.gd -- <good|bad> <out_dir>
var _app: Node
var _strategy := "good"
var _out := ""

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_strategy = args[0] if args.size() > 0 else "good"
	_out = args[1] if args.size() > 1 else "/tmp"
	root.size = Vector2i(720, 1280)
	DisplayServer.window_set_size(Vector2i(720, 1280))
	_app = load("res://app/main.tscn").instantiate()
	_app.set("save_prefix", "capture.")
	PopSaveStore.clear("capture.factory.v1")
	root.add_child(_app)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _strategy, name])


func _buy(cmd: String) -> bool:
	var f = _app.rules
	var r: Dictionary = f.execute({"type": cmd})
	return bool(r["ok"])


func _shop() -> void:
	var f = _app.rules
	var strat := _strategy
	if strat == "bad" and int(f.flow_ms) >= 360000:
		strat = "good"
	if strat == "bad":
		if f.station_open("packer") and f.packer_cost() >= 0 and f.money >= f.packer_cost():
			_buy("buy_packer")
		return
	match String(f.bottleneck()):
		"production":
			if f.money >= f.cost() and f.cost() >= 0:
				_buy("buy")
		"packaging":
			if f.station_open("packer") and f.packer_cost() >= 0 and f.money >= f.packer_cost():
				_buy("buy_packer")
		"demand":
			if f.station_open("sign") and f.sign_cost() >= 0 and f.money >= f.sign_cost():
				_buy("buy_sign")


func _run() -> void:
	await process_frame
	_app.open("factory")
	await process_frame
	await _shot("0min")
	print("minute | money revenue sold left | kettle station sign | bottleneck")
	var f = _app.rules
	var t := 0
	var minute := 0
	while t < 600000:
		if f.glass.is_empty() and int(f.cooldown_left) <= 0:
			_app.on_command("press", {"type": "press"})
			var hold: int = (int(f.window_start()) + int(f.window_end())) / 2
			_app.dev_advance(hold)
			t += hold
			_app.on_command("release", {"type": "release"})
		_app.dev_advance(250)
		t += 250
		_shop()
		if t / 60000 > minute:
			minute = t / 60000
			print("%2d | %6d %6d %4d %4d | %2d %d %d | %s" % [minute, f.money, f.stats["revenue"], f.stats["sold"], int(f.stats["abandoned"]) + int(f.stats["passed_by"]), f.level, f.packer_tier, f.sign_tier, f.bottleneck()])
			if minute == 3:
				await _shot("3min")
	await _shot("10min")
	quit(0)
