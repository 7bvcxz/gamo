extends Node

## Everything the game makes a sound with: the one-shots, the looping beds, the
## mix between inside and outside, and -- through `music` -- what plays under
## the screen. `design/AUDIO_DIRECTION.md` is what it should sound like; this is
## how that is kept.
##
## A manager rather than a voice pool, for three reasons that each cost a
## playtest:
##
## * What plays used to be decided in two functions in Main that did not know
##   about each other, and neither asked *where she was* -- the wind blew through
##   a shut door. One call a frame now (`apply`), with the place in it.
## * Every sound used to be placeless and equally loud. The core beeping for each
##   item a belt delivered was heard six hundred tiles away inside the shelter.
##   A sound that happens somewhere in the world is played *at* that place
##   (`play_at`), fades with distance from the listener and is not started at all
##   past `FAR`.
## * Nothing limited how many of one sound played at once. A factory is the same
##   event from twenty machines; `RULES` caps each sound, and when the cap is full
##   the farthest voice gives way to a nearer one -- so what is heard is the
##   nearest few, never twenty.
##
## Every sound has a bus (`BUS_OF`, buses in `default_bus_layout.tres`) and each
## place has a mix of those buses (`MIXES`, chosen by the `mix` column of
## `Zone.gd`), eased rather than cut.

# --- The bank -----------------------------------------------------------------
## Each sound is a list of takes. One is picked per play, never the same as the
## last one where there is a choice -- a single sample struck ten times a second
## is exactly the "same sound again" the ear tires of first.
const BANK := {
	"build": [preload("res://assets/sfx/build.wav")],
	"remove": [preload("res://assets/sfx/remove.wav")],
	"select": [preload("res://assets/sfx/select.wav")],
	"confirm": [preload("res://assets/sfx/confirm.wav")],
	"deliver": [preload("res://assets/sfx/deliver.wav")],
	"alloy": [preload("res://assets/sfx/alloy.wav")],
	"deny": [preload("res://assets/sfx/deny.wav")],
	"alarm": [preload("res://assets/sfx/alarm.wav")],
	"finish": [preload("res://assets/sfx/finish.wav")],
	"pick": [preload("res://assets/sfx/pick.wav")],
	"nibble": [preload("res://assets/sfx/nibble.wav")],
	## The one voice in the game. A cat waking out of the ice.
	"meow": [preload("res://assets/sfx/meow.wav")],
	"step": [preload("res://assets/sfx/step.wav")],
	"step_run": [preload("res://assets/sfx/step_run.wav")],
	## Making and receiving (1.0.42): the fire's tick while it works, the pop
	## when a make is done, and the chime when an important thing reaches her.
	"tick": [preload("res://assets/sfx/tick.wav")],
	"pop": [preload("res://assets/sfx/pop.wav")],
	"chime": [preload("res://assets/sfx/chime.wav")],
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
	# Small on purpose. The tick repeats every second of a make; the pop and the
	# chime mark one moment each and must not outrank a cat waking up.
	"tick": -22.0, "pop": -10.0, "chime": -9.0,
}
## Where each sound is mixed. UI is anything that answers a key or marks a
## reward; Character is her and the cats; Machine is the factory; Environment is
## the world's own events -- the fire, the base, the weather's one-shots.
const BUS_OF := {
	"build": "Environment", "remove": "Environment", "select": "UI", "confirm": "UI",
	"deliver": "Machine", "alloy": "Machine", "deny": "UI", "alarm": "UI",
	"finish": "UI", "pick": "Character", "nibble": "Character", "meow": "Character",
	"step": "Character", "step_run": "Character", "tick": "Environment",
	"pop": "Environment", "chime": "UI",
}
## How a sound may repeat. `cap` is how many of it sound at once; `gap` is the
## shortest time between two starts. Anything not listed gets `DEFAULT_RULE`.
const DEFAULT_RULE := {"cap": 4, "gap": 0.035}
const RULES := {
	"step": {"cap": 2, "gap": 0.06},
	"step_run": {"cap": 2, "gap": 0.05},
	"deliver": {"cap": 3, "gap": 0.08},
	"alloy": {"cap": 3, "gap": 0.08},
	"nibble": {"cap": 1, "gap": 0.2},
}

# --- Where a sound is ---------------------------------------------------------
## Distances in world pixels from the listener. Full level inside `NEAR` (a few
## tiles either side of her), fading to `FAR_DB` at `FAR`, and not started past
## it: a voice spent on something nobody can hear is a voice a near sound loses.
const NEAR := 6.0 * float(Grid.TILE)
const FAR := 22.0 * float(Grid.TILE)
const FAR_DB := -24.0
## Each voice of the same sound already sounding takes this much off the next,
## per doubling -- twenty cats are a busier sound than one, not twenty times it.
const CROWD_DB := 3.0

