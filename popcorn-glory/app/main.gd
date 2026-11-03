class_name PopApp
extends Node

## Popcorn & Glory: the chooser, or one experiment, chosen by the address
## (PopRoute) and kept in it -- opening an experiment puts `#<id>` in the
## address, Back takes it out, the browser's back button and an edited link
## are followed. One experiment at a time, each run from nothing.
##
## Every change to a run goes through here: the view asks (command), the app
## stamps the active time, logs the input, executes it on the rules, and hands
## the resulting events to the session log and back to the view in the same
## frame -- a press shows its pop on the frame it was made.
##
## Nothing is stored: no save, no settings, no browser storage.

const VERSION_SETTING := "application/config/version"

var route: Dictionary = {}
var web := PopWeb.new()
var bridge := PopBridge.new()
var economy := PopEconomy.load_default()
var screen := "chooser"
var exp_id := ""
var rules: PopRules
var clock := PopClock.new()
var session := PopSession.new()
var history: Array[Dictionary] = []
var reduced_motion := false

var ui: Control
var chooser: PopChooser
var frame: PopFrame
var audio: PopAudio


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.name = "Layer"
	add_child(layer)
	ui = Control.new()
	ui.name = "UI"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = PopPalette.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chooser = PopChooser.new()
	chooser.name = "Chooser"
	ui.add_child(chooser)
	chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chooser.chosen.connect(open)
	frame = PopFrame.new()
	frame.name = "Frame"
	ui.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.back_pressed.connect(back)
	frame.restart_pressed.connect(restart)
	frame.buy_pressed.connect(buy)
	frame.sound_pressed.connect(toggle_sound)
	frame.log_pressed.connect(download_log)
	audio = PopAudio.new()
	audio.name = "Audio"
	add_child(audio)
	route = PopRoute.parse(PopWeb.location_hash(), PopWeb.location_search(), OS.get_cmdline_user_args())
	reduced_motion = String(route["motion"]) == "reduce"
	frame.dev = bool(route["dev"])
	audio.set_muted(not bool(route["sound"]))
	frame.set_sound(not audio.muted)
	if not economy.errors.is_empty():
		push_error("economy.json: %s" % [economy.errors])
	chooser.build(PopRegistry.listed())
	web.attach(_on_hash, func(hidden: bool) -> void: clock.set_pause("hidden", hidden))
	bridge.attach(self)
	get_viewport().size_changed.connect(_fit)
	_fit()
	show_route(String(route["exp"]))


func version() -> String:
	return String(ProjectSettings.get_setting(VERSION_SETTING, "0"))


## A wide window (a desktop browser) shows the portrait layout 1.3 times as
## big: at 1280x800 the 720x1280 canvas would otherwise draw everything at 0.63.
func _fit() -> void:
	var win := get_window()
	if win == null:
		return
	var s := Vector2(win.size)
	var k := 1.3 if s.x > s.y * 1.05 else 1.0
	if not is_equal_approx(win.content_scale_factor, k):
		win.content_scale_factor = k


func show_route(id: String) -> void:
	if id != "" and not PopRegistry.find(id).is_empty():
		_start(id)
	else:
		_show_chooser()


func open(id: String) -> void:
	if PopRegistry.find(id).is_empty():
		return
	PopWeb.set_route(id)
	_start(id)


func back() -> void:
	_finish_run()
	PopWeb.set_route("")
	_show_chooser()


## The run's local log with what it was played on (dev mode's log button):
## build, variant, viewport, active time, every line. Nothing is sent anywhere.
func log_document() -> Dictionary:
	var win := get_window()
	return {"game": "popcorn-glory", "version": version(), "variant": exp_id,
		"viewport": [win.size.x, win.size.y] if win else [0, 0], "active_ms": clock.now_ms,
		"summary": summary(), "lines": session.lines}


func download_log() -> void:
	if rules == null:
		return
	PopWeb.download(JSON.stringify(log_document(), "  "), "popcorn-%s-%d.json" % [exp_id, clock.now_ms], "application/json")


func toggle_sound() -> void:
	audio.set_muted(not audio.muted)
	frame.set_sound(not audio.muted)


func restart() -> void:
	if screen != "play":
		return
	_finish_run()
	_start(exp_id)


func buy() -> void:
	if rules == null:
		return
	var r := rules.execute({"type": "buy"})
	session.record(clock.now_ms, "buy", {"ok": bool(r["ok"]), "reason": String(r.get("reason", ""))})
	_flush()


