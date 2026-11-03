class_name PopAudio
extends Node

## Every sound goes through here, on the SFX bus declared in
## default_bus_layout.tres (a bus added at run time is silent on the web --
## AGENTS.md 2026-10-27). A small pool of players caps how many play at once,
## and one sound is not restarted more often than MIN_GAP_MS (a hundred pieces
## in one eruption are one boom and a crackle, not a hundred pops).
## Muting mutes the bus; `?sound=off` starts muted.

const NAMES := ["pop_1", "pop_2", "pop_3", "coin", "upgrade", "sizzle", "ding", "thud", "hiss", "clink", "boom", "crackle"]
const POOL := 10
const MIN_GAP_MS := 45

var muted := false
var played: Dictionary = {}       # name -> times played (for tests)
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_ms: Dictionary = {}
var _loop: AudioStreamPlayer


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
	muted = on
	var bus := AudioServer.get_bus_index(&"SFX")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, on)


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(name, -100000)) < MIN_GAP_MS:
		return
	_last_ms[name] = now
	played[name] = int(played.get(name, 0)) + 1
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
	if _loop.stream != _streams[name]:
		var s: AudioStreamOggVorbis = (_streams[name] as AudioStreamOggVorbis).duplicate()
		s.loop = true
		_loop.stream = s
	_loop.pitch_scale = clampf(pitch, 0.5, 2.0)
	if not _loop.playing:
		played[name] = int(played.get(name, 0)) + 1
		_loop.play()


func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
	_loop.stop()
