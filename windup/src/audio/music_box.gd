class_name MusicBox
extends Node

## A music box that grows with the atelier: silent while it sleeps, then one
## plucked line, then more voices as stages pass (design: Step 05). Notes are
## synthesised once at start (no sound files) and scheduled on game time, so a
## paused game is a silent game and a test can step it exactly.
##
## Layers by stage: 1 melody (sparse) · 2 melody (full) · 3 + bass · 4 + high
## counter-line · 5 + the big clock's tick.

const RATE := 22050
const STEP := 0.42            # seconds per step; 16 steps = one 6.7 s phrase
## C major pentatonic, two octaves: index -> frequency.
const SCALE := [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]
## 16 steps; -1 is a rest. Melody in the upper octave, bass below.
const MELODY_SPARSE := [7, -1, -1, -1, 5, -1, -1, -1, 6, -1, -1, -1, 4, -1, -1, -1]
const MELODY_FULL := [7, -1, 5, 6, 7, -1, 8, -1, 6, -1, 5, 4, 5, -1, -1, -1]
const BASS := [0, -1, -1, -1, 3, -1, -1, -1, 1, -1, -1, -1, 2, -1, -1, -1]
const COUNTER := [-1, 9, -1, -1, -1, 8, -1, -1, -1, 9, -1, 7, -1, -1, 8, -1]

var stage: int = 0
var notes_played: int = 0
var _t: float = 0.0
var _step: int = -1
var _pluck: Array[AudioStreamWAV] = []
var _tick: AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for f: float in SCALE:
		_pluck.append(Sfx._make(_pluck_samples(f, 0.9)))
	_tick = Sfx._make(_tick_samples())
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = -9.0
		add_child(p)
		_players.append(p)


## The layers the stage plays: [pattern, octave shift (notes), volume dB].
static func layers(st: int) -> Array:
	var out: Array = []
	if st >= 1:
		out.append([MELODY_SPARSE if st == 1 else MELODY_FULL, 0, 0.0])
	if st >= 3:
		out.append([BASS, -5, -3.0])
	if st >= 4:
		out.append([COUNTER, 0, -8.0])
	return out


func advance(dt: float) -> void:
	_t += dt
	var s := int(floor(_t / STEP))
	while _step < s:
		_step += 1
		_play_step(_step % 16)


func _play_step(i: int) -> void:
	for layer: Array in layers(stage):
		var pattern: Array = layer[0]
		var n: int = pattern[i]
		if n < 0:
			continue
		var idx := n + int(layer[1])
		var pitch := 1.0
		if idx < 0:
			pitch = 0.5
			idx += 5
		_play(_pluck[clampi(idx, 0, _pluck.size() - 1)], pitch, float(layer[2]))
	if stage >= 5 and i % 2 == 0:
		_play(_tick, 1.0 if i % 4 == 0 else 0.92, -6.0)


func _play(stream: AudioStreamWAV, pitch: float, db: float) -> void:
	notes_played += 1
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = -9.0 + db
	p.play()


## A music-box pluck: a bright attack and a long soft decay.
static func _pluck_samples(f: float, seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 4.0) * minf(1.0, t * 400.0)
		out[i] = (sin(TAU * f * t) * 0.55 + sin(TAU * f * 3.0 * t) * 0.12 * exp(-t * 9.0) + sin(TAU * f * 5.02 * t) * 0.05 * exp(-t * 14.0)) * env * 0.5
	return out


## The grandfather clock's tick: a short low knock.
static func _tick_samples() -> PackedFloat32Array:
	var n := int(RATE * 0.09)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * 820.0 * t) * 0.3 + sin(TAU * 205.0 * t) * 0.4) * exp(-t * 55.0)
	return out
