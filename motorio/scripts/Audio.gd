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
const STEPS := [preload("res://assets/sfx/cc0/step_1.wav"), preload("res://assets/sfx/cc0/step_2.wav"),
	preload("res://assets/sfx/cc0/step_3.wav"), preload("res://assets/sfx/cc0/step_4.wav"),
	preload("res://assets/sfx/cc0/step_5.wav")]
## Each sound is a list of takes. One is picked per play, never the same as the
## last one where there is a choice -- a single sample struck ten times a second
## is exactly the "same sound again" the ear tires of first.
const BANK := {
	"build": [preload("res://assets/sfx/build.wav")],
	"remove": [preload("res://assets/sfx/remove.wav")],
	"select": [preload("res://assets/sfx/select.wav")],
	"confirm": [preload("res://assets/sfx/confirm.wav")],
	## Something arriving at the core: a soft tap of tin (CC0, `cc0/`). It was a
	## beep, placeless, for every item -- the factory noise in the shelter.
	"deliver": [preload("res://assets/sfx/cc0/deliver_1.wav"), preload("res://assets/sfx/cc0/deliver_2.wav"),
		preload("res://assets/sfx/cc0/deliver_3.wav")],
	"alloy": [preload("res://assets/sfx/alloy.wav")],
	"deny": [preload("res://assets/sfx/deny.wav")],
	"alarm": [preload("res://assets/sfx/alarm.wav")],
	"finish": [preload("res://assets/sfx/finish.wav")],
	## A pickaxe on stone: a recorded crack with the thud filtered off, a knock
	## of stone under it and grit after (CC0, tools/build_cc0_sfx.py). Five takes
	## -- the old one was a single falling glide ("벽 때리는 소리").
	"pick": [preload("res://assets/sfx/cc0/pick_1.wav"), preload("res://assets/sfx/cc0/pick_2.wav"),
		preload("res://assets/sfx/cc0/pick_3.wav"), preload("res://assets/sfx/cc0/pick_4.wav"),
		preload("res://assets/sfx/cc0/pick_5.wav")],
	"nibble": [preload("res://assets/sfx/nibble.wav")],
	## The one voice in the game. A cat waking out of the ice.
	"meow": [preload("res://assets/sfx/meow.wav")],
	## A boot in packed snow, five takes; running uses the same five, faster.
	"step": STEPS,
	"step_run": STEPS,
	## Making and receiving (1.0.42): the fire's tick while it works, the pop
	## when a make is done, and the chime when an important thing reaches her.
	"tick": [preload("res://assets/sfx/tick.wav")],
	"pop": [preload("res://assets/sfx/pop.wav")],
	"chime": [preload("res://assets/sfx/chime.wav")],
	## A few tiny crackles of ice, once, when the cold gets a step worse.
	"frost": [preload("res://assets/sfx/frost.wav")],
	## Her breath in the cold. Not in the effect path's schedule -- the cold
	## scheduler below decides when -- but played through it like any sound.
	"breath": [preload("res://assets/sfx/breath_1.wav"), preload("res://assets/sfx/breath_2.wav"),
		preload("res://assets/sfx/breath_3.wav")],
	## A cat at work: the same stone, much smaller -- a tiny pick. Played by the
	## worker scheduler below, a few at a time, nearest first.
	"cat_tap": [preload("res://assets/sfx/cc0/cat_tap_1.wav"), preload("res://assets/sfx/cc0/cat_tap_2.wav"),
		preload("res://assets/sfx/cc0/cat_tap_3.wav")],
	## A machine finishing a piece of work: a small, light piece of metal.
	"clink": [preload("res://assets/sfx/cc0/clink_1.wav"), preload("res://assets/sfx/cc0/clink_2.wav"),
		preload("res://assets/sfx/cc0/clink_3.wav")],
	## The case unfolding into a base: a latch, and a creak of hinges.
	"latch": [preload("res://assets/sfx/cc0/latch.wav")],
	"creak": [preload("res://assets/sfx/cc0/creak.wav")],
	## Cloth: her getting up, out of the snow or out of bed.
	"rustle": [preload("res://assets/sfx/cc0/rustle_1.wav"), preload("res://assets/sfx/cc0/rustle_2.wav")],
	## Fuel catching in the fire: a soft rush of air, warm because it has no top
	## and no bottom.
	"whoomp": [preload("res://assets/sfx/whoomp.wav")],
	## The fire growing a size: the whoomp and two warm notes rising out of it.
	"level": [preload("res://assets/sfx/level.wav")],
}
const VOLUMES := {
	"build": -6.0, "remove": -12.0, "select": -16.0, "confirm": -8.0,
	"deliver": -17.0, "alloy": -8.0, "deny": -10.0,
	# A reminder, not an alarm (Quality Pass 01): two soft notes stepping down.
	"alarm": -13.0,
	# A reward is a little louder than usual, and only a little. It was -4, the
	# loudest thing in the game, for every mission line.
	"finish": -11.0,
	"pick": -8.0, "nibble": -21.0,
	# Loud, because it happens once per cat and it is the thing the walk was for.
	"meow": -7.0,
	# Under everything. Footsteps are the only sound that plays continuously, so
	# what would be a reasonable level for a one-shot is a drone here.
	"step": -23.0, "step_run": -21.0,
	# Small on purpose. The tick repeats every second of a make; the pop and the
	# chime mark one moment each and must not outrank a cat waking up.
	"tick": -22.0, "pop": -10.0, "chime": -12.0,
	"frost": -24.0, "breath": -27.0, "whoomp": -15.0, "level": -11.0,
	# A cat's tap is the smallest thing in the world that still reads: under her
	# pick by eleven dB, and several of them are still under it (`CROWD_DB`).
	"cat_tap": -19.0,
	# Machines are details, not events: under a delivery, far under a build.
	"clink": -19.0,
	"latch": -12.0, "creak": -16.0, "rustle": -18.0,
}
## A sound's own pitch, before the jitter. Running is the walk played quicker.
const PITCH := {"step_run": 1.08}
## Where each sound is mixed. UI is anything that answers a key or marks a
## reward; Character is her and the cats; Machine is the factory; Environment is
## the world's own events -- the fire, the base, the weather's one-shots.
const BUS_OF := {
	"build": "Environment", "remove": "Environment", "select": "UI", "confirm": "UI",
	"deliver": "Machine", "alloy": "Machine", "deny": "UI", "alarm": "UI",
	"finish": "UI", "pick": "Character", "nibble": "Character", "meow": "Character",
	"step": "Character", "step_run": "Character", "tick": "Environment",
	"pop": "Environment", "chime": "UI", "frost": "Character", "breath": "Character",
	"whoomp": "Environment", "level": "Environment",
	"cat_tap": "Character", "clink": "Machine", "latch": "Environment",
	"creak": "Environment", "rustle": "Character",
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
	"breath": {"cap": 1, "gap": 3.0},
	"frost": {"cap": 1, "gap": 6.0},
	"pick": {"cap": 2, "gap": 0.08},
	# Twenty cats at work are three taps at a time, the nearest three -- and,
	# through the gap, never more than three or four a second however many are
	# working. One cat taps every second or so and the gap never touches it; at
	# sixteen in earshot the plain schedule was six a second, a chatter.
	"cat_tap": {"cap": 3, "gap": 0.28},
	"clink": {"cap": 3, "gap": 0.2},
}

