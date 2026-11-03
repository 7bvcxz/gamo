class_name WindupMain
extends Node

## The game's entry point (scenes/main.tscn). It reads how the run was asked
## to start, owns the one clock, the rules (Atelier), the event log and the
## save, and makes every new game through `new_game` -- the restart button,
## `?fresh=1` and the debug reset (F5 with ?dev=1) are the same path, so a fresh
## game is always the same game for the same seed.
##
## Input: the key is pressed with the mouse/touch or Space. A press is one
## quarter turn; holding keeps turning at the hold rate after a short delay.
## The rules refuse turns faster than the cap (data/balance.json).

var config: RunConfig
var clock: GameClock
var telemetry: Telemetry
var balance: Balance
var atelier: Atelier
var view: AtelierView
var hud: Hud
var sfx: Sfx
var store := SaveStore.new()
var settings := Settings.new()
var music: MusicBox
var ambient: AmbientBed
var session: int = 0
var winds: int = 0
## Presses (not held repeats), for the session summary.
var inputs: int = 0

var _web := WindupWeb.new()
var _bridge := WindupBridge.new()
var input: WindInput
var _last_input: float = -1.0
var _hinted: bool = false
var _since_save: float = 0.0
var _reported_end: bool = false
var _trace_t: float = 0.0


func _write_trace() -> void:
	var f := FileAccess.open(config.trace_out, FileAccess.WRITE)
	if f != null:
		f.store_string(telemetry.to_jsonl() + "\n")


func _ready() -> void:
	if config == null:
		config = RunConfig.from_environment()
	clock = GameClock.new()
	telemetry = Telemetry.new(clock)
	balance = Balance.load_variant(config.variant)
	# Each variant keeps its own save, so trying A does not continue B.
	if config.variant != "base":
		store.path = "user://windup_save_%s.json" % config.variant
	var bad := balance.problems()
	assert(bad.is_empty(), "balance.json: %s" % [bad])
	view = AtelierView.new()
	view.version_text = "v" + version()
	add_child(view)
	view.key_pressed.connect(press)
	view.key_released.connect(release.bind("click"))
	hud = Hud.new()
	add_child(hud)
	hud.restart_requested.connect(func() -> void:
		telemetry.emit("restart", {"dolls": atelier.awake})
		new_game(config.seed))
	sfx = Sfx.new()
	add_child(sfx)
	music = MusicBox.new()
	add_child(music)
	ambient = AmbientBed.new()
	add_child(ambient)
	view.helping.connect(func(helper: int, target: int) -> void:
		telemetry.emit("help", {"helper": helper, "target": target}))
	settings.load_saved()
	var q := RunConfig.parse_query(WindupWeb.query_string()) if OS.has_feature("web") else RunConfig.parse_args(OS.get_cmdline_user_args())
	if String(q.get("sound", "")) == "off":
		settings.volume_step = Settings.VOLUMES.size() - 1
	if String(q.get("motion", "")) == "reduce" or WindupWeb.prefers_reduced_motion():
		settings.reduced_motion = true
	_apply_settings()
	hud.volume_pressed.connect(func() -> void:
		settings.cycle_volume()
		_apply_settings()
		settings.save()
		telemetry.emit("setting", {"volume": settings.volume()}))
	hud.motion_pressed.connect(func() -> void:
		settings.reduced_motion = not settings.reduced_motion
		_apply_settings()
		settings.save()
		telemetry.emit("setting", {"reduced_motion": settings.reduced_motion}))
	var saved := {} if config.fresh or config.smoke else store.load_atelier()
	new_game(config.seed, saved)
	_web.attach(func(hidden: bool) -> void: set_pause("hidden", hidden),
		func(focused: bool) -> void: set_pause("focus", not focused))
	_bridge.attach(self)
	if config.smoke:
		_run_smoke.call_deferred()


func _apply_settings() -> void:
	settings.apply_audio()
	hud.volume_step = settings.volume_step
	hud.reduced_motion = settings.reduced_motion
	view.reduced_motion = settings.reduced_motion


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## The version with the variant: what a playtest record names its build by.
func build_id() -> String:
	return "%s+%s" % [version(), config.variant]


