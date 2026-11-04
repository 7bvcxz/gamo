class_name PopAudio
extends Node

## Every sound goes through here, on the SFX bus declared in
## default_bus_layout.tres (a bus added at run time is silent on the web --
## AGENTS.md 2026-10-27). A small pool of players caps how many play at once,
## and one sound is not restarted more often than MIN_GAP_MS (a hundred pieces
## in one eruption are one boom and a crackle, not a hundred pops).
## Muting mutes the bus; `?sound=off` starts muted.

const NAMES := ["pop_1", "pop_2", "pop_3", "coin", "upgrade", "sizzle", "ding", "thud", "hiss", "clink", "boom", "crackle", "fanfare"]
## The speaker button steps through these (Step 05 addendum: a volume setting,
## not only mute): loud, soft, off.
const LEVELS := [{"name": "loud", "db": 0.0}, {"name": "soft", "db": -12.0}, {"name": "off", "db": -80.0}]
## Big sounds duck the small ones for DUCK_MS, so a boom or a fanfare is not
## buried under a hundred pops (controlled polyphony, with the pool and the gap).
const DUCKERS := ["boom", "fanfare"]
const DUCK_DB := -8.0
const DUCK_MS := 450
const POOL := 10
const MIN_GAP_MS := 45

var muted := false
var level := 0          # index into LEVELS
var _duck_until := 0
var played: Dictionary = {}       # name -> times played (for tests)
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_ms: Dictionary = {}
var _loop: AudioStreamPlayer
var _loop_streams := {}   # name -> its looping copy, made once


func _ready() -> void:
	for n: String in NAMES:
		var path := "res://assets/audio/%s.ogg" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_loop = AudioStreamPlayer.new()
	_loop.bus = &"SFX"
	add_child(_loop)
	set_muted(muted)


func set_muted(on: bool) -> void:
	set_level(2 if on else 0)


## 0 loud, 1 soft, 2 off.
func set_level(i: int) -> void:
	level = clampi(i, 0, LEVELS.size() - 1)
	muted = String(LEVELS[level]["name"]) == "off"
	var bus := AudioServer.get_bus_index(&"SFX")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, muted)
		AudioServer.set_bus_volume_db(bus, float(LEVELS[level]["db"]) if not muted else 0.0)


func next_level() -> void:
	set_level((level + 1) % LEVELS.size())


func level_name() -> String:
	return String(LEVELS[level]["name"])


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(name, -100000)) < MIN_GAP_MS:
		return
	_last_ms[name] = now
	played[name] = int(played.get(name, 0)) + 1
	if name in DUCKERS:
		_duck_until = now + DUCK_MS
	elif now < _duck_until:
		volume_db += DUCK_DB
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.volume_db = volume_db
	p.play()


## One looping sound at a time (B's sizzle while heating).
func loop(name: String, on: bool, pitch: float = 1.0) -> void:
	if not on:
		if _loop.playing:
			_loop.stop()
		return
	if not _streams.has(name):
		return
	# The looping copy is made once per sound and kept. (Until Step 12 this compared
	# the player's copy with the original -- never equal -- so every frame of
	# heating made a new copy and restarted it: 1,400 'plays' a minute, and on
	# the web each new stream was a newly decoded sample that stayed alive,
	# about 27 MB a hold.)
	if not _loop_streams.has(name):
		var s: AudioStreamOggVorbis = (_streams[name] as AudioStreamOggVorbis).duplicate()
		s.loop = true
		_loop_streams[name] = s
	if _loop.stream != _loop_streams[name]:
		_loop.stream = _loop_streams[name]
	_loop.pitch_scale = clampf(pitch, 0.5, 2.0)
	if not _loop.playing:
		played[name] = int(played.get(name, 0)) + 1
		_loop.play()


func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
	_loop.stop()
