class_name AudioService
extends Node

## Everything the island sounds like, in one place, apart from the game.
##
## Three buses under Master -- Music, Ambience, Effects -- each with its own
## volume from Settings, plus a mute for all and a choice to fall silent while
## the game is in the background (a hidden tab, another app in front).
##
## Music: one calm loop. Ambience: layers that follow the island -- the sea
## always, more wind and crickets at night, a low hum while furnaces or mines
## work -- each easing toward where it should be, never jumping. Effects: short
## sounds for what happens (a tap on any button, building, a building done, a
## harvest, research done, a letter, a Momo hired or put to work, a sale, land
## rising, a promotion, a demolition, a refusal), from a few players in turn.
##
## The sounds are made by tools/audio/build_audio.py (synthesised, Ogg).

const DIR := "res://assets/audio/"
const BUSES: PackedStringArray = ["Music", "Ambience", "Effects"]
const LAYERS: PackedStringArray = ["ocean", "wind", "crickets", "industry"]
const INDUSTRY: PackedStringArray = ["smelter", "car_factory", "game_studio", "steam_engine", "mine"]
const VOICES := 6
## Ambience follows its target by this much per second (0..1 of full volume).
const EASE := 0.5

var sim: Simulation
var settings: SettingsStore
var music: AudioStreamPlayer
var layers: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}
## How often each effect played (tests, the E2E bridge).
var played: Dictionary = {}
## Ambience volume now and where it is heading, per layer (0..1).
var level: Dictionary = {}
var target: Dictionary = {}
var focused := true


func setup(p_sim: Simulation, p_settings: SettingsStore) -> void:
	sim = p_sim
	_cycle = null
	_retarget_left = 0.0
	settings = p_settings
	name = "Audio"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	music = _player("Music", "Music")
	music.stream = _stream("music_calm", true)
	for layer: String in LAYERS:
		var p := _player("Amb_" + layer, "Ambience")
		p.stream = _stream("amb_" + layer, true)
		p.volume_db = -80.0
		layers[layer] = p
		level[layer] = 0.0
		target[layer] = 0.0
	for i in VOICES:
		voices.append(_player("Voice%d" % i, "Effects"))
	apply_settings()
	sim.bus.emitted.connect(_on_event)
	get_tree().node_added.connect(_watch_button)
	for n: Node in get_tree().root.find_children("*", "BaseButton", true, false):
		_watch_button(n)


## Starts music and beds (on the web the browser lets sound out after the
## first touch; before that this is silent and harmless).
func start() -> void:
	if not music.playing:
		music.play()
	for layer: String in LAYERS:
		if not (layers[layer] as AudioStreamPlayer).playing:
			(layers[layer] as AudioStreamPlayer).play()


func _player(node_name: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = bus
	add_child(p)
	return p


func _stream(file: String, loop: bool) -> AudioStream:
	if _streams.has(file):
		return _streams[file]
	var s: AudioStream = load(DIR + file + ".ogg")
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_streams[file] = s
	return s


# --- settings ---------------------------------------------------------------------------

## Volumes (0..1, a natural curve), mute, and the background rule onto the buses.
func apply_settings() -> void:
	var vols := {"Music": float(settings.get_value("music_volume")), "Ambience": float(settings.get_value("ambience_volume")),
		"Effects": float(settings.get_value("sfx_volume"))}
	for bus: String in vols:
		var i := AudioServer.get_bus_index(bus)
		var v := clampf(float(vols[bus]), 0.0, 1.0)
		AudioServer.set_bus_volume_db(i, volume_db(v))
		AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_mute(0, silent())


func silent() -> bool:
	return bool(settings.get_value("muted")) or (not focused and bool(settings.get_value("mute_unfocused")))


## 0..1 -> dB on a perceptual curve (squared), -60 dB at the bottom.
static func volume_db(v: float) -> float:
	if v <= 0.001:
		return -80.0
	return maxf(linear_to_db(v * v), -60.0)


func set_setting(key: String, value: Variant) -> void:
	settings.set_value(key, value)
	apply_settings()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			focused = false
			if settings != null:
				apply_settings()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			focused = true
			if settings != null:
				apply_settings()


# --- ambience -----------------------------------------------------------------------------

const RETARGET_SECONDS := 0.25
var _retarget_left := 0.0
var _cycle: DayCycle

## Where each layer should be now: the sea always, wind and crickets by the
## hour, the hum while industry works.
func targets() -> Dictionary:
	if _cycle == null:
		_cycle = DayCycle.new(sim.data)
	var night := _cycle.is_night(sim.clock)
	var working := false
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids():
		var b := bs.get_building(id)
		if b["state"] == BuildingSystem.WORKING and INDUSTRY.has(String(b["type"])):
			working = true
			break
	return {"ocean": 0.75, "wind": 0.55 if night else 0.3, "crickets": 0.6 if night else 0.0, "industry": 0.5 if working else 0.0}


func _process(delta: float) -> void:
	if sim == null:
		return
	# Where the layers head changes with the hour and the work: a few looks a
	# second are plenty for fades this slow (and spare a walk over every
	# building each frame).
	_retarget_left -= delta
	if _retarget_left <= 0.0:
		_retarget_left = RETARGET_SECONDS
		target = targets()
	for layer: String in LAYERS:
		var v := move_toward(float(level[layer]), float(target[layer]), EASE * delta)
		level[layer] = v
		(layers[layer] as AudioStreamPlayer).volume_db = volume_db(v)


# --- effects --------------------------------------------------------------------------------

## Effects that come in streams once work pays at once (Step 50): heard at
## most once per this many milliseconds, so many Momo finishing together
## ring one coin, not a cascade.
const MIN_GAP_MS := {"coin": 250, "harvest": 250}
var _last_ms := {}


func play(effect: String) -> void:
	if MIN_GAP_MS.has(effect):
		var now := Time.get_ticks_msec()
		if _last_ms.has(effect) and now - int(_last_ms[effect]) < int(MIN_GAP_MS[effect]):
			return
		_last_ms[effect] = now
	played[effect] = int(played.get(effect, 0)) + 1
	var s := _stream("sfx_" + effect, false)
	if s == null:
		return
	var p := voices[_next]
	_next = (_next + 1) % voices.size()
	p.stream = s
	p.pitch_scale = 1.0
	p.play()


func _watch_button(n: Node) -> void:
	if n is BaseButton and not n.has_meta("audio_click"):
		n.set_meta("audio_click", true)
		(n as BaseButton).pressed.connect(func() -> void: play("click"))


## What happens on the island, heard.
func _on_event(type: StringName, p: Dictionary) -> void:
	match type:
		&"building_added", &"building_refit":
			play("build")
		&"building_built":
			play("built")
		&"task_completed":
			if String(p.get("stage", "")) == "harvest":
				play("harvest")
		&"research_completed":
			play("research")
		&"letter_written":
			play("letter")
		&"momo_hired", &"momo_assigned":
			play("momo")
		&"sold":
			play("coin")
		&"land_bought":
			play("land")
		&"tier_promoted":
			play("promote")
		&"building_demolished":
			play("demolish")
