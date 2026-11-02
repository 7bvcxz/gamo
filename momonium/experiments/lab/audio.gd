class_name LabAudio
extends Node

## Sound for the Lab: one soft music loop, the sea, and short effects -- all
## the game's own files (shared/audio). The buses are declared in
## default_bus_layout.tres: buses added at run time are not in the web
## build's audio graph and play nowhere (momonium Step 51's lesson).
## `muted` is the player's sound switch (the frame's speaker button).

const MUSIC := preload("res://shared/audio/music_calm.ogg")
const OCEAN := preload("res://shared/audio/amb_ocean.ogg")
const EFFECTS := {
	"coin": preload("res://shared/audio/sfx_coin.ogg"),
	"click": preload("res://shared/audio/sfx_click.ogg"),
	"refuse": preload("res://shared/audio/sfx_refuse.ogg"),
	"built": preload("res://shared/audio/sfx_built.ogg"),
	"promote": preload("res://shared/audio/sfx_promote.ogg"),
	"harvest": preload("res://shared/audio/sfx_harvest.ogg"),
	"pick": preload("res://shared/audio/sfx_tap_pick.ogg"),
	"metal": preload("res://shared/audio/sfx_tap_metal.ogg"),
	"thunk": preload("res://shared/audio/sfx_thunk.ogg"),
	"break": preload("res://shared/audio/sfx_demolish.ogg"),
	"land": preload("res://shared/audio/sfx_land.ogg"),
	"momo": preload("res://shared/audio/sfx_momo.ogg"),
	"soft": preload("res://shared/audio/sfx_tap_soft.ogg"),
	"wood": preload("res://shared/audio/sfx_tap_wood.ogg"),
	"water": preload("res://shared/audio/sfx_tap_water.ogg"),
}
const POOL := 8

var muted := false:
	set(v):
		muted = v
		var bus := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(bus, v)
## How many times each effect was asked for (tests and the report read it).
var played: Dictionary = {}

var _music: AudioStreamPlayer
var _ocean: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = _player("Music", MUSIC, -14.0)
	_ocean = _player("Ambience", OCEAN, -20.0)
	for i in POOL:
		_pool.append(_player("Effects", null, -6.0))


func _player(bus: String, stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p


## The music and the sea, quietly (an experiment starts them).
func start_ambience(music: bool = true) -> void:
	if music and not _music.playing:
		_loop(_music)
		_music.play()
	if not _ocean.playing:
		_loop(_ocean)
		_ocean.play()


func _loop(p: AudioStreamPlayer) -> void:
	var ogg := p.stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true


func stop_ambience() -> void:
	_music.stop()
	_ocean.stop()


func play(name: String, pitch: float = 1.0, db: float = 0.0, jitter: float = 0.04) -> void:
	if not EFFECTS.has(name):
		return
	played[name] = int(played.get(name, 0)) + 1
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = EFFECTS[name]
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-jitter, jitter))
	p.volume_db = -6.0 + db
	p.play()
