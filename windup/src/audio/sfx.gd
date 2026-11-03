class_name Sfx
extends Node

## The game's sounds, synthesised at start (no sound files): the ratchet click
## of a quarter turn, the chime of an awakening, the small chirp of a doll that
## is up and working. All on the Effects bus (declared in
## default_bus_layout.tres -- a bus added at runtime is silent on the web).

const RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _tick: AudioStreamWAV
var _chime: AudioStreamWAV
var _chirp: AudioStreamWAV
var _tick_pitch := [1.0, 1.06, 0.97, 1.03]
var _tick_i := 0
## How many sounds were started, by name (tests and the browser bridge).
var played: Dictionary = {}
var volume_db: float = 0.0:
	set(v):
		volume_db = v
		for p in _players:
			p.volume_db = v


func _ready() -> void:
	_tick = _make(_tick_samples())
	_chime = _make(_chime_samples())
	_chirp = _make(_chirp_samples())
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = &"Effects"
		add_child(p)
		_players.append(p)


## One ratchet click. `tension` 0..1 (how full the next doll is) raises the
## pitch, so the winding sounds tighter as an awakening comes near.
func tick(tension: float = 0.0) -> void:
	_tick_i = (_tick_i + 1) % _tick_pitch.size()
	_play("tick", _tick, float(_tick_pitch[_tick_i]) * (1.0 + 0.32 * clampf(tension, 0.0, 1.0)))


func chime() -> void:
	_play("chime", _chime, 1.0)


func chirp() -> void:
	_play("chirp", _chirp, 1.0)


func _play(name: String, stream: AudioStream, pitch: float) -> void:
	played[name] = int(played.get(name, 0)) + 1
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.play()


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## A ratchet click: a short bright knock and a wooden body under it.
static func _tick_samples() -> PackedFloat32Array:
	var n := int(RATE * 0.07)
	var out := PackedFloat32Array()
	out.resize(n)
	var seed := 12345
	for i in n:
		var t := float(i) / RATE
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed % 2000) / 1000.0 - 1.0
		var knock := noise * exp(-t * 180.0) * 0.32
		var body := sin(TAU * 1850.0 * t) * exp(-t * 90.0) * 0.2 + sin(TAU * 420.0 * t) * exp(-t * 60.0) * 0.18
		out[i] = knock + body
	return out


## An awakening: three soft bell partials rising, 1.4 s.
static func _chime_samples() -> PackedFloat32Array:
	var n := int(RATE * 1.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [[523.25, 0.0], [659.25, 0.12], [783.99, 0.24], [1046.5, 0.36]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for note: Array in notes:
			var start: float = note[1]
			if t >= start:
				var u := t - start
				v += sin(TAU * float(note[0]) * u) * exp(-u * 3.2) * 0.15
				v += sin(TAU * float(note[0]) * 2.01 * u) * exp(-u * 6.0) * 0.04
		out[i] = v * minf(1.0, t * 200.0)
	return out


## A doll ready to work: a short upward chirp.
static func _chirp_samples() -> PackedFloat32Array:
	var n := int(RATE * 0.18)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(900.0, 1500.0, t / 0.18)
		phase += TAU * f / RATE
		out[i] = sin(phase) * sin(PI * t / 0.18) * 0.3
	return out