## The one way a game starts: fresh, or from a saved atelier.
func new_game(seed: int, saved: Dictionary = {}) -> void:
	session += 1
	winds = 0
	inputs = 0
	config.seed = seed
	clock.reset()
	telemetry.clear()
	sfx.played.clear()
	_last_input = -1.0
	_hinted = false
	_since_save = 0.0
	_reported_end = false
	atelier = Atelier.new(balance)
	input = WindInput.new(balance)
	if not saved.is_empty():
		atelier.from_dict(saved)
	else:
		store.clear()
	atelier.awakening.connect(_on_awakening)
	atelier.awake_changed.connect(_on_awake)
	atelier.kicked.connect(func(i: int, k: float) -> void:
		view.on_kick(i, k)
		sfx.ping(i)
		telemetry.emit("kick", {"index": i, "energy_added": snappedf(k, 0.001)}))
	atelier.stage_changed.connect(func(stage: int, name: String) -> void:
		music.stage = stage
		ambient.stage = stage
		telemetry.emit("stage", {"stage": stage, "name": name}))
	music.stage = atelier.stage
	ambient.stage = atelier.stage
	view.bind(atelier)
	view.set_variant(config.variant)
	view.reset()
	hud.set_energy(atelier.energy)
	telemetry.emit("session_start", {"variant": config.variant, "build": version(), "build_id": build_id(), "seed": seed,
		"session": session, "resumed": not saved.is_empty(), "dolls": atelier.awake})


## A press of the key from `source` ("click", "key", "dev"): one turn now,
## and more while it is held.
func press(source: String) -> void:
	inputs += 1
	input.press(source)
	wind(source)
	if source == "dev":
		_let_go()


func release(source: String) -> void:
	if input.release(source):
		_let_go()


## A: letting go of the key releases the coiled spring into energy.
func _let_go() -> void:
	if not balance.spring_enabled:
		return
	var e := atelier.release()
	if e <= 0.0:
		return
	view.on_release(e)
	sfx.whoosh()
	hud.set_energy(atelier.energy)
	telemetry.emit("release", {"energy_added": snappedf(e, 0.001), "energy": snappedf(atelier.energy, 0.001)})


## One quarter turn, from any source. Refused turns (faster than the cap)
## change nothing and log nothing.
func wind(source: String) -> void:
	var t := clock.time
	if _last_input >= 0.0 and t - _last_input >= balance.idle_report_seconds:
		telemetry.emit("idle", {"seconds": snappedf(t - _last_input, 0.01)})
	_last_input = t
	_hinted = false
	view.hint = false
	var full_before := atelier.spring_full_refusals
	var added := atelier.wind()
	if added <= 0.0:
		if atelier.spring_full_refusals > full_before:
			view.on_spring_full()
		return
	winds += 1
	view.turn()
	view.on_wind()
	var tension := atelier.spring_fill() if balance.spring_enabled else atelier.target_fill()
	sfx.tick(tension)
	hud.set_energy(atelier.energy)
	var e := {"source": source, "energy_added": snappedf(added, 0.001), "energy": snappedf(atelier.energy, 0.001)}
	if balance.spring_enabled:
		e["spring"] = snappedf(atelier.spring, 0.001)
	telemetry.emit("wind", e)


func _on_awakening(i: int) -> void:
	view.on_awakening(i)
	sfx.chime()
	telemetry.emit("doll_awake", {"index": i, "cost": balance.costs[i],
		"energy_rate": snappedf(atelier.auto_rate(), 0.001), "awake_before": atelier.awake})


func _on_awake(i: int) -> void:
	sfx.chirp()
	telemetry.emit("doll_ready", {"index": i, "energy_rate": snappedf(atelier.auto_rate(), 0.001)})


func _process(delta: float) -> void:
	advance(delta)
	hud.advance(delta)


## Moves the game by `seconds` of game time (nothing moves while paused).
func advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, GameClock.MAX_STEP)
		left -= step
		var used := clock.advance(step)
		if used <= 0.0:
			continue
		_step(used)


