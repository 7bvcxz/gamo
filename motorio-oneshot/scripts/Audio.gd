extends Node

## A tiny voice pool. Sounds are procedurally generated WAVs shipped with the
## project, so there is no licensing question and no streaming stall.

const VOICES := 8
const BANK := {
	"build": preload("res://assets/sfx/build.wav"),
	"remove": preload("res://assets/sfx/remove.wav"),
	"select": preload("res://assets/sfx/select.wav"),
	"confirm": preload("res://assets/sfx/confirm.wav"),
	"deliver": preload("res://assets/sfx/deliver.wav"),
	"alloy": preload("res://assets/sfx/alloy.wav"),
	"deny": preload("res://assets/sfx/deny.wav"),
	"alarm": preload("res://assets/sfx/alarm.wav"),
	"finish": preload("res://assets/sfx/finish.wav"),
}
const VOLUMES := {
	"build": -6.0, "remove": -12.0, "select": -16.0, "confirm": -8.0,
	"deliver": -12.0, "alloy": -6.0, "deny": -10.0, "alarm": -6.0, "finish": -4.0,
}

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}

func _ready() -> void:
	for index in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_voices.append(player)

func play(sound: String, pitch_jitter: float = 0.06) -> void:
	if not BANK.has(sound):
		return
	# Rapid deliveries would otherwise stack into a harsh wall of sound.
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < 0.035:
		return
	_last_played[sound] = now
	var player: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	player.stream = BANK[sound]
	player.volume_db = float(VOLUMES.get(sound, -10.0))
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()