# --- Things that work continuously ------------------------------------------------
## Workers: many things doing the same small job -- cats at their posts. Each
## taps now and then at its own random interval; the taps go through `play_at`,
## so distance, the cap and the crowd rule decide what is heard.
const WORKERS := {
	"cat_tap": {"every": Vector2(0.85, 1.7)},
}
## Emitters: machines with a continuous sound. A loop is attached to the nearest
## `cap` of them in earshot and to none of the rest -- twenty generators are two
## hums, never twenty.
const EMITTERS := {
	"hum": {"stream": preload("res://assets/sfx/hum.wav"), "bus": "Machine", "db": -27.0, "cap": 2},
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
## Two looping beds: the wind, always there outside, and the cold -- the wind
## picking up, a gustier mid-range layer that rises as warmth falls. Both are
## filtered noise above 170 Hz (Quality Pass 01): the old wind was 26-150 Hz, a
## drone, and the old cold was a separate shimmer that read as a fault. The two
## loops are 16 and 12.2 seconds long so they only line up again after minutes,
## and the gusts on top arrive at random (`GUSTS`).
const BEDS := {
	"wind": preload("res://assets/sfx/wind.wav"),
	"cold": preload("res://assets/sfx/cold.wav"),
}
const BED_CEILING := {"wind": -22.0, "cold": -27.0}
const BED_BUS := {"wind": "Ambient", "cold": "Ambient"}
## Below this the bed is muted outright; -60 dB of noise is still noise.
const BED_FLOOR := -40.0
## The wind by time of day: light by day, a little stronger once the sun goes.
const WIND_DAY := 0.5
const WIND_NIGHT := 0.72

# --- Weather on top of the beds -------------------------------------------------
## Gusts, one at a time, at random intervals, sizes and pitches -- the reason a
## sixteen-second loop never sounds like one. More often at night.
const GUSTS: Array[AudioStream] = [preload("res://assets/sfx/gust_1.wav"),
	preload("res://assets/sfx/gust_2.wav"), preload("res://assets/sfx/gust_3.wav")]
const GUST_DB := -27.0
const GUST_EVERY := Vector2(7.0, 16.0)
const GUST_EVERY_NIGHT := Vector2(4.5, 10.0)

## The cold in three steps. Not a sound that repeats every second or two -- a
## breath now and then, a little more often as it gets worse, and one crackle
## of ice when it steps down. `x` is where the step starts on exposure (0..1);
## `every` the seconds between breaths.
const COLD_STEPS := [
	{"name": "normal", "from": 0.0, "every": Vector2.ZERO},
	{"name": "cold", "from": 0.4, "every": Vector2(8.0, 11.0)},
	{"name": "danger", "from": 0.75, "every": Vector2(4.5, 6.0)},
]

# --- The opening ----------------------------------------------------------------
## One cue a panel, played once as the panel arrives. On the Music bus: they are
## the score of the story, and the story has no score but these.
const CUES := {
	"tension": preload("res://assets/sfx/cue_tension.wav"),
	"impact": preload("res://assets/sfx/cue_impact.wav"),
	"rise": preload("res://assets/sfx/cue_rise.wav"),
	"blast": preload("res://assets/sfx/cue_blast.wav"),
	"alarm": preload("res://assets/sfx/cue_alarm.wav"),
	"crash": preload("res://assets/sfx/cue_crash.wav"),
}
const CUE_DB := -14.0

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
var _gust: AudioStreamPlayer
var _gust_wait := 5.0
## When the gust sounding now ends, on this node's clock. Not `playing`: a
## headless mixer never finishes a stream, and the scheduler would wait forever.
var _gust_ends := -1.0
var _cue: AudioStreamPlayer
## What the opening asked of the wind: the story is in space and in a city until
## the ice planet, and there is no wind there.
var _cue_wind := 0.0
var _cold_step := 0
var _breath_wait := 0.0
## How many gusts and breaths have started, and the gaps between breaths -- what
## a test reads instead of listening.
var gusts := 0
var breath_gaps: Array[float] = []
var _last_breath := -INF
## Every start this manager has made, by sound -- the only observable a test has,
## since a headless mixer plays nothing anyone can listen to.
var started: Dictionary = {}
## Which take each start used, most recent last. A test reads it to see that the
## same recording is not struck twice running.
var take_log: Dictionary = {}
## Its own dice. The game's world seed is drawn from the global generator, and a
## sound that rolled from the same one would move every world after it.
var _rng := RandomNumberGenerator.new()
var _workers: Dictionary = {}
var _emitters: Dictionary = {}

func _ready() -> void:
	for name: String in BEDS:
		var bed := AudioStreamPlayer.new()
		bed.bus = _bus(String(BED_BUS.get(name, "Ambient")))
		bed.stream = BEDS[name]
		if bed.stream is AudioStreamWAV:
			(bed.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(bed.stream as AudioStreamWAV).loop_end = loop_frames(bed.stream as AudioStreamWAV)
		bed.volume_db = -60.0
		add_child(bed)
		_beds[name] = bed
		bed.play()
	_gust = AudioStreamPlayer.new()
	_gust.bus = _bus("Ambient")
	add_child(_gust)
	_cue = AudioStreamPlayer.new()
	_cue.bus = _bus("Music")
	add_child(_cue)
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
	for stream: AudioStream in GUSTS:
		out.append(stream.resource_path)
	for name: String in CUES:
		out.append((CUES[name] as AudioStream).resource_path)
	for kind: String in EMITTERS:
		out.append((EMITTERS[kind]["stream"] as AudioStream).resource_path)
	return out

## Where a bed's loop ends: its length in frames.
##
## It used to be `data.size() / 2` -- bytes over two, which is the frame count
## of 16-bit PCM and nothing else. The beds are imported QOA-compressed
## (`compress/mode=2`), a few bits a sample, so that number was a fifth of the
## file: the 7.5 second wind looped every 1.5 seconds and the 6 second cold
## every 1.2, each with a jump at the seam. That is most of what a playtest
## heard as a roar on repeat and a strange noise every second or two, and no
## recipe in build_sfx.py could have fixed it. (Quoted in design/AUDIO_AUDIT.md;
## not here, because test_font holds every character in a script to the font.)
static func loop_frames(stream: AudioStreamWAV) -> int:
	return int(round(stream.get_length() * float(stream.mix_rate)))

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
		take = _rng.randi() % (takes.size() - 1)
		if take >= int(_last_take.get(sound, -1)):
			take += 1
	_last_take[sound] = take
	var log: Array = take_log.get(sound, [])
	log.append(take)
	if log.size() > 64:
		log.pop_front()
	take_log[sound] = log
	var stream: AudioStream = takes[take]
	var pitch: float = float(PITCH.get(sound, 1.0)) * (1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter))
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

## One frame of a crowd of workers. `where` maps each worker's id to its place;
## a worker not in it has stopped. Each keeps its own random interval, so twenty
## cats do not tap in step -- and every tap goes through `play_at`, so only the
## nearest few in earshot are heard.
func work(kind: String, where: Dictionary, delta: float) -> void:
	if not WORKERS.has(kind):
		return
	var every: Vector2 = WORKERS[kind]["every"]
	var waits: Dictionary = _workers.get(kind, {})
	for id: Variant in waits.keys():
		if not where.has(id):
			waits.erase(id)
	for id: Variant in where:
		# A worker that has just started waits a random part of an interval, so a
		# row of cats put down together does not start in unison.
		var wait: float = float(waits.get(id, _rng.randf_range(0.2, every.y))) - delta
		if wait <= 0.0:
			play_at(kind, where[id], 0.08)
			wait = _rng.randf_range(every.x, every.y)
		waits[id] = wait
	_workers[kind] = waits

## One frame of continuous machine sound: a loop on each of the nearest `cap`
## emitters in earshot, faded by distance, and silence on the rest.
func set_emitters(kind: String, points: Array, delta: float) -> void:
	if not EMITTERS.has(kind):
		return
	var spec: Dictionary = EMITTERS[kind]
	var voices: Array = _emitters.get(kind, [])
	if voices.is_empty():
		var stream: AudioStreamWAV = spec["stream"]
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = loop_frames(stream)
		for index in int(spec["cap"]):
			var player := AudioStreamPlayer2D.new()
			player.attenuation = 0.0
			player.max_distance = FAR * 4.0
			player.bus = _bus(String(spec["bus"]))
			player.stream = stream
			add_child(player)
			voices.append({"player": player, "at": Vector2.ZERO, "on": false})
		_emitters[kind] = voices
	var near: Array = []
	for point: Vector2 in points:
		var distance: float = point.distance_to(listener)
		if distance <= FAR:
			near.append([distance, point])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for index in voices.size():
		var voice: Dictionary = voices[index]
		var player: AudioStreamPlayer2D = voice["player"]
		if index < near.size():
			var point: Vector2 = near[index][1]
			voice["at"] = point
			player.global_position = point
			player.volume_db = float(spec["db"]) + distance_db(float(near[index][0]))
			if not voice["on"]:
				voice["on"] = true
				# Each loop starts somewhere different: two generators side by side
				# should not breathe in unison.
				player.play(_rng.randf() * (player.stream as AudioStream).get_length())
		elif voice["on"]:
			voice["on"] = false
			player.stop()

## How many loops of an emitter kind are sounding, and where.
func emitting(kind: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for voice: Dictionary in _emitters.get(kind, []):
		if voice["on"]:
			out.append(voice["at"])
	return out

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
## `day` is how far through the day the clock is (0 morning, 1 the end of night)
## -- both are Main's to know and neither is worth this node reading the world
## for.
func apply(screen: String, zone: int, exposure: float, day: float, delta: float) -> void:
	var score: String = String(SCREEN_SCORES.get(screen, Zone.score(zone)))
	if music != null:
		if score.is_empty():
			music.call("stop")
		else:
			music.call("play_score", score)
	set_mix(Zone.mix(zone), delta)
	if screen != "opening" and _cue.playing:
		# The story was skipped or is over: its cue does not play on into the snow.
		_cue.volume_db = move_toward(_cue.volume_db, -60.0, delta * 60.0)
		if _cue.volume_db <= -59.0:
			_cue.stop()
	if not Zone.has_weather(zone):
		# Not a quieter outdoors -- no outdoors. Wind is the sound of being in
		# the open, and a door closing on it is the clearest thing this game says
		# without words.
		set_bed("wind", 0.0, delta)
		set_bed("cold", 0.0, delta)
		_cold_step = 0
		return
	if screen == "title":
		set_bed("wind", STILL_WIND, delta)
		set_bed("cold", 0.0, delta)
		_tick_gusts(delta, 0.0)
		return
	if screen == "opening":
		set_bed("wind", _cue_wind, delta)
		set_bed("cold", 0.0, delta)
		return
	var evening: float = evening_of(day)
	set_bed("wind", lerpf(WIND_DAY, WIND_NIGHT, evening), delta)
	set_bed("cold", clampf(exposure, 0.0, 1.0), delta)
	_tick_gusts(delta, evening)
	if screen == "play":
		_tick_cold(exposure, delta)
	else:
		_cold_step = 0

## 0 through the day, rising through dusk to 1 at night. The day clock alone
## would make the wind grow from breakfast onward.
static func evening_of(day: float) -> float:
	var dusk_starts: float = 1.0 - Defs.DUSK_SECONDS / Defs.DAY_SECONDS
	return clampf((day - dusk_starts) / (1.0 - dusk_starts), 0.0, 1.0)

func _tick_gusts(delta: float, evening: float) -> void:
	_gust_wait -= delta
	if _gust_wait > 0.0:
		return
	var every: Vector2 = GUST_EVERY.lerp(GUST_EVERY_NIGHT, evening)
	_gust_wait = _rng.randf_range(every.x, every.y)
	if clock < _gust_ends:
		return
	_gust.stream = GUSTS[_rng.randi() % GUSTS.size()]
	_gust.pitch_scale = _rng.randf_range(0.9, 1.1)
	_gust_ends = clock + _gust.stream.get_length() / _gust.pitch_scale
	_gust.volume_db = GUST_DB + _rng.randf_range(-6.0, 0.0) + 3.0 * evening
	_gust.play()
	gusts += 1

## Which cold step an exposure is in.
static func cold_step_of(exposure: float) -> int:
	var step := 0
	for index in COLD_STEPS.size():
		if exposure >= float(COLD_STEPS[index]["from"]):
			step = index
	return step

func _tick_cold(exposure: float, delta: float) -> void:
	var step: int = cold_step_of(exposure)
	if step > _cold_step:
		# A step down into the cold: ice, once. Its own gap keeps a warmth that
		# wobbles on the line from crackling twice.
		play("frost", 0.05)
		_breath_wait = minf(_breath_wait, 1.2)
	_cold_step = step
	var every: Vector2 = COLD_STEPS[step]["every"]
	if every == Vector2.ZERO:
		_breath_wait = 0.0
		return
	_breath_wait -= delta
	if _breath_wait > 0.0:
		return
	_breath_wait = _rng.randf_range(every.x, every.y)
	if play("breath", 0.06):
		if _last_breath > -INF:
			breath_gaps.append(clock - _last_breath)
		_last_breath = clock

## The opening's cue for the panel that has just arrived, and how much wind is
## under it. An empty name plays nothing and only moves the wind.
func cue(name: String, wind: float = 0.0) -> void:
	_cue_wind = clampf(wind, 0.0, 1.0)
	# The last panel is her waking in the snow: no cue but her own breath, the
	# first sound of the game proper arriving a moment early.
	if name == "breath":
		play("breath", 0.04)
		started["cue_breath"] = int(started.get("cue_breath", 0)) + 1
		return
	if not CUES.has(name):
		return
	_cue.stream = CUES[name]
	_cue.volume_db = CUE_DB
	_cue.play()
	started["cue_" + name] = int(started.get("cue_" + name, 0)) + 1
