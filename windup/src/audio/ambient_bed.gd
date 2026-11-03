class_name AmbientBed
extends Node

## The room's tone (Step 05 V2): at first a cold, near-silent hush, so the
## stillness is something you hear; as dolls work, a warm low hum and a soft
## mechanical heartbeat whose pace follows the dolls' energy rate. Two seamless
## loops (synthesised, the filters primed so the end meets the start) and a
## scheduled thump -- nothing restarts audibly every few seconds.

const RATE := 22050
const LOOP_SECONDS := 4.0

var stage: int = 0
var rate: float = 0.0
var beats: int = 0
var _hush: AudioStreamPlayer
var _warm: AudioStreamPlayer
var _beat: AudioStreamPlayer
var _beat_t: float = 0.0


func _ready() -> void:
	_hush = _loop_player(_hush_samples(), -30.0)
	_warm = _loop_player(_warm_samples(), -80.0)
	_beat = AudioStreamPlayer.new()
	_beat.bus = &"Ambience"
	_beat.stream = Sfx._make(_thump_samples())
	_beat.volume_db = -14.0
	add_child(_beat)


func _loop_player(samples: PackedFloat32Array, db: float) -> AudioStreamPlayer:
	var w := Sfx._make(samples)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = samples.size()   # 16-bit mono: one frame per sample
	var p := AudioStreamPlayer.new()
	p.bus = &"Ambience"
	p.stream = w
	p.volume_db = db
	add_child(p)
	p.play()
	return p


## Target levels (dB) for a stage: the hush fades as the hum comes in.
static func levels(st: int) -> Vector2:
	var hush := lerpf(-26.0, -48.0, clampf(st / 4.0, 0.0, 1.0))
	var warm := -80.0 if st <= 0 else lerpf(-30.0, -18.0, clampf((st - 1) / 4.0, 0.0, 1.0))
	return Vector2(hush, warm)


func advance(dt: float) -> void:
	var l := levels(stage)
	_hush.volume_db = move_toward(_hush.volume_db, l.x, dt * 6.0)
	_warm.volume_db = move_toward(_warm.volume_db, l.y, dt * 6.0)
	if rate > 0.0:
		_beat_t += dt
		var period := clampf(2.4 - rate * 0.06, 0.55, 2.4)
		if _beat_t >= period:
			_beat_t = 0.0
			beats += 1
			_beat.play()


## Filtered noise, the filter run over the buffer twice so the loop is seamless.
static func _hush_samples() -> PackedFloat32Array:
	var n := int(RATE * LOOP_SECONDS)
	var noise := PackedFloat32Array()
	noise.resize(n)
	var seed := 4242
	for i in n:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		noise[i] = float(seed % 2000) / 1000.0 - 1.0
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for pass_i in 2:
		for i in n:
			lp += (noise[i] - lp) * 0.035
			out[i] = lp * 0.9
	return out


## A low hum: whole-number cycles of 55/110/165 Hz in 4 s, so it loops clean.
static func _warm_samples() -> PackedFloat32Array:
	var n := int(RATE * LOOP_SECONDS)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var swell := 0.75 + 0.25 * sin(TAU * t / LOOP_SECONDS)
		out[i] = (sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 55.0 * t) * 0.25 + sin(TAU * 165.0 * t) * 0.08) * swell * 0.6
	return out


## The heartbeat: a soft wooden double knock.
static func _thump_samples() -> PackedFloat32Array:
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var a := sin(TAU * 90.0 * t) * exp(-t * 30.0)
		var t2 := t - 0.16
		var b := sin(TAU * 80.0 * t2) * exp(-t2 * 34.0) * 0.6 if t2 > 0.0 else 0.0
		out[i] = (a + b) * 0.5
	return out
