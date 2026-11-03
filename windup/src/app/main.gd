class_name WindupMain
extends Node

## The game's entry point (scenes/main.tscn). It reads how the run was asked
## to start, owns the one clock and the event log, and makes every new game
## through `new_game` -- the debug reset, `?fresh=1` and a restart are the
## same path, so a fresh game is always the same game for the same seed.
##
## Step 02: the foundation only. Pressing the key turns it and logs a `wind`
## event; there is no energy, no doll and no save yet (Step 04).

var config: RunConfig
var clock: GameClock
var telemetry: Telemetry
var view: AtelierView
var session: int = 0
var winds: int = 0

var _web := WindupWeb.new()
var _bridge := WindupBridge.new()


func _ready() -> void:
	if config == null:
		config = RunConfig.from_environment()
	clock = GameClock.new()
	telemetry = Telemetry.new(clock)
	view = AtelierView.new()
	view.version_text = "v" + version()
	add_child(view)
	view.wind_pressed.connect(wind)
	new_game(config.seed)
	_web.attach(func(hidden: bool) -> void: set_pause("hidden", hidden),
		func(focused: bool) -> void: set_pause("focus", not focused))
	_bridge.attach(self)
	if config.smoke:
		_run_smoke.call_deferred()


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## The one way a game starts.
func new_game(seed: int) -> void:
	session += 1
	winds = 0
	config.seed = seed
	clock.reset()
	telemetry.clear()
	view.reset()
	telemetry.emit("session_start", {"variant": config.variant, "build": version(), "seed": seed, "session": session})


## One quarter turn of the key, from any source ("click", "hold", "key", "dev").
func wind(source: String) -> void:
	winds += 1
	view.turn()
	telemetry.emit("wind", {"source": source})


func _process(delta: float) -> void:
	advance(delta)


## Moves the game by `seconds` of game time (the clock ignores it while paused).
func advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, GameClock.MAX_STEP)
		clock.advance(step)
		left -= step


func set_pause(reason: String, on: bool) -> void:
	if clock.set_paused(reason, on):
		telemetry.emit("pause" if clock.paused else "resume", {"why": reason})


func _notification(what: int) -> void:
	if clock == null:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			set_pause("focus", true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			set_pause("focus", false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_SPACE:
			wind("key")
			get_viewport().set_input_as_handled()
		elif key == KEY_F5 and config.dev:
			new_game(config.seed)
			get_viewport().set_input_as_handled()


func state() -> Dictionary:
	return {
		"version": version(),
		"session": session,
		"t": snappedf(clock.time, 0.001),
		"paused": clock.paused,
		"pause_reasons": clock.reasons(),
		"winds": winds,
		"events": telemetry.events.size(),
		"config": config.to_dict(),
		"art": view.use_art,
		"doll": view.doll.pose_name if view.doll != null else "",
		"fps": Engine.get_frames_per_second(),
	}


## `godot --headless --path windup -- --smoke`: a few presses over a few game
## seconds through the real scene, then one summary line, then quit with the
## number of problems found.
func _run_smoke() -> void:
	for i in 8:
		wind("dev")
		advance(0.5)
		await get_tree().process_frame
	var problems := 0
	if telemetry.count("session_start") != 1:
		problems += 1
	if telemetry.count("wind") != 8:
		problems += 1
	if clock.time < 3.9:
		problems += 1
	print("WINDUP_SMOKE " + JSON.stringify({"ok": problems == 0, "state": state()}))
	get_tree().quit(problems)