func _step(dt: float) -> void:
	# Holding: after the delay, one turn per 1/hold_rate seconds.
	for i in input.advance(dt):
		wind("hold")
	atelier.tick(dt)
	view.advance(dt)
	music.advance(dt)
	ambient.rate = atelier.auto_rate()
	ambient.advance(dt)
	hud.set_energy(atelier.energy)
	var idle_for := clock.time - maxf(_last_input, 0.0)
	if not _hinted and not input.holding() and idle_for >= balance.hint_idle_seconds and atelier.target() < atelier.doll_count():
		_hinted = true
		view.hint = true
		telemetry.emit("hint", {"reason": "idle20", "idle": snappedf(idle_for, 0.01)})
	_since_save += dt
	if _since_save >= balance.autosave_seconds:
		save()
	if config.trace_out != "" and not OS.has_feature("web"):
		_trace_t += dt
		if _trace_t >= 2.0:
			_trace_t = 0.0
			_write_trace()


func save() -> void:
	_since_save = 0.0
	store.save(atelier, version())


func set_pause(reason: String, on: bool) -> void:
	if clock.set_paused(reason, on):
		telemetry.emit("pause" if clock.paused else "resume", {"why": reason})
		if clock.paused:
			if input.release_all():
				_let_go()
			save()


func _notification(what: int) -> void:
	if clock == null:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			set_pause("focus", true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			set_pause("focus", false)
		NOTIFICATION_WM_CLOSE_REQUEST:
			end_session()


## The session summary event (also asked for by the browser bridge).
func end_session() -> Dictionary:
	var e := {"dolls": atelier.awake, "energy": snappedf(atelier.energy, 0.001), "inputs": inputs,
		"turns": atelier.turns, "blocked": atelier.blocked}
	if not _reported_end:
		_reported_end = true
		telemetry.emit("session_end", e)
		save()
	return e


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_SPACE:
			if event.pressed:
				press("key")
			else:
				release("key")
			get_viewport().set_input_as_handled()
		elif key == KEY_F5 and event.pressed and config.dev:
			new_game(config.seed)
			get_viewport().set_input_as_handled()
		elif key == KEY_E and event.pressed and config.dev:
			_bridge.query("dev_export", null)
			get_viewport().set_input_as_handled()


func state() -> Dictionary:
	return {
		"version": version(),
		"session": session,
		"t": snappedf(clock.time, 0.001),
		"paused": clock.paused,
		"pause_reasons": clock.reasons(),
		"winds": winds,
		"inputs": inputs,
		"events": telemetry.events.size(),
		"config": config.to_dict(),
		"art": view.use_art,
		"doll": view.doll.pose_name if view.doll != null else "",
		"fps": Engine.get_frames_per_second(),
		"energy": snappedf(atelier.energy, 0.001),
		"spring": snappedf(atelier.spring, 0.001),
		"build_id": build_id(),
		"awake": atelier.awake,
		"waking": atelier.waking,
		"target": atelier.target(),
		"fill": snappedf(atelier.target_fill(), 0.001),
		"stage": atelier.stage,
		"rate": snappedf(atelier.auto_rate(), 0.001),
		"hint": view.hint,
		"sounds": sfx.played.duplicate(),
		"music_notes": music.notes_played,
		"gears": view.gears_shown(),
		"settings": {"volume": settings.volume(), "reduced_motion": settings.reduced_motion},
	}


## `godot --headless --path windup -- --smoke`: presses over game seconds
## through the real scene, then one summary line, then quit with the number of
## problems found.
func _run_smoke() -> void:
	for i in 100:
		press("dev")
		advance(0.2)
		if i % 10 == 0:
			await get_tree().process_frame
	advance(3.0)
	var problems: Array[String] = []
	if telemetry.count("session_start") != 1:
		problems.append("session_start")
	if telemetry.count("wind") != 100:
		problems.append("wind %d" % telemetry.count("wind"))
	if atelier.awake < 1:
		problems.append("no doll awake")
	if absf(atelier.accounted_energy() - atelier.energy) > 1e-6:
		problems.append("energy accounting")
	print("WINDUP_SMOKE " + JSON.stringify({"ok": problems.is_empty(), "problems": problems, "state": state()}))
	get_tree().quit(problems.size())
