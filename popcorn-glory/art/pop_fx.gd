class_name PopFx
extends RefCounted

## Flying popcorn and coins: a fixed pool, stepped with the frame and drawn by
## the view in one _draw(). Purely a picture -- the rules have already paid
## the money when a piece appears, so dropping pieces (the cap, reduced motion)
## never changes the game.

const CAP := 400
const GRAVITY := 1900.0

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat32Array()     # seconds left; <= 0 is a free slot
var size := PackedFloat32Array()
var rot := PackedFloat32Array()
var kind := PackedByteArray()        # 0 popcorn, 1 coin, 2 smoke, 3 kernel
var tint := PackedColorArray()
var target := Vector2.ZERO           # where coins fly (the money counter)
var alive := 0
var peak := 0
var dropped := 0


func _init() -> void:
	pos.resize(CAP); vel.resize(CAP); life.resize(CAP); size.resize(CAP); rot.resize(CAP); kind.resize(CAP)
	tint.resize(CAP)


func clear() -> void:
	life.fill(0.0)
	alive = 0


## `n` popcorn pieces bursting up out of `from`. `spread` widens the fan,
## `power` the speed, `big` the pieces (C draws fewer, bigger pieces past the cap).
func burst(from: Vector2, n: int, scale: float, rng: RandomNumberGenerator, col: Color = PopPalette.CREAM,
		spread: float = 0.9, power: float = 1.0, big: float = 1.0, life_s: float = 1.1) -> void:
	for i in n:
		var a := -PI / 2 + rng.randf_range(-spread, spread)
		var speed := rng.randf_range(650.0, 1150.0) * scale * power
		_spawn(0, from + Vector2(rng.randf_range(-20, 20), 0) * scale, Vector2(cos(a), sin(a)) * speed,
			rng.randf_range(life_s * 0.8, life_s * 1.2), rng.randf_range(15.0, 22.0) * scale * big, rng.randf() * TAU, col)


## Dark puffs rising (a burnt batch).
func smoke(from: Vector2, n: int, scale: float, rng: RandomNumberGenerator) -> void:
	for i in n:
		_spawn(2, from + Vector2(rng.randf_range(-60, 60), 0) * scale, Vector2(rng.randf_range(-40, 40), rng.randf_range(-260, -160)) * scale,
			rng.randf_range(0.9, 1.4), rng.randf_range(22.0, 34.0) * scale, 0.0, Color(0.25, 0.22, 0.22, 0.75))


## Unpopped kernels tumbling out (an early release).
func kernels(from: Vector2, n: int, scale: float, rng: RandomNumberGenerator) -> void:
	for i in n:
		var a := -PI / 2 + rng.randf_range(-1.2, 1.2)
		_spawn(3, from, Vector2(cos(a), sin(a)) * rng.randf_range(300.0, 600.0) * scale,
			rng.randf_range(0.6, 0.9), rng.randf_range(7.0, 10.0) * scale, rng.randf() * TAU, Color(0.78, 0.52, 0.2))


func coin(from: Vector2, scale: float) -> void:
	_spawn(1, from, Vector2.ZERO, 0.55, 20.0 * scale, 0.0, PopPalette.GOLD)


func step(delta: float) -> void:
	alive = 0
	for i in CAP:
		if life[i] <= 0.0:
			continue
		life[i] -= delta
		if kind[i] == 1:
			# Coins ease towards the counter and are gone when they reach it.
			pos[i] = pos[i].lerp(target, clampf(delta * 9.0, 0.0, 1.0))
			if pos[i].distance_to(target) < 12.0:
				life[i] = 0.0
		elif kind[i] == 2:
			pos[i] += vel[i] * delta
			size[i] += delta * 30.0
		else:
			vel[i] += Vector2(0, GRAVITY) * delta
			pos[i] += vel[i] * delta
			rot[i] += delta * 3.0
		if life[i] > 0.0:
			alive += 1
	peak = maxi(peak, alive)


func draw(ci: CanvasItem) -> void:
	for i in CAP:
		if life[i] <= 0.0:
			continue
		var fade := clampf(life[i] / 0.25, 0.0, 1.0)
		match kind[i]:
			1:
				PopMachineArt.draw_coin(ci, pos[i], size[i])
			2:
				ci.draw_circle(pos[i], size[i], Color(tint[i], tint[i].a * fade))
			3:
				ci.draw_circle(pos[i], size[i], Color(tint[i], fade))
			_:
				PopMachineArt.draw_piece(ci, pos[i], size[i], rot[i], Color(tint[i], fade))


## Any live popcorn piece's position (for a chain to start from), or `fallback`.
func random_piece(rng: RandomNumberGenerator, fallback: Vector2) -> Vector2:
	for attempt in 6:
		var i := rng.randi_range(0, CAP - 1)
		if life[i] > 0.3 and kind[i] == 0:
			return pos[i]
	return fallback


func _spawn(k: int, p: Vector2, v: Vector2, t: float, s: float, r: float, col: Color = PopPalette.CREAM) -> void:
	for i in CAP:
		if life[i] <= 0.0:
			pos[i] = p; vel[i] = v; life[i] = t; size[i] = s; rot[i] = r; kind[i] = k; tint[i] = col
			return
	dropped += 1
