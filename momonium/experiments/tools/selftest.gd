extends SceneTree

## Plays each built experiment for three minutes of play time with a scripted
## player and prints its run record -- objective numbers about the design
## (when the upgrades come, how long the waits are), never a measure of fun.
##
##   godot --headless --path momonium/experiments --script res://tools/selftest.gd -- [--exp island] [--json out.json]
##
## The scripted player reacts after REACTION seconds; per experiment:
##   island  buys Upgrade Island when it can pay
##   rock    taps the rock 2.5 times a second, buys Pickaxe Power when it can pay
##   tree    buys Grow Tree when it can pay
##   harvest harvests when ripe and buys Bigger Field when it can pay
##   other   presses the one button when it can pay

const SECONDS := 180.0
const STEP := 0.05
const REACTION := 1.5

var _out := {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var only := ""
	var json_path := ""
	for i in args.size():
		if args[i] == "--exp" and i + 1 < args.size():
			only = args[i + 1]
		if args[i] == "--json" and i + 1 < args.size():
			json_path = args[i + 1]
	root.size = Vector2i(720, 1280)
	var app: LabApp = (load("res://lab/main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	for id: String in LabRegistry.ids():
		if not LabRegistry.playable(id) or (only != "" and id != only):
			continue
		app.open(id)
		await process_frame
		var host: LabHost = app.host
		host.set_process(false)
		var e := host.experiment
		var t := 0.0
		var ready_since := -1.0
		var tap_clock := 0.0
		while t < SECONDS:
			host.step(STEP)
			t += STEP
			if id == "rock":
				tap_clock += STEP
				if tap_clock >= 0.4:
					tap_clock -= 0.4
					var rr: Array = e.state()["rock_rect"]
					var c := Vector2(float(rr[0]) + float(rr[2]) * 0.5, float(rr[1]) + float(rr[3]) * 0.5)
					e.call("tap_at", e.get_global_transform().affine_inverse() * c)
			var info := e.action_info()
			# D's button rests a moment after a harvest: nothing to press then.
			if String(info.get("kind", "")) == "rest":
				ready_since = -1.0
				continue
			if not info.is_empty() and bool(info.get("affordable", false)):
				if ready_since < 0.0:
					ready_since = t
				elif t - ready_since >= REACTION:
					host.press_action()
					ready_since = -1.0
			else:
				ready_since = -1.0
		var s := host.session.summary()
		_out[id] = s
		print("%s: %s" % [id, JSON.stringify({"upgrades": (s["upgrades"] as Array).size(), "first_upgrade_s": s["first_upgrade_s"],
			"seconds_between_upgrades": s["seconds_between_upgrades"], "idle_seconds": s["idle_seconds"],
			"longest_idle_s": s["longest_idle_s"], "actions": s["actions"], "metrics": s["metrics"],
			"milestones": (s["milestones"] as Array).map(func(m: Dictionary) -> String: return "%s@%s" % [m["name"], m["t_s"]])})])
		app.back()
		await process_frame
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"_doc": "tools/selftest.gd: a scripted player, 180 s of play each (reaction %.1f s). Objective numbers only." % REACTION, "runs": _out}, "  "))
		f.close()
	app.queue_free()
	for i in 3:
		await process_frame
	quit()
