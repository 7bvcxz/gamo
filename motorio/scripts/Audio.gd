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
	"pick": preload("res://assets/sfx/pick.wav"),
	"nibble": preload("res://assets/sfx/nibble.wav"),
	"step": preload("res://assets/sfx/step.wav"),
	"step_run": preload("res://assets/sfx/step_run.wav"),
}
const VOLUMES := {
	"build": -6.0, "remove": -12.0, "select": -16.0, "confirm": -8.0,
	"deliver": -12.0, "alloy": -6.0, "deny": -10.0, "alarm": -6.0, "finish": -4.0,
	"pick": -7.0, "nibble": -21.0,
	# Under everything. Footsteps are the only sound that plays continuously, so
	# what would be a reasonable level for a one-shot is a drone here.
	"step": -24.0, "step_run": -21.0,
}

## Two looping beds rather than music: a wind floor that is always there, and a
## cold shimmer that fades up as warmth falls. The game had nine one-shots and
## silence between them, which made a frozen plateau sound like a menu.
const BEDS := {
	"wind": preload("res://assets/sfx/wind.wav"),
	"cold": preload("res://assets/sfx/cold.wav"),
}
const BED_CEILING := {"wind": -19.0, "cold": -15.0}
## Below this the bus is muted outright; -60 dB of noise is still noise.
const BED_FLOOR := -34.0

var _beds: Dictionary = {}
var _bed_level: Dictionary = {"wind": 0.0, "cold": 0.0}

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}

func _ready() -> void:
	for name: String in BEDS:
		var bed := AudioStreamPlayer.new()
		bed.bus = "Master"
		bed.stream = BEDS[name]
		if bed.stream is AudioStreamWAV:
			(bed.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(bed.stream as AudioStreamWAV).loop_end = (bed.stream as AudioStreamWAV).data.size() / 2
		bed.volume_db = -60.0
		add_child(bed)
		_beds[name] = bed
		bed.play()
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

## Called every frame with 0..1 targets. Levels are eased rather than snapped so
## walking in and out of the cold is a slide, not a switch.
func set_bed(name: String, target: float, delta: float) -> void:
	if not _beds.has(name):
		return
	var wanted: float = clampf(target, 0.0, 1.0)
	var level: float = lerpf(float(_bed_level.get(name, 0.0)), wanted, clampf(delta * 1.6, 0.0, 1.0))
	_bed_level[name] = level
	var player: AudioStreamPlayer = _beds[name]
	if level <= 0.02:
		player.volume_db = -80.0
		return
	player.volume_db = lerpf(BED_FLOOR, float(BED_CEILING[name]), level)