const FLAT_VOICES := 10
const WORLD_VOICES := 16

# --- Beds ---------------------------------------------------------------------
## Two looping beds rather than music: a wind floor that is always there, and a
## cold shimmer that fades up as warmth falls. The game had nine one-shots and
## silence between them, which made a frozen plateau sound like a menu.
const BEDS := {
	"wind": preload("res://assets/sfx/wind.wav"),
	"cold": preload("res://assets/sfx/cold.wav"),
}
const BED_CEILING := {"wind": -19.0, "cold": -15.0}
const BED_BUS := {"wind": "Ambient", "cold": "Ambient"}
## Below this the bed is muted outright; -60 dB of noise is still noise.
const BED_FLOOR := -34.0

# --- The mix ------------------------------------------------------------------
## Bus levels in dB for each place. Buses not named are at 0. The shelter keeps
## her and the cats (Character) and the room's own sounds (Interior); the
## outside goes -- most of it is already silent by distance, since the room is
## six hundred tiles from the fire, and this is what takes the rest.
const MIXES := {
	"outside": {"Interior": -80.0},
	"inside": {"Ambient": -80.0, "Machine": -60.0, "Environment": -40.0},
}
## Seconds for a bus to travel all the way. A door closing is a fade, not a cut.
const MIX_FADE := 0.6
const MIX_BUSES: Array[String] = ["Music", "Ambient", "SFX", "Machine", "Character",
	"Environment", "UI", "Interior"]

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

## Where the ear is: the centre of the screen, set by Main every frame. Until it
## is set, every world sound is treated as right here.
var listener := Vector2.ZERO
## The manager's own time. Advanced by `_process`, and by a test with
## `advance()` -- gaps and voice lifetimes are measured on it, never on the wall
## clock, so a test can put twenty sounds in one frame and know what happened.
var clock := 0.0

var _beds: Dictionary = {}
var _bed_level: Dictionary = {"wind": 0.0, "cold": 0.0}
var _flat: Array[Dictionary] = []
var _world: Array[Dictionary] = []
var _last_start: Dictionary = {}
var _last_take: Dictionary = {}
var _mix_name := "outside"
var _mix_gain: Dictionary = {}
## Every start this manager has made, by sound -- the only observable a test has,
## since a headless mixer plays nothing anyone can listen to.
var started: Dictionary = {}