## A view's request: stamped, logged, executed, shown -- all in this frame.
func on_command(kind: String, cmd: Dictionary) -> void:
	if rules == null:
		return
	if kind == "release":
		# Letting go is part of B's action, not a second input: the input count
		# stays one per press in every experiment.
		session.record(clock.now_ms, "release", {})
	else:
		session.record_input(clock.now_ms, kind)
		frame.play.last_input_ms = clock.now_ms
	var r := rules.execute(cmd)
	if not bool(r["ok"]):
		session.record(clock.now_ms, "refused", {"kind": kind, "reason": String(r.get("reason", ""))})
	_flush()


func dev_level(level: int) -> void:
	if rules != null:
		rules.level = clampi(level, 0, rules.max_level())
		_flush()


func dev_advance(ms: int) -> void:
	if rules == null or ms <= 0:
		return
	# In steps no longer than a frame's cap, so time-driven rules see the same
	# sequence a played run would.
	var left := ms
	while left > 0:
		var step := mini(left, 100)
		clock.add_ms(step)
		rules.advance(step)
		_flush()
		left -= step


func _process(delta: float) -> void:
	if screen != "play" or rules == null:
		return
	var added := clock.step(delta)
	if added > 0:
		rules.advance(added)
	_flush()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo:
		return
	if screen == "play" and (k.keycode == KEY_SPACE or k.keycode == KEY_ENTER):
		# The view turns it into its own commands (logged in on_command).
		frame.play.key(k.pressed)
		get_viewport().set_input_as_handled()
	elif screen == "play" and k.pressed and k.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()


func _flush() -> void:
	var events := rules.drain_events()
	if not events.is_empty():
		session.record_events(events)
		frame.play.on_events(events)
	session.observe(clock.now_ms, rules)
	frame.play.now_ms = clock.now_ms
	frame.refresh(rules, clock.now_ms)


func _start(id: String) -> void:
	var entry := PopRegistry.find(id)
	exp_id = id
	screen = "play"
	rules = PopRegistry.make_rules(id, economy)
	clock = PopClock.new()
	if web.hidden():
		clock.set_pause("hidden", true)
	session = PopSession.new(id)
	var view_script: GDScript = load(String(entry["view"]))
	var view: PopPlayView = view_script.new()
	view.reduced_motion = reduced_motion
	view.audio = audio
	audio.stop_all()
	view.command.connect(on_command)
	frame.accent = entry["color"]
	frame.set_play(view)
	view.setup(rules)
	chooser.visible = false
	frame.visible = true
	_flush()


func _finish_run() -> void:
	if screen == "play" and rules != null:
		session.reset(clock.now_ms)
		history.append(summary())
		if history.size() > 20:
			history.pop_front()


func _show_chooser() -> void:
	if audio != null:
		audio.stop_all()
	screen = "chooser"
	exp_id = ""
	rules = null
	chooser.visible = true
	frame.visible = false


func _on_hash() -> void:
	var r := PopRoute.parse(PopWeb.location_hash(), PopWeb.location_search(), PackedStringArray())
	var id := String(r["exp"])
	if id == exp_id:
		return
	_finish_run()
	show_route(id)


# -- what the page and the tests can read ---------------------------------

func summary() -> Dictionary:
	if rules == null:
		return {}
	return session.summary(clock.now_ms, rules)


func log_lines() -> Array[Dictionary]:
	return session.lines


func state() -> Dictionary:
	var out := {"version": version(), "screen": screen, "exp": exp_id,
		"window": [get_window().size.x, get_window().size.y] if get_window() else [0, 0],
		"listed": PopRegistry.listed().map(func(e: Dictionary) -> String: return String(e["id"])),
		"history": history.size(), "rects": _rects()}
	if rules != null:
		out["run"] = rules.state()
		out["clock_ms"] = clock.now_ms
		out["paused"] = clock.pause_reasons()
		out["fx"] = {"alive": frame.play.fx.alive, "peak": frame.play.fx.peak, "cap": PopFx.CAP}
	out["sound"] = {"muted": audio.muted, "played": audio.played.duplicate()}
	return out


## Window-pixel rectangles [x, y, w, h] of what a test taps.
func _rects() -> Dictionary:
	var out := {}
	var named: Dictionary = {}
	if screen == "play":
		named = {"play": frame.play, "upgrade": frame.upgrade_button, "back": frame.back_button,
			"restart": frame.restart_button, "money": frame.money_view, "sound": frame.sound_button}
	else:
		for t: Dictionary in chooser.tiles:
			named["tile_" + String(t["id"])] = t["button"]
	var xf := get_viewport().get_final_transform()
	for key: String in named.keys():
		var c: Control = named[key]
		var r := xf * c.get_global_rect()
		out[key] = [r.position.x, r.position.y, r.size.x, r.size.y]
	return out
