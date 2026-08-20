extends Node

## Everything the game makes a sound with: the one-shots, the two looping beds,
## and -- through `music` -- what plays under the screen.
##
## The last part is why this is a manager rather than a voice pool. What plays
## used to be decided in two functions in Main that did not know about each
## other: one matched on the screen and started a score, the other read the
## weather and set the beds. Neither asked *where she was*, so walking into the
## shelter changed nothing about what the player heard -- the wind kept blowing
## through a shut door, and the cold bed was at its loudest at the exact moment
## she was finally safe, because it was read off the warmth she came home on.
##
## One call a frame now, with the place in it. Sounds are procedurally generated
## WAVs shipped with the project, so there is no licensing question and no
## streaming stall.

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
	## The one voice in the game. A cat waking out of the ice.
	"meow": preload("res://assets/sfx/meow.wav"),
	"step": preload("res://assets/sfx/step.wav"),
	"step_run": preload("res://assets/sfx/step_run.wav"),
}
const VOLUMES := {
	"build": -6.0, "remove": -12.0, "select": -16.0, "confirm": -8.0,
	"deliver": -12.0, "alloy": -6.0, "deny": -10.0, "alarm": -6.0, "finish": -4.0,
	"pick": -7.0, "nibble": -21.0,
	# Loud, because it happens once per cat and it is the thing the walk was for.
	"meow": -7.0,
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

## The sequencer, handed over by Main. Held rather than found so a test can run
## this without a scene, and so there is exactly one place that decides between a
## screen's score and a room's.
var music: Node = null

## What each screen sounds like regardless of where she is standing. The title
## and the summary card are the game talking, not the world, so they win.
const SCREEN_SCORES := {"title": "title", "result": "result"}
## The plateau under a still screen: no clock running and no one in the cold, so
## the wind is at its resting level and the cold bed says nothing.
const STILL_WIND := 0.35

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

## How loud a bed actually is, after the ease. The target is what was asked for
## and this is what the ear gets, which is the one a test has to read: a bed told
## to stop still fades, and a fade is exactly how a sound outlives its cause.
func bed_level(name: String) -> float:
	return float(_bed_level.get(name, 0.0))

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

## The whole soundscape of one frame: which score, and how loud each bed.
##
## `screen` is what is being drawn ("title", "opening", "play", "result", ...),
## `zone` is where she is standing, and the two are asked in that order because a
## card on screen is louder than a room. `exposure` is how cold she is, 0..1, and
## `night` is how far into the day it is -- both are Main's to know and neither
## is worth this node reading the world for.
func apply(screen: String, zone: int, exposure: float, night: float, delta: float) -> void:
	var score: String = String(SCREEN_SCORES.get(screen, Zone.score(zone)))
	if music != null:
		if score.is_empty():
			music.call("stop")
		else:
			music.call("play_score", score)
	if not Zone.has_weather(zone):
		# Not a quieter outdoors -- no outdoors. Wind and the cold shimmer are
		# both the sound of being in the open, and a door closing on them is the
		# clearest thing this game says without words.
		set_bed("wind", 0.0, delta)
		set_bed("cold", 0.0, delta)
		return
	if screen == "title" or screen == "opening":
		set_bed("wind", STILL_WIND, delta)
		set_bed("cold", 0.0, delta)
		return
	set_bed("wind", 0.45 + clampf(night, 0.0, 1.0) * 0.45, delta)
	set_bed("cold", clampf(exposure, 0.0, 1.0), delta)