func _ready() -> void:
	for name: String in BEDS:
		var bed := AudioStreamPlayer.new()
		bed.bus = _bus(String(BED_BUS.get(name, "Ambient")))
		bed.stream = BEDS[name]
		if bed.stream is AudioStreamWAV:
			(bed.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(bed.stream as AudioStreamWAV).loop_end = (bed.stream as AudioStreamWAV).data.size() / 2
		bed.volume_db = -60.0
		add_child(bed)
		_beds[name] = bed
		bed.play()
	for index in FLAT_VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_flat.append({"player": player, "sound": "", "ends": -1.0, "dist": 0.0})
	for index in WORLD_VOICES:
		var player := AudioStreamPlayer2D.new()
		# The engine pans; the distance fade is ours (`distance_db`), so the one
		# the engine would add is switched off and its range put out of the way.
		player.attenuation = 0.0
		player.max_distance = FAR * 4.0
		add_child(player)
		_world.append({"player": player, "sound": "", "ends": -1.0, "dist": 0.0})
	for bus: String in MIX_BUSES:
		_mix_gain[bus] = _mix_target(bus, _mix_name)
	_push_mix()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	clock += delta

# --- Playing ------------------------------------------------------------------

## A sound with no place: an answer to a key, or something happening to her.
## Returns whether it started, which is what a test reads.
func play(sound: String, pitch_jitter: float = 0.06) -> bool:
	return _start(sound, pitch_jitter, 0.0, Vector2.ZERO, false)

## A sound that happens somewhere in the world, fading with distance from the
## listener and not played at all out of earshot.
func play_at(sound: String, at: Vector2, pitch_jitter: float = 0.06) -> bool:
	return _start(sound, pitch_jitter, at.distance_to(listener), at, true)

## Every stream this manager plays that is not in `BANK` or `BEDS` -- the
## tables added for ambience, cues and machine loops. `test_audio` reads it to
## check that nothing on disk goes unplayed.
static func extra_streams() -> Array[String]:
	var out: Array[String] = []
	return out

## How much quieter a sound is at this distance, in dB. Negative infinity is not
## returned: past `FAR` the caller does not play at all.
static func distance_db(distance: float) -> float:
	if distance <= NEAR:
		return 0.0
	return lerpf(0.0, FAR_DB, clampf((distance - NEAR) / (FAR - NEAR), 0.0, 1.0))

## How many of one sound are sounding right now.
func sounding(sound: String) -> int:
	var count := 0
	for voice: Dictionary in _flat + _world:
		if String(voice["sound"]) == sound and float(voice["ends"]) > clock:
			count += 1
	return count

func _rule(sound: String) -> Dictionary:
	return RULES.get(sound, DEFAULT_RULE)

func _start(sound: String, pitch_jitter: float, distance: float, at: Vector2,
		placed: bool) -> bool:
	if not BANK.has(sound):
		return false
	if placed and distance > FAR:
		return false
	var rule: Dictionary = _rule(sound)
	if clock - float(_last_start.get(sound, -INF)) < float(rule["gap"]):
		return false
	# The cap. Full means the farthest of this sound gives way -- if the new one is
	# nearer. Otherwise the new one is the one not heard.
	var same: Array[Dictionary] = []
	for voice: Dictionary in _flat + _world:
		if String(voice["sound"]) == sound and float(voice["ends"]) > clock:
			same.append(voice)
	if same.size() >= int(rule["cap"]):
		var farthest: Dictionary = same[0]
		for voice: Dictionary in same:
			if float(voice["dist"]) > float(farthest["dist"]):
				farthest = voice
		if float(farthest["dist"]) <= distance:
			return false
		_silence(farthest)
		same.erase(farthest)
	var voice: Dictionary = _take_voice(_world if placed else _flat)
	var takes: Array = BANK[sound]
	var take: int = 0
	if takes.size() > 1:
		take = randi() % (takes.size() - 1)
		if take >= int(_last_take.get(sound, -1)):
			take += 1
	_last_take[sound] = take
	var stream: AudioStream = takes[take]
	var pitch: float = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	var level: float = float(VOLUMES.get(sound, -10.0))
	if placed:
		level += distance_db(distance)
	level -= CROWD_DB * log(1.0 + float(same.size())) / log(2.0)
	var player: Node = voice["player"]
	player.set("stream", stream)
	player.set("bus", _bus(String(BUS_OF.get(sound, "SFX"))))
	player.set("volume_db", level)
	player.set("pitch_scale", pitch)
	if placed:
		(player as AudioStreamPlayer2D).global_position = at
	player.call("play")
	voice["sound"] = sound
	voice["dist"] = distance
	voice["ends"] = clock + stream.get_length() / maxf(pitch, 0.01)
	_last_start[sound] = clock
	started[sound] = int(started.get(sound, 0)) + 1
	return true

## A free voice from the pool, or the one closest to finishing.
func _take_voice(pool: Array[Dictionary]) -> Dictionary:
	var pick: Dictionary = pool[0]
	for voice: Dictionary in pool:
		if float(voice["ends"]) <= clock:
			return voice
		if float(voice["ends"]) < float(pick["ends"]):
			pick = voice
	_silence(pick)
	return pick

func _silence(voice: Dictionary) -> void:
	(voice["player"] as Node).call("stop")
	voice["sound"] = ""
	voice["ends"] = -1.0

## A bus by name, falling back to Master when the layout does not have it -- a
## scene run without the project's bus layout still makes sound.
static func _bus(name: String) -> StringName:
	return StringName(name) if AudioServer.get_bus_index(name) >= 0 else &"Master"

# --- Beds ---------------------------------------------------------------------

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

# --- The mix ------------------------------------------------------------------

## A bus's current level, 0..1 linear, after the fade.
func bus_level(bus: String) -> float:
	return float(_mix_gain.get(bus, 1.0))

func mix_name() -> String:
	return _mix_name

static func _mix_target(bus: String, mix: String) -> float:
	var levels: Dictionary = MIXES.get(mix, {})
	return db_to_linear(float(levels.get(bus, 0.0))) if float(levels.get(bus, 0.0)) > -79.0 else 0.0

## Moves every bus toward the named mix, `MIX_FADE` seconds end to end.
func set_mix(mix: String, delta: float) -> void:
	_mix_name = mix
	var step: float = delta / MIX_FADE
	for bus: String in MIX_BUSES:
		var now: float = float(_mix_gain.get(bus, 1.0))
		_mix_gain[bus] = move_toward(now, _mix_target(bus, mix), step)
	_push_mix()

func _push_mix() -> void:
	for bus: String in MIX_BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(_mix_gain[bus]), 0.0001)))

## The whole soundscape of one frame: which score, which mix, and how loud each
## bed.
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
	set_mix(Zone.mix(zone), delta)
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
