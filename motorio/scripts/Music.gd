extends Node
## Music, played rather than stored.
##
## There is no music file. There is one note sample and a list of when to strike
## it and how far to bend it, and this walks that list in time. The reason is
## size: this game's whole first download is half a megabyte, most of it the two
## looping ambience beds, and a rendered twenty-four second theme at the same
## rate would be a megabyte on its own -- tripling the download for something the
## player hears twice. A score is a few hundred numbers, and the sample it plays
## is 44KB.
##
## It also means the music can be edited. Moving a note is changing a number
## here, not finding whatever produced a WAV and hoping it still runs -- the
## exact problem tools/build_sfx.py exists to fix for the sound effects.
##
## Where it plays is deliberately narrow: the title, and the day summary. Not
## underneath play. A day is twelve minutes and a session is several of them, so
## a loop running through it would come round often enough to stop being
## atmosphere; the wind and cold beds already carry the plateau, and they answer
## to warmth in a way a loop cannot.

const NOTE: AudioStream = preload("res://assets/sfx/note.wav")
## Six is enough for the densest moment in either score plus the tails of what
## came before; a struck note here rings for a second.
const VOICES := 6
const BEAT := 0.5
## Music sits under the effects. It is the background of a menu, not an event.
const LEVEL_DB := -17.0

## [beat, semitone, gain]. Semitones are relative to the sample's own pitch, so
## 0 is A4, -12 is the octave below it. The scale is A natural minor throughout
## -- 0, 2, 3, 5, 7, 8, 10 -- which is what makes a sparse figure sound intended
## rather than arbitrary.
const SCORES := {
	# The title. Rewritten in Quality Pass 01: the old one struck its loudest
	# note two octaves below the sample (110 Hz at gain 0.9) every eight beats,
	# and a pitch_scale of 0.25 also plays a sample four times slower -- a low
	# boom every four seconds, which is the "opening BGM" a playtest could not
	# stand. Now nothing goes below G3, the low notes are the quietest ones, and
	# the sample is a bell. A slow line over sparse roots, sixteen seconds, loop.
	"title": {
		"bars": 32.0,
		"loop": true,
		"db": -19.0,
		"notes": [
			[0.0, -12, 0.26], [0.0, 7, 0.32],
			[2.0, 3, 0.24],
			[4.0, 5, 0.22],
			[6.0, 7, 0.26],
			[8.0, -4, 0.22], [8.0, 0, 0.24],
			[11.0, 3, 0.22],
			[14.0, -2, 0.20],
			[16.0, -9, 0.24], [16.0, 10, 0.24],
			[18.0, 7, 0.22],
			[20.0, 5, 0.22],
			[22.0, 3, 0.20],
			[24.0, -14, 0.22], [24.0, 2, 0.22],
			[27.0, 5, 0.20],
			[30.0, 7, 0.18],
		],
	},
	# The shelter. The only score that plays while the game is running, and the
	# only room where nothing is being asked of the player: the clock is stopped,
	# the cold cannot reach her and the cats are asleep on the floor. A lullaby:
	# fewer notes than the title, softer, and the quietest score -- it plays for
	# as long as she stays, so it has to be possible to stop hearing it.
	"home": {
		"bars": 24.0,
		"loop": true,
		"db": -24.0,
		"notes": [
			[0.0, -12, 0.22], [0.0, 3, 0.22],
			[3.0, 7, 0.18],
			[6.0, 5, 0.16],
			[8.0, -4, 0.20], [8.0, 0, 0.18],
			[11.0, 3, 0.16],
			[14.0, 0, 0.14],
			[16.0, -9, 0.20], [16.0, 7, 0.18],
			[19.0, 5, 0.15],
			[22.0, 3, 0.14],
		],
	},
	# The day summary. Once, and short: a rising figure that lands on the octave,
	# because the card it plays under is the one that says the day was survived.
	"result": {
		"bars": 9.0,
		"loop": false,
		"notes": [
			[0.0, -12, 0.80], [0.0, 3, 0.45],
			[2.0, 7, 0.45],
			[4.0, 10, 0.45],
			[6.0, 12, 0.55], [6.0, 0, 0.35],
		],
	},
}

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
## How many notes have been struck. The only observable the sequencer has -- a
## test cannot listen, and whether a loop wrapped correctly or a finished score
## restarted itself are both questions about how many times a note was played.
var strikes: int = 0
## What the screen asked for, and what is actually sounding. They are not the
## same thing, and keeping only one was a bug: `result` does not loop, so it
## stops on its own while the summary card is still up -- and a caller that says
## "play result" every frame would then start it again, every frame, forever.
## The request persists after the score ends; only a different screen clears it.
var _requested: String = ""
var _score: String = ""
var _time: float = 0.0
## Which notes of the current pass have already been struck. Cleared on a loop.
var _fired: int = 0

func _ready() -> void:
	for index in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Master"
		player.stream = NOTE
		add_child(player)
		_voices.append(player)

## Starts a score from the beginning. Asking again for the one already requested
## does nothing, so the caller can say this every frame.
func play_score(name: String) -> void:
	if not SCORES.has(name) or _requested == name:
		return
	_requested = name
	_score = name
	_time = 0.0
	_fired = 0

func stop() -> void:
	if _requested == "" and _score == "":
		return
	_requested = ""
	_score = ""
	for player: AudioStreamPlayer in _voices:
		player.stop()

func is_playing_score(name: String) -> bool:
	return _score == name

func requested_score() -> String:
	return _requested

func _process(delta: float) -> void:
	if _score == "":
		return
	var score: Dictionary = SCORES[_score]
	var notes: Array = score["notes"]
	_time += delta
	var beat: float = _time / BEAT
	# Notes are in order, so this only ever looks at the front of the queue.
	while _fired < notes.size() and float(notes[_fired][0]) <= beat:
		var note: Array = notes[_fired]
		_strike(int(note[1]), float(note[2]))
		_fired += 1
	if beat < float(score["bars"]):
		return
	if not bool(score["loop"]):
		_score = ""
		return
	# Wrap by the bar length rather than resetting to zero, so a long frame does
	# not swallow the first beat of the next pass.
	_time -= float(score["bars"]) * BEAT
	_fired = 0

func _strike(semitone: int, gain: float) -> void:
	strikes += 1
	# No pool means no mixer -- a test driving the sequencer directly. The timing
	# is the part being checked and it does not need a speaker.
	if _voices.is_empty():
		return
	var player: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	player.pitch_scale = pow(2.0, float(semitone) / 12.0)
	var level: float = LEVEL_DB
	if SCORES.has(_score):
		level = float(SCORES[_score].get("db", LEVEL_DB))
	player.volume_db = level + linear_to_db(clampf(gain, 0.01, 1.0))
	player.play()
